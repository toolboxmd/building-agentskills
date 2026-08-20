#!/usr/bin/env python3
"""Fail-closed, metadata-only TAR/ZIP inspector."""

import argparse
import json
import os
import re
import stat
import sys
import tarfile
import zipfile


SCHEMA_VERSION = 1
ISSUE_ORDER = (
    "INPUT", "ARCHIVE_INVALID", "PATH_EMPTY", "PATH_ABSOLUTE",
    "PATH_PARENT", "PATH_CONTROL", "PATH_DUPLICATE",
    "PATH_CASE_COLLISION", "TYPE_LINK", "TYPE_SPECIAL",
    "ZIP_ENCRYPTED", "ENTRY_LIMIT", "SIZE_LIMIT",
)
DRIVE_RE = re.compile(r"^[A-Za-z]:")


class QuietParser(argparse.ArgumentParser):
    def error(self, message):
        raise ValueError(message)


def emit(status, archive_format, entry_count, declared_bytes, issues):
    ordered = [code for code in ISSUE_ORDER if code in issues]
    result = {
        "schemaVersion": SCHEMA_VERSION,
        "status": status,
        "format": archive_format,
        "entryCount": entry_count,
        "declaredBytes": declared_bytes,
        "issues": ordered,
    }
    sys.stdout.write(json.dumps(result, separators=(",", ":")) + "\n")


def positive_int(value):
    try:
        number = int(value, 10)
    except (TypeError, ValueError):
        raise argparse.ArgumentTypeError("must be a positive integer")
    if number <= 0:
        raise argparse.ArgumentTypeError("must be a positive integer")
    return number


def normalized_name(name, issues):
    if not isinstance(name, str) or not name:
        issues.add("PATH_EMPTY")
        return None
    if any(ord(character) < 32 or ord(character) == 127 for character in name):
        issues.add("PATH_CONTROL")

    slash_name = name.replace("\\", "/")
    if slash_name.startswith("/") or DRIVE_RE.match(slash_name):
        issues.add("PATH_ABSOLUTE")
    components = slash_name.split("/")
    if ".." in components:
        issues.add("PATH_PARENT")
    normalized = "/".join(part for part in components if part not in ("", "."))
    if not normalized:
        issues.add("PATH_EMPTY")
        return None
    return normalized


def inspect_names(name, seen_exact, seen_folded, issues):
    normalized = normalized_name(name, issues)
    if normalized is None:
        return
    folded = normalized.casefold()
    if normalized in seen_exact:
        issues.add("PATH_DUPLICATE")
    elif folded in seen_folded:
        issues.add("PATH_CASE_COLLISION")
    seen_exact.add(normalized)
    seen_folded.add(folded)


def inspect_zip(path):
    issues = set()
    count = 0
    total = 0
    seen_exact = set()
    seen_folded = set()
    with zipfile.ZipFile(path, "r") as archive:
        for member in archive.infolist():
            count += 1
            if member.file_size < 0:
                raise zipfile.BadZipFile("negative declared size")
            total += member.file_size
            inspect_names(member.filename, seen_exact, seen_folded, issues)
            if member.flag_bits & 0x1:
                issues.add("ZIP_ENCRYPTED")

            mode = (member.external_attr >> 16) & 0xFFFF
            kind = stat.S_IFMT(mode) if member.create_system == 3 else 0
            if kind == stat.S_IFLNK:
                issues.add("TYPE_LINK")
            elif member.is_dir():
                if kind not in (0, stat.S_IFDIR):
                    issues.add("TYPE_SPECIAL")
            elif kind not in (0, stat.S_IFREG):
                issues.add("TYPE_SPECIAL")
    return count, total, issues


def inspect_tar(path):
    issues = set()
    count = 0
    total = 0
    seen_exact = set()
    seen_folded = set()
    with tarfile.open(path, mode="r:*") as archive:
        for member in archive:
            count += 1
            if member.size < 0:
                raise tarfile.ReadError("negative declared size")
            total += member.size
            inspect_names(member.name, seen_exact, seen_folded, issues)
            if member.issym() or member.islnk():
                issues.add("TYPE_LINK")
            elif not (member.isfile() or member.isdir()):
                issues.add("TYPE_SPECIAL")
    return count, total, issues


def inspect(path):
    if zipfile.is_zipfile(path):
        return "zip", inspect_zip(path)
    return "tar", inspect_tar(path)


def main(argv=None):
    parser = QuietParser(add_help=False, allow_abbrev=False)
    parser.add_argument("--archive", required=True)
    parser.add_argument("--max-entries", required=True, type=positive_int)
    parser.add_argument("--max-total-bytes", required=True, type=positive_int)
    try:
        args = parser.parse_args(argv)
    except (SystemExit, ValueError):
        emit("error", "unknown", 0, 0, {"INPUT"})
        return 2

    if not os.path.isfile(args.archive):
        emit("error", "unknown", 0, 0, {"INPUT"})
        return 2

    archive_format = "unknown"
    try:
        archive_format, (count, total, issues) = inspect(args.archive)
    except (OSError, EOFError, ValueError, tarfile.TarError, zipfile.BadZipFile,
            zipfile.LargeZipFile):
        emit("error", archive_format, 0, 0, {"ARCHIVE_INVALID"})
        return 2

    if count > args.max_entries:
        issues.add("ENTRY_LIMIT")
    if total > args.max_total_bytes:
        issues.add("SIZE_LIMIT")
    if issues:
        emit("unsafe", archive_format, count, total, issues)
        return 1
    emit("safe", archive_format, count, total, issues)
    return 0


if __name__ == "__main__":
    sys.exit(main())
