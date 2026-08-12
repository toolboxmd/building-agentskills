#!/usr/bin/env python3
"""Sanitize a LumenDesk customer export and emit its deterministic audit."""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import os
from pathlib import Path
import re
import sys
import tempfile
import unicodedata


HEADER = ["customer_ref", "email", "region", "display_name", "note", "status"]
CUSTOMER_REF_RE = re.compile(r"CUS-[0-9]{4}\Z")
REGIONS = {"north": "NORTH", "n": "NORTH", "nord": "NORTH",
           "south": "SOUTH", "s": "SOUTH", "sud": "SOUTH"}
STATUSES = {"active": "ACTIVE", "enabled": "ACTIVE",
            "paused": "PAUSED", "hold": "PAUSED"}


class SanitizationError(Exception):
    """An actionable input or output validation error."""


def normalized_text(value: str) -> str:
    return unicodedata.normalize("NFKC", value)


def collapsed(value: str) -> str:
    return " ".join(value.strip().split())


def validate_csv_quoting(text: str) -> None:
    """Reject quote placement that csv.reader accepts but RFC 4180 prohibits."""
    at_field_start = True
    in_quoted_field = False
    after_closing_quote = False
    line = 1
    index = 0
    while index < len(text):
        char = text[index]
        if in_quoted_field:
            if char == '"':
                if index + 1 < len(text) and text[index + 1] == '"':
                    index += 1
                else:
                    in_quoted_field = False
                    after_closing_quote = True
            elif char == "\n":
                line += 1
        elif after_closing_quote:
            if char == ",":
                at_field_start = True
                after_closing_quote = False
            elif char in "\r\n":
                if char == "\n":
                    line += 1
                at_field_start = True
                after_closing_quote = False
            else:
                raise SanitizationError(
                    f"malformed CSV at physical line {line}: "
                    "unexpected character after closing quote"
                )
        elif char == '"':
            if not at_field_start:
                raise SanitizationError(
                    f"malformed CSV at physical line {line}: "
                    "quote inside an unquoted field"
                )
            in_quoted_field = True
            at_field_start = False
        elif char == ",":
            at_field_start = True
        elif char in "\r\n":
            if char == "\n":
                line += 1
            at_field_start = True
        else:
            at_field_start = False
        index += 1

    if in_quoted_field:
        raise SanitizationError(
            f"malformed CSV at physical line {line}: unterminated quoted field"
        )


def normalize_row(row: list[str], row_number: int) -> list[str]:
    values = [normalized_text(value) for value in row]

    customer_ref = values[0].strip().upper()
    if not CUSTOMER_REF_RE.fullmatch(customer_ref):
        raise SanitizationError(
            f"row {row_number}: customer_ref must match CUS-[0-9]{{4}}"
        )

    email = values[1].strip().lower()
    if email.count("@") != 1 or any(ch.isspace() for ch in email):
        raise SanitizationError(
            f"row {row_number}: email must have exactly one @, nonempty sides, "
            "and no internal whitespace"
        )
    local, domain = email.split("@")
    if not local or not domain:
        raise SanitizationError(
            f"row {row_number}: email must have exactly one @, nonempty sides, "
            "and no internal whitespace"
        )

    region_key = values[2].strip().casefold()
    if region_key not in REGIONS:
        raise SanitizationError(f"row {row_number}: unsupported region {values[2].strip()!r}")
    region = REGIONS[region_key]

    display_name = collapsed(values[3])
    if not display_name:
        raise SanitizationError(f"row {row_number}: display_name is required")

    note = collapsed(values[4])

    status_key = values[5].strip().casefold()
    if status_key not in STATUSES:
        raise SanitizationError(f"row {row_number}: unsupported status {values[5].strip()!r}")
    status = STATUSES[status_key]

    return [customer_ref, email, region, display_name, note, status]


def parse_input(input_bytes: bytes) -> tuple[list[list[str]], int]:
    try:
        text = input_bytes.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise SanitizationError(f"input is not valid UTF-8 at byte {exc.start}") from exc

    validate_csv_quoting(text)
    reader = csv.reader(io.StringIO(text, newline=""), strict=True)
    try:
        header = next(reader)
    except StopIteration as exc:
        raise SanitizationError("input is empty; the exact six-column header is required") from exc
    except csv.Error as exc:
        raise SanitizationError(f"malformed CSV header: {exc}") from exc

    if header != HEADER:
        raise SanitizationError(
            "header must be exactly: " + ",".join(HEADER)
        )

    rows: list[list[str]] = []
    seen_refs: dict[str, int] = {}
    rows_read = 0
    try:
        for row in reader:
            if not row:
                continue
            rows_read += 1
            row_number = rows_read + 1
            if len(row) != len(HEADER):
                kind = "extra cell(s)" if len(row) > len(HEADER) else "missing cell(s)"
                raise SanitizationError(
                    f"row {row_number}: expected 6 cells, found {len(row)} ({kind})"
                )
            normalized = normalize_row(row, row_number)
            customer_ref = normalized[0]
            if customer_ref in seen_refs:
                raise SanitizationError(
                    f"row {row_number}: duplicate customer_ref {customer_ref}; "
                    f"first seen at row {seen_refs[customer_ref]}"
                )
            seen_refs[customer_ref] = row_number
            rows.append(normalized)
    except csv.Error as exc:
        raise SanitizationError(
            f"malformed CSV near physical line {reader.line_num}: {exc}"
        ) from exc

    rows.sort(key=lambda row: (row[2], row[5]))
    return rows, rows_read


def build_csv(rows: list[list[str]]) -> bytes:
    stream = io.StringIO(newline="")
    writer = csv.writer(stream, quoting=csv.QUOTE_MINIMAL, lineterminator="\n")
    writer.writerow(HEADER)
    writer.writerows(rows)
    return stream.getvalue().encode("utf-8")


def build_audit(input_bytes: bytes, output_bytes: bytes,
                rows: list[list[str]], rows_read: int) -> bytes:
    region_counts = {"NORTH": 0, "SOUTH": 0}
    status_counts = {"ACTIVE": 0, "PAUSED": 0}
    for row in rows:
        region_counts[row[2]] += 1
        status_counts[row[5]] += 1
    audit = {
        "schema_version": 1,
        "input_sha256": hashlib.sha256(input_bytes).hexdigest(),
        "output_sha256": hashlib.sha256(output_bytes).hexdigest(),
        "rows_read": rows_read,
        "rows_written": len(rows),
        "region_counts": region_counts,
        "status_counts": status_counts,
    }
    return (json.dumps(audit, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def remove_requested(path: Path, protected_input: Path) -> None:
    if path == protected_input:
        return
    try:
        path.unlink(missing_ok=True)
    except IsADirectoryError:
        # A directory is not a partial or stale requested output file.
        pass
    except OSError:
        # Preserve the original actionable failure; a later write will expose
        # destination problems on otherwise valid input.
        pass


def stage_bytes(path: Path, content: bytes) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
    except BaseException:
        temporary_path.unlink(missing_ok=True)
        raise
    return temporary_path


def write_artifacts(output_path: Path, audit_path: Path,
                    output_bytes: bytes, audit_bytes: bytes,
                    input_path: Path) -> None:
    output_temp: Path | None = None
    audit_temp: Path | None = None
    try:
        output_temp = stage_bytes(output_path, output_bytes)
        audit_temp = stage_bytes(audit_path, audit_bytes)
        os.replace(output_temp, output_path)
        output_temp = None
        os.replace(audit_temp, audit_path)
        audit_temp = None
    except BaseException:
        remove_requested(output_path, input_path)
        remove_requested(audit_path, input_path)
        raise
    finally:
        if output_temp is not None:
            output_temp.unlink(missing_ok=True)
        if audit_temp is not None:
            audit_temp.unlink(missing_ok=True)


def resolved(path_text: str) -> Path:
    return Path(path_text).expanduser().resolve(strict=False)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Normalize, validate, sort, and audit a customer export CSV."
    )
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--audit", required=True)
    args = parser.parse_args(argv)

    input_path = resolved(args.input)
    output_path = resolved(args.output)
    audit_path = resolved(args.audit)

    if len({input_path, output_path, audit_path}) != 3:
        # Never remove a path that resolves to the immutable input.
        remove_requested(output_path, input_path)
        remove_requested(audit_path, input_path)
        print("error: input, output, and audit must resolve to three distinct paths", file=sys.stderr)
        return 2

    # Rejections must remove artifacts left by earlier invocations.
    remove_requested(output_path, input_path)
    remove_requested(audit_path, input_path)

    try:
        input_bytes = input_path.read_bytes()
        rows, rows_read = parse_input(input_bytes)
        output_bytes = build_csv(rows)
        audit_bytes = build_audit(input_bytes, output_bytes, rows, rows_read)
        write_artifacts(
            output_path, audit_path, output_bytes, audit_bytes, input_path
        )
    except (SanitizationError, OSError) as exc:
        remove_requested(output_path, input_path)
        remove_requested(audit_path, input_path)
        print(f"error: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
