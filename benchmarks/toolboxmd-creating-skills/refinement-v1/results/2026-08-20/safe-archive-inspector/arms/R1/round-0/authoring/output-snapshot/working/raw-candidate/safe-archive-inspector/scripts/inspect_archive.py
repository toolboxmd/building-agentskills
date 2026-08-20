#!/usr/bin/env python3
"""Inspect TAR/ZIP metadata without extracting or opening member payloads."""

import json
import os
import re
import stat
import sys
import tarfile
import zipfile


SCHEMA_VERSION = 1
ISSUE_ORDER = (
    "INPUT",
    "ARCHIVE_INVALID",
    "PATH_EMPTY",
    "PATH_ABSOLUTE",
    "PATH_PARENT",
    "PATH_CONTROL",
    "PATH_DUPLICATE",
    "PATH_CASE_COLLISION",
    "TYPE_LINK",
    "TYPE_SPECIAL",
    "ZIP_ENCRYPTED",
    "ENTRY_LIMIT",
    "SIZE_LIMIT",
)
DRIVE = re.compile(r"^[A-Za-z]:")


def emit(status, archive_format, count, size, issues):
    ordered = [code for code in ISSUE_ORDER if code in issues]
    result = {
        "schemaVersion": SCHEMA_VERSION,
        "status": status,
        "format": archive_format,
        "entryCount": count,
        "declaredBytes": size,
        "issues": ordered,
    }
    sys.stdout.write(json.dumps(result, separators=(",", ":")) + "\n")


def parse_args(argv):
    values = {}
    index = 0
    allowed = {"--archive", "--max-entries", "--max-total-bytes"}
    while index < len(argv):
        option = argv[index]
        if option not in allowed or option in values or index + 1 >= len(argv):
            return None
        values[option] = argv[index + 1]
        index += 2
    if set(values) != allowed:
        return None
    try:
        max_entries = int(values["--max-entries"], 10)
        max_bytes = int(values["--max-total-bytes"], 10)
    except ValueError:
        return None
    if max_entries <= 0 or max_bytes <= 0:
        return None
    return values["--archive"], max_entries, max_bytes


def check_name(name, exact_names, folded_names, issues):
    if any(ord(char) < 32 or ord(char) == 127 for char in name):
        issues.add("PATH_CONTROL")
    slashed = name.replace("\\", "/")
    if slashed.startswith("/") or slashed.startswith("//") or DRIVE.match(slashed):
        issues.add("PATH_ABSOLUTE")
    parts = slashed.split("/")
    if ".." in parts:
        issues.add("PATH_PARENT")
    normalized = "/".join(part for part in parts if part not in ("", "."))
    if not normalized:
        issues.add("PATH_EMPTY")
    if normalized in exact_names:
        issues.add("PATH_DUPLICATE")
    else:
        folded = normalized.casefold()
        prior = folded_names.get(folded)
        if prior is not None and prior != normalized:
            issues.add("PATH_CASE_COLLISION")
        exact_names.add(normalized)
        folded_names.setdefault(folded, normalized)


def inspect_zip(path, max_entries, max_bytes):
    issues = set()
    exact_names = set()
    folded_names = {}
    count = 0
    total = 0
    with zipfile.ZipFile(path, "r") as archive:
        for member in archive.infolist():
            count += 1
            total += member.file_size
            check_name(member.filename, exact_names, folded_names, issues)
            mode = member.external_attr >> 16
            kind = stat.S_IFMT(mode)
            if kind == stat.S_IFLNK:
                issues.add("TYPE_LINK")
            elif kind not in (0, stat.S_IFREG, stat.S_IFDIR):
                issues.add("TYPE_SPECIAL")
            elif member.is_dir() and kind == stat.S_IFREG:
                issues.add("TYPE_SPECIAL")
            elif not member.is_dir() and kind == stat.S_IFDIR:
                issues.add("TYPE_SPECIAL")
            if member.flag_bits & 0x1:
                issues.add("ZIP_ENCRYPTED")
    if count > max_entries:
        issues.add("ENTRY_LIMIT")
    if total > max_bytes:
        issues.add("SIZE_LIMIT")
    return count, total, issues


def inspect_tar(path, max_entries, max_bytes):
    issues = set()
    exact_names = set()
    folded_names = {}
    count = 0
    total = 0
    with tarfile.open(path, "r:*") as archive:
        for member in archive.getmembers():
            count += 1
            if member.size < 0:
                raise tarfile.ReadError("negative member size")
            total += member.size
            check_name(member.name, exact_names, folded_names, issues)
            if member.issym() or member.islnk():
                issues.add("TYPE_LINK")
            elif not (member.isfile() or member.isdir()):
                issues.add("TYPE_SPECIAL")
    if count > max_entries:
        issues.add("ENTRY_LIMIT")
    if total > max_bytes:
        issues.add("SIZE_LIMIT")
    return count, total, issues


def main(argv):
    parsed = parse_args(argv)
    if parsed is None:
        emit("error", "unknown", 0, 0, {"INPUT"})
        return 2
    path, max_entries, max_bytes = parsed
    if not os.path.isfile(path):
        emit("error", "unknown", 0, 0, {"INPUT"})
        return 2

    archive_format = "unknown"
    try:
        if zipfile.is_zipfile(path):
            archive_format = "zip"
            count, total, issues = inspect_zip(path, max_entries, max_bytes)
        else:
            archive_format = "tar"
            count, total, issues = inspect_tar(path, max_entries, max_bytes)
    except (tarfile.TarError, zipfile.BadZipFile, EOFError, ValueError, OverflowError):
        emit("error", archive_format, 0, 0, {"ARCHIVE_INVALID"})
        return 2
    except OSError:
        emit("error", archive_format, 0, 0, {"INPUT"})
        return 2

    if issues:
        emit("unsafe", archive_format, count, total, issues)
        return 1
    emit("safe", archive_format, count, total, issues)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
