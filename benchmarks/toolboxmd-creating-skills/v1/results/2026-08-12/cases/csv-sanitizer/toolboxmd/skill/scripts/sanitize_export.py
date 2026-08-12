#!/usr/bin/env python3
"""Validate and canonicalize a LumenDesk customer export."""

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


HEADER = (
    "customer_ref",
    "email",
    "region",
    "display_name",
    "note",
    "status",
)
CUSTOMER_REF_RE = re.compile(r"CUS-[0-9]{4}\Z")
WHITESPACE_RE = re.compile(r"\s+")
REGIONS = {"north": "NORTH", "n": "NORTH", "nord": "NORTH",
           "south": "SOUTH", "s": "SOUTH", "sud": "SOUTH"}
STATUSES = {"active": "ACTIVE", "enabled": "ACTIVE",
            "paused": "PAUSED", "hold": "PAUSED"}


class SanitizationError(Exception):
    """An actionable input, path, or output error."""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Sanitize a LumenDesk customer-export CSV and write its audit JSON."
    )
    parser.add_argument("--input", required=True, type=Path, help="source CSV path")
    parser.add_argument("--output", required=True, type=Path, help="canonical CSV path")
    parser.add_argument("--audit", required=True, type=Path, help="audit JSON path")
    return parser.parse_args()


def remove_requested(path: Path) -> None:
    """Remove a requested artifact without following a symlink."""
    try:
        path.unlink(missing_ok=True)
    except OSError:
        # Preserve the original error; cleanup is retried and reported by main.
        pass


def normalize_text(value: str) -> str:
    return unicodedata.normalize("NFKC", value)


def normalize_row(row: list[str], row_number: int) -> tuple[str, ...]:
    if len(row) != len(HEADER):
        detail = "extra cell(s)" if len(row) > len(HEADER) else "missing cell(s)"
        raise SanitizationError(
            f"row {row_number}: expected {len(HEADER)} cells, found {len(row)} ({detail})"
        )

    customer_ref, email, region, display_name, note, status = map(normalize_text, row)

    customer_ref = customer_ref.strip().upper()
    if not CUSTOMER_REF_RE.fullmatch(customer_ref):
        raise SanitizationError(
            f"row {row_number}: invalid customer_ref {customer_ref!r}; expected CUS-0000 format"
        )

    email = email.strip().lower()
    if email.count("@") != 1 or any(ch.isspace() for ch in email):
        raise SanitizationError(
            f"row {row_number}: invalid email {email!r}; require one @, nonempty sides, and no whitespace"
        )
    local, domain = email.split("@")
    if not local or not domain:
        raise SanitizationError(
            f"row {row_number}: invalid email {email!r}; both sides of @ are required"
        )

    region_key = region.strip().casefold()
    if region_key not in REGIONS:
        raise SanitizationError(
            f"row {row_number}: unsupported region {region.strip()!r}"
        )
    region = REGIONS[region_key]

    display_name = WHITESPACE_RE.sub(" ", display_name.strip())
    if not display_name:
        raise SanitizationError(f"row {row_number}: display_name is required")

    note = WHITESPACE_RE.sub(" ", note.strip())

    status_key = status.strip().casefold()
    if status_key not in STATUSES:
        raise SanitizationError(
            f"row {row_number}: unsupported status {status.strip()!r}"
        )
    status = STATUSES[status_key]

    return customer_ref, email, region, display_name, note, status


def validate_csv_quotes(text: str) -> None:
    """Reject quote placement outside RFC 4180's field grammar."""
    state = "field_start"
    line = 1
    index = 0
    while index < len(text):
        character = text[index]
        newline = character in "\r\n"

        if state == "field_start":
            if character == '"':
                state = "quoted"
            elif character == ",":
                pass
            elif newline:
                pass
            else:
                state = "unquoted"
        elif state == "unquoted":
            if character == '"':
                raise SanitizationError(
                    f"malformed CSV at line {line}: quote inside an unquoted field"
                )
            if character == ",":
                state = "field_start"
            elif newline:
                state = "field_start"
        elif state == "quoted":
            if character == '"':
                state = "after_quote"
        else:  # after_quote
            if character == '"':
                state = "quoted"
            elif character == ",":
                state = "field_start"
            elif newline:
                state = "field_start"
            else:
                raise SanitizationError(
                    f"malformed CSV at line {line}: unexpected character after closing quote"
                )

        if character == "\r":
            if index + 1 < len(text) and text[index + 1] == "\n":
                index += 1
            line += 1
        elif character == "\n":
            line += 1
        index += 1

    if state == "quoted":
        raise SanitizationError(f"malformed CSV at line {line}: unterminated quoted field")


def parse_input(input_bytes: bytes) -> tuple[list[tuple[str, ...]], int]:
    try:
        text = input_bytes.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise SanitizationError(
            f"input is not valid UTF-8 at byte {exc.start}"
        ) from exc

    validate_csv_quotes(text)
    try:
        reader = csv.reader(io.StringIO(text, newline=""), strict=True)
        records = [(reader.line_num, row) for row in reader if row]
    except csv.Error as exc:
        raise SanitizationError(f"malformed CSV near line {reader.line_num}: {exc}") from exc

    if not records:
        raise SanitizationError("input is empty or contains only blank lines; header is required")

    header_line, header = records[0]
    if tuple(header) != HEADER:
        raise SanitizationError(
            f"line {header_line}: invalid header; expected {','.join(HEADER)} in that order"
        )

    normalized_rows: list[tuple[str, ...]] = []
    seen_refs: dict[str, int] = {}
    for row_number, row in records[1:]:
        normalized = normalize_row(row, row_number)
        customer_ref = normalized[0]
        if customer_ref in seen_refs:
            raise SanitizationError(
                f"row {row_number}: duplicate customer_ref {customer_ref!r} "
                f"after normalization (first seen on row {seen_refs[customer_ref]})"
            )
        seen_refs[customer_ref] = row_number
        normalized_rows.append(normalized)

    return normalized_rows, len(records) - 1


def make_csv(rows: list[tuple[str, ...]]) -> bytes:
    stream = io.StringIO(newline="")
    writer = csv.writer(stream, lineterminator="\n", quoting=csv.QUOTE_MINIMAL)
    writer.writerow(HEADER)
    writer.writerows(sorted(rows, key=lambda row: (row[2], row[5])))
    return stream.getvalue().encode("utf-8")


def make_audit(input_bytes: bytes, output_bytes: bytes,
               rows: list[tuple[str, ...]], rows_read: int) -> bytes:
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


def resolved_paths(args: argparse.Namespace) -> tuple[Path, Path, Path]:
    input_path = Path(os.path.abspath(args.input))
    output_path = Path(os.path.abspath(args.output))
    audit_path = Path(os.path.abspath(args.audit))
    if len({path.resolve() for path in (input_path, output_path, audit_path)}) != 3:
        raise SanitizationError(
            "--input, --output, and --audit must resolve to three distinct paths"
        )
    return input_path, output_path, audit_path


def stage_bytes(path: Path, data: bytes) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        descriptor, temporary_name = tempfile.mkstemp(
            prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
        )
        temporary_path = Path(temporary_name)
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        return temporary_path
    except OSError as exc:
        if "temporary_path" in locals():
            remove_requested(temporary_path)
        raise SanitizationError(f"cannot stage {path}: {exc}") from exc


def write_artifacts(output_path: Path, audit_path: Path,
                    output_bytes: bytes, audit_bytes: bytes) -> None:
    output_temp: Path | None = None
    audit_temp: Path | None = None
    try:
        output_temp = stage_bytes(output_path, output_bytes)
        audit_temp = stage_bytes(audit_path, audit_bytes)
        os.replace(output_temp, output_path)
        output_temp = None
        os.replace(audit_temp, audit_path)
        audit_temp = None
    except (OSError, SanitizationError) as exc:
        remove_requested(output_path)
        remove_requested(audit_path)
        if isinstance(exc, SanitizationError):
            raise
        raise SanitizationError(f"cannot replace requested artifacts: {exc}") from exc
    finally:
        if output_temp is not None:
            remove_requested(output_temp)
        if audit_temp is not None:
            remove_requested(audit_temp)


def run(args: argparse.Namespace) -> None:
    input_path, output_path, audit_path = resolved_paths(args)
    try:
        input_bytes = input_path.read_bytes()
    except OSError as exc:
        raise SanitizationError(f"cannot read input {input_path}: {exc}") from exc

    rows, rows_read = parse_input(input_bytes)
    output_bytes = make_csv(rows)
    audit_bytes = make_audit(input_bytes, output_bytes, rows, rows_read)
    write_artifacts(output_path, audit_path, output_bytes, audit_bytes)


def main() -> int:
    args = parse_args()
    try:
        _, output_path, audit_path = resolved_paths(args)
    except SanitizationError as exc:
        # Remove aliases such as output symlinks, but never unlink the input itself.
        input_path = Path(os.path.abspath(args.input))
        candidates = {Path(os.path.abspath(args.output)), Path(os.path.abspath(args.audit))}
        for candidate in candidates:
            if candidate != input_path:
                remove_requested(candidate)
        print(f"error: {exc}", file=sys.stderr)
        return 2

    try:
        run(args)
    except SanitizationError as exc:
        remove_requested(output_path)
        remove_requested(audit_path)
        print(f"error: {exc}", file=sys.stderr)
        return 1
    except Exception as exc:  # Keep the no-stale-artifacts guarantee for unexpected failures.
        remove_requested(output_path)
        remove_requested(audit_path)
        print(f"error: unexpected failure: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
