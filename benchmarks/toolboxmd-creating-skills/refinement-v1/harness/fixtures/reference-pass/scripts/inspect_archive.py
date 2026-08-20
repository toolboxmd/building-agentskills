#!/usr/bin/env python3
"""Inspect TAR or ZIP metadata without extracting or reading member payloads."""

import argparse
import json
from pathlib import Path
import re
import stat
import sys
import tarfile
import zipfile


def emit(status, archive_format, entry_count, declared_bytes, issues, exit_status):
    payload = {
        "schemaVersion": 1,
        "status": status,
        "format": archive_format,
        "entryCount": entry_count,
        "declaredBytes": declared_bytes,
        "issues": issues,
    }
    sys.stdout.write(json.dumps(payload, sort_keys=True, separators=(",", ":")) + "\n")
    return exit_status


def add_issue(issues, seen, code, member=None):
    key = (code, member)
    if key in seen:
        return
    seen.add(key)
    issue = {"code": code}
    if member is not None:
        issue["member"] = member
    issues.append(issue)


def canonical_member(name, issues, seen):
    if not name:
        add_issue(issues, seen, "PATH_EMPTY", name)
        return None
    if any(ord(character) < 32 or ord(character) == 127 for character in name):
        add_issue(issues, seen, "PATH_CONTROL", name)
    portable = name.replace("\\", "/")
    if portable.startswith("/") or portable.startswith("//") or re.match(r"^[A-Za-z]:(?:/|$)", portable):
        add_issue(issues, seen, "PATH_ABSOLUTE", name)
    parts = []
    for part in portable.split("/"):
        if part in ("", "."):
            continue
        if part == "..":
            add_issue(issues, seen, "PATH_PARENT", name)
            return None
        parts.append(part)
    if not parts:
        add_issue(issues, seen, "PATH_EMPTY", name)
        return None
    return "/".join(parts)


def inspect_names(rows, max_entries, max_total_bytes):
    issues = []
    seen_issues = set()
    normalized = set()
    folded = {}
    entry_count = len(rows)
    declared_bytes = sum(max(0, row[1]) for row in rows)
    if entry_count > max_entries:
        add_issue(issues, seen_issues, "ENTRY_LIMIT")
    if declared_bytes > max_total_bytes:
        add_issue(issues, seen_issues, "SIZE_LIMIT")
    for name, _size, kind, encrypted in rows:
        canonical = canonical_member(name, issues, seen_issues)
        if canonical is not None:
            if canonical in normalized:
                add_issue(issues, seen_issues, "PATH_DUPLICATE", name)
            normalized.add(canonical)
            folded_name = canonical.casefold()
            previous = folded.get(folded_name)
            if previous is not None and previous != canonical:
                add_issue(issues, seen_issues, "PATH_CASE_COLLISION", name)
            else:
                folded[folded_name] = canonical
        if kind == "link":
            add_issue(issues, seen_issues, "TYPE_LINK", name)
        elif kind == "special":
            add_issue(issues, seen_issues, "TYPE_SPECIAL", name)
        if encrypted:
            add_issue(issues, seen_issues, "ZIP_ENCRYPTED", name)
    return entry_count, declared_bytes, issues


def zip_rows(path):
    rows = []
    with zipfile.ZipFile(str(path), "r") as archive:
        for info in archive.infolist():
            mode = (info.external_attr >> 16) & 0xFFFF
            file_type = stat.S_IFMT(mode)
            if stat.S_ISLNK(mode):
                kind = "link"
            elif file_type and not (stat.S_ISREG(mode) or stat.S_ISDIR(mode)):
                kind = "special"
            elif info.is_dir():
                kind = "directory"
            else:
                kind = "regular"
            rows.append((info.filename, info.file_size, kind, bool(info.flag_bits & 1)))
    return rows


def tar_rows(path):
    rows = []
    with tarfile.open(str(path), "r:*") as archive:
        for info in archive.getmembers():
            if info.issym() or info.islnk():
                kind = "link"
            elif info.isreg():
                kind = "regular"
            elif info.isdir():
                kind = "directory"
            else:
                kind = "special"
            rows.append((info.name, info.size, kind, False))
    return rows


def main():
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument("--archive", required=True)
    parser.add_argument("--max-entries", required=True, type=int)
    parser.add_argument("--max-total-bytes", required=True, type=int)
    try:
        args = parser.parse_args()
    except SystemExit:
        return emit("error", "unknown", 0, 0, [{"code": "INPUT"}], 2)
    if args.max_entries < 1 or args.max_total_bytes < 1:
        return emit("error", "unknown", 0, 0, [{"code": "INPUT"}], 2)
    path = Path(args.archive)
    if not path.is_file():
        return emit("error", "unknown", 0, 0, [{"code": "INPUT"}], 2)
    try:
        if zipfile.is_zipfile(str(path)):
            archive_format = "zip"
            rows = zip_rows(path)
        elif tarfile.is_tarfile(str(path)):
            archive_format = "tar"
            rows = tar_rows(path)
        else:
            return emit("error", "unknown", 0, 0, [{"code": "ARCHIVE_INVALID"}], 2)
        entry_count, declared_bytes, issues = inspect_names(rows, args.max_entries, args.max_total_bytes)
    except (OSError, tarfile.TarError, zipfile.BadZipFile, ValueError):
        return emit("error", "unknown", 0, 0, [{"code": "ARCHIVE_INVALID"}], 2)
    if issues:
        return emit("unsafe", archive_format, entry_count, declared_bytes, issues, 1)
    return emit("safe", archive_format, entry_count, declared_bytes, [], 0)


if __name__ == "__main__":
    raise SystemExit(main())
