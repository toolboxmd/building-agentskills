#!/usr/bin/env python3
"""Grade a safe-archive-inspector candidate against frozen hidden fixtures."""

from __future__ import annotations

import argparse
import ast
from contextlib import redirect_stderr
from hashlib import sha256
import io
import json
import os
from pathlib import Path
import stat
import struct
import subprocess
import sys
import tarfile
import tempfile
import warnings
import zipfile


EXPECTED_FILES = ["SKILL.md", "scripts/inspect_archive.py"]
REQUIRED_FIELDS = {
    "schemaVersion",
    "status",
    "format",
    "entryCount",
    "declaredBytes",
    "issues",
}
FORBIDDEN_IMPORT_ROOTS = {
    "http",
    "requests",
    "socket",
    "subprocess",
    "urllib",
}
FORBIDDEN_MEMBER_METHODS = {"extract", "extractall", "extractfile"}


def file_sha(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


def tree_manifest(root: Path) -> dict:
    files = []
    symlinks = []
    nonregular = []
    for path in sorted(root.rglob("*"), key=lambda item: item.relative_to(root).as_posix().encode()):
        relative = path.relative_to(root).as_posix()
        mode = path.lstat().st_mode
        if stat.S_ISLNK(mode):
            symlinks.append({"path": relative, "target": os.readlink(path)})
        elif stat.S_ISREG(mode):
            files.append(
                {
                    "path": relative,
                    "bytes": path.stat().st_size,
                    "sha256": file_sha(path),
                }
            )
        elif not stat.S_ISDIR(mode):
            nonregular.append(relative)
    lines = "".join(f"{item['sha256']}  {item['path']}\n" for item in files)
    return {
        "files": files,
        "symlinks": symlinks,
        "nonregular": nonregular,
        "aggregateSha256": sha256(lines.encode()).hexdigest(),
        "bytes": sum(item["bytes"] for item in files),
    }


def regular_tar(path: Path, entries: list[tuple[str, bytes]]) -> None:
    with tarfile.open(path, "w") as archive:
        for name, payload in entries:
            info = tarfile.TarInfo(name)
            info.size = len(payload)
            archive.addfile(info, io.BytesIO(payload))


def typed_tar(path: Path, name: str, member_type: bytes, linkname: str = "") -> None:
    with tarfile.open(path, "w") as archive:
        info = tarfile.TarInfo(name)
        info.type = member_type
        info.linkname = linkname
        archive.addfile(info)


def regular_zip(path: Path, entries: list[tuple[str, bytes]]) -> None:
    with warnings.catch_warnings(), zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        warnings.simplefilter("ignore", UserWarning)
        for name, payload in entries:
            archive.writestr(name, payload)


def symlink_zip(path: Path) -> None:
    info = zipfile.ZipInfo("link")
    info.create_system = 3
    info.external_attr = (stat.S_IFLNK | 0o777) << 16
    with zipfile.ZipFile(path, "w") as archive:
        archive.writestr(info, "../outside")


def encrypted_flag_zip(path: Path) -> None:
    regular_zip(path, [("secret.txt", b"metadata-only")])
    data = bytearray(path.read_bytes())
    local = data.find(b"PK\x03\x04")
    central = data.find(b"PK\x01\x02")
    if local < 0 or central < 0:
        raise RuntimeError("ZIP signatures missing")
    local_flags = struct.unpack_from("<H", data, local + 6)[0] | 1
    central_flags = struct.unpack_from("<H", data, central + 8)[0] | 1
    struct.pack_into("<H", data, local + 6, local_flags)
    struct.pack_into("<H", data, central + 8, central_flags)
    path.write_bytes(data)


def issue_codes(payload: dict | None) -> set[str]:
    if not isinstance(payload, dict) or not isinstance(payload.get("issues"), list):
        return set()
    result = set()
    for issue in payload["issues"]:
        if isinstance(issue, dict) and isinstance(issue.get("code"), str):
            result.add(issue["code"])
        elif isinstance(issue, str):
            result.add(issue)
    return result


def invoke(
    script: Path,
    archive: Path,
    *,
    max_entries: str = "100",
    max_total_bytes: str = "1000000",
) -> dict:
    cwd = archive.parent
    before = sorted(path.relative_to(cwd).as_posix() for path in cwd.rglob("*") if path.is_file())
    marker = cwd.parent / f"archive-grader-escape-{archive.stem}"
    if marker.exists():
        marker.unlink()
    argv = [
        "/usr/bin/python3",
        str(script),
        "--archive",
        str(archive),
        "--max-entries",
        max_entries,
        "--max-total-bytes",
        max_total_bytes,
    ]
    try:
        completed = subprocess.run(
            argv,
            cwd=cwd,
            env={
                "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
                "PYTHONDONTWRITEBYTECODE": "1",
                "LANG": "C",
                "LC_ALL": "C",
            },
            text=True,
            capture_output=True,
            timeout=4,
        )
        timed_out = False
    except subprocess.TimeoutExpired as exc:
        return {
            "exitStatus": None,
            "timedOut": True,
            "stdout": exc.stdout or "",
            "stderr": exc.stderr or "",
            "payload": None,
            "oneJsonLine": False,
            "filesystemChanged": True,
            "escapeMarkerExists": marker.exists(),
        }
    stdout = completed.stdout
    payload = None
    lines = stdout.splitlines()
    one_json_line = len(lines) == 1 and stdout.endswith("\n")
    if one_json_line:
        try:
            payload = json.loads(lines[0])
        except json.JSONDecodeError:
            payload = None
    after = sorted(path.relative_to(cwd).as_posix() for path in cwd.rglob("*") if path.is_file())
    return {
        "exitStatus": completed.returncode,
        "timedOut": timed_out,
        "stdout": stdout,
        "stderr": completed.stderr,
        "payload": payload,
        "oneJsonLine": one_json_line,
        "filesystemChanged": before != after,
        "escapeMarkerExists": marker.exists(),
    }


def result_summary(result: dict) -> dict:
    payload = result.get("payload")
    return {
        "exitStatus": result.get("exitStatus"),
        "timedOut": result.get("timedOut"),
        "stderrEmpty": result.get("stderr") == "",
        "oneJsonLine": result.get("oneJsonLine"),
        "filesystemChanged": result.get("filesystemChanged"),
        "escapeMarkerExists": result.get("escapeMarkerExists"),
        "status": payload.get("status") if isinstance(payload, dict) else None,
        "format": payload.get("format") if isinstance(payload, dict) else None,
        "entryCount": payload.get("entryCount") if isinstance(payload, dict) else None,
        "declaredBytes": payload.get("declaredBytes") if isinstance(payload, dict) else None,
        "issueCodes": sorted(issue_codes(payload)),
        "requiredFieldsPresent": isinstance(payload, dict) and REQUIRED_FIELDS <= set(payload),
    }


def case_passed(result: dict, *, exit_status: int, status_value: str, issue: str | None = None) -> bool:
    payload = result.get("payload")
    return bool(
        not result.get("timedOut")
        and result.get("exitStatus") == exit_status
        and result.get("stderr") == ""
        and result.get("oneJsonLine")
        and not result.get("filesystemChanged")
        and not result.get("escapeMarkerExists")
        and isinstance(payload, dict)
        and REQUIRED_FIELDS <= set(payload)
        and payload.get("schemaVersion") == 1
        and payload.get("status") == status_value
        and isinstance(payload.get("entryCount"), int)
        and isinstance(payload.get("declaredBytes"), int)
        and (issue is None or issue in issue_codes(payload))
    )


def add_check(checks: dict, name: str, *, points: int, critical: bool, passed: bool, detail: object) -> None:
    checks[name] = {
        "critical": critical,
        "passed": bool(passed),
        "pointsAvailable": points,
        "pointsAwarded": points if passed else 0,
        "detail": detail,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    candidate = args.candidate.resolve()
    output = args.output.resolve()
    if not candidate.is_dir():
        raise SystemExit(f"candidate is not a directory: {candidate}")
    output.parent.mkdir(parents=True, exist_ok=True)

    manifest = tree_manifest(candidate)
    paths = [item["path"] for item in manifest["files"]]
    skill = candidate / "SKILL.md"
    script = candidate / "scripts/inspect_archive.py"
    checks = {}

    shape_passed = (
        paths == EXPECTED_FILES
        and not manifest["symlinks"]
        and not manifest["nonregular"]
        and manifest["bytes"] <= 30000
    )
    add_check(
        checks,
        "exact-portable-package",
        points=8,
        critical=True,
        passed=shape_passed,
        detail={"files": paths, "bytes": manifest["bytes"], "symlinks": manifest["symlinks"], "nonregular": manifest["nonregular"]},
    )

    syntax_error = None
    forbidden_imports = []
    forbidden_calls = []
    executable = script.exists() and os.access(script, os.X_OK)
    if script.is_file():
        try:
            source = script.read_text(encoding="utf-8")
            tree = ast.parse(source)
            for node in ast.walk(tree):
                if isinstance(node, ast.Import):
                    forbidden_imports.extend(alias.name for alias in node.names if alias.name.split(".")[0] in FORBIDDEN_IMPORT_ROOTS)
                elif isinstance(node, ast.ImportFrom) and node.module and node.module.split(".")[0] in FORBIDDEN_IMPORT_ROOTS:
                    forbidden_imports.append(node.module)
                elif isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr in FORBIDDEN_MEMBER_METHODS:
                    forbidden_calls.append(node.func.attr)
        except (UnicodeDecodeError, SyntaxError) as exc:
            syntax_error = f"{type(exc).__name__}: {exc}"
    else:
        syntax_error = "missing helper"
    static_passed = executable and syntax_error is None and not forbidden_imports and not forbidden_calls
    add_check(
        checks,
        "executable-stdlib-metadata-only-helper",
        points=8,
        critical=True,
        passed=static_passed,
        detail={"executable": executable, "syntaxError": syntax_error, "forbiddenImports": forbidden_imports, "forbiddenCalls": forbidden_calls},
    )

    name = None
    description = None
    lines = []
    if skill.is_file():
        try:
            text = skill.read_text(encoding="utf-8")
            lines = text.splitlines()
            if lines and lines[0] == "---":
                for line in lines[1:]:
                    if line == "---":
                        break
                    if line.startswith("name:"):
                        name = json.loads(line.split(":", 1)[1].strip())
                    if line.startswith("description:"):
                        description = json.loads(line.split(":", 1)[1].strip())
        except (UnicodeDecodeError, json.JSONDecodeError):
            pass
    description_lower = description.lower() if isinstance(description, str) else ""
    interface_passed = bool(
        name == "safe-archive-inspector"
        and isinstance(description, str)
        and len(description) <= 400
        and len(lines) <= 150
        and skill.stat().st_size <= 10500
        and any(word in description_lower for word in ("untrusted", "archive", "tar", "zip"))
        and any(word in description_lower for word in ("do not", "don't", "not use", "not for"))
    )
    add_check(
        checks,
        "portable-frontmatter-and-activation-boundary",
        points=6,
        critical=True,
        passed=interface_passed,
        detail={"name": name, "description": description, "skillLines": len(lines), "skillBytes": skill.stat().st_size if skill.is_file() else None},
    )

    case_results = {}
    if script.is_file():
        with tempfile.TemporaryDirectory(prefix="archive-grade-") as temporary:
            root = Path(temporary)
            fixtures = root / "fixtures"
            fixtures.mkdir()

            regular_tar(fixtures / "safe.tar", [("docs/readme.txt", b"hello"), ("data/value.json", b"{}")])
            regular_zip(fixtures / "safe.zip", [("docs/readme.txt", b"hello"), ("data/value.json", b"{}")])
            regular_tar(fixtures / "parent.tar", [("../escape", b"x")])
            regular_tar(fixtures / "absolute.tar", [("/absolute", b"x")])
            regular_zip(fixtures / "backslash-parent.zip", [("..\\escape.txt", b"x")])
            regular_zip(fixtures / "windows-drive.zip", [("C:\\Users\\escape.txt", b"x")])
            typed_tar(fixtures / "symlink.tar", "link", tarfile.SYMTYPE, "../outside")
            typed_tar(fixtures / "hardlink.tar", "hard", tarfile.LNKTYPE, "target")
            typed_tar(fixtures / "fifo.tar", "pipe", tarfile.FIFOTYPE)
            symlink_zip(fixtures / "symlink.zip")
            encrypted_flag_zip(fixtures / "encrypted.zip")
            regular_zip(fixtures / "duplicate.zip", [("same.txt", b"one"), ("same.txt", b"two")])
            regular_zip(fixtures / "case-collision.zip", [("A.txt", b"one"), ("a.txt", b"two")])
            regular_zip(fixtures / "many.zip", [("1", b"1"), ("2", b"2"), ("3", b"3")])
            regular_zip(fixtures / "large.zip", [("large.bin", b"x" * 64)])
            (fixtures / "corrupt.bin").write_bytes(b"not an archive\x00\x01")

            matrix = [
                ("safe-tar", "safe.tar", 0, "safe", None, "100", "1000000"),
                ("safe-zip", "safe.zip", 0, "safe", None, "100", "1000000"),
                ("parent", "parent.tar", 1, "unsafe", "PATH_PARENT", "100", "1000000"),
                ("absolute", "absolute.tar", 1, "unsafe", "PATH_ABSOLUTE", "100", "1000000"),
                ("backslash-parent", "backslash-parent.zip", 1, "unsafe", "PATH_PARENT", "100", "1000000"),
                ("windows-drive", "windows-drive.zip", 1, "unsafe", "PATH_ABSOLUTE", "100", "1000000"),
                ("symlink-tar", "symlink.tar", 1, "unsafe", "TYPE_LINK", "100", "1000000"),
                ("hardlink-tar", "hardlink.tar", 1, "unsafe", "TYPE_LINK", "100", "1000000"),
                ("fifo-tar", "fifo.tar", 1, "unsafe", "TYPE_SPECIAL", "100", "1000000"),
                ("symlink-zip", "symlink.zip", 1, "unsafe", "TYPE_LINK", "100", "1000000"),
                ("encrypted-zip", "encrypted.zip", 1, "unsafe", "ZIP_ENCRYPTED", "100", "1000000"),
                ("duplicate", "duplicate.zip", 1, "unsafe", "PATH_DUPLICATE", "100", "1000000"),
                ("case-collision", "case-collision.zip", 1, "unsafe", "PATH_CASE_COLLISION", "100", "1000000"),
                ("entry-limit", "many.zip", 1, "unsafe", "ENTRY_LIMIT", "2", "1000000"),
                ("size-limit", "large.zip", 1, "unsafe", "SIZE_LIMIT", "100", "10"),
                ("corrupt", "corrupt.bin", 2, "error", "ARCHIVE_INVALID", "100", "1000000"),
            ]
            for case_id, filename, exit_status, status_value, issue, max_entries, max_bytes in matrix:
                result = invoke(script, fixtures / filename, max_entries=max_entries, max_total_bytes=max_bytes)
                case_results[case_id] = {
                    "passed": case_passed(result, exit_status=exit_status, status_value=status_value, issue=issue),
                    "expected": {"exitStatus": exit_status, "status": status_value, "issue": issue},
                    "actual": result_summary(result),
                }

            missing = invoke(script, fixtures / "missing.zip")
            invalid_limit = invoke(script, fixtures / "safe.zip", max_entries="0")
            case_results["missing-input"] = {
                "passed": case_passed(missing, exit_status=2, status_value="error", issue="INPUT"),
                "expected": {"exitStatus": 2, "status": "error", "issue": "INPUT"},
                "actual": result_summary(missing),
            }
            case_results["invalid-limit"] = {
                "passed": case_passed(invalid_limit, exit_status=2, status_value="error", issue="INPUT"),
                "expected": {"exitStatus": 2, "status": "error", "issue": "INPUT"},
                "actual": result_summary(invalid_limit),
            }

    def passed(*case_ids: str) -> bool:
        return all(case_results.get(case_id, {}).get("passed") is True for case_id in case_ids)

    add_check(checks, "safe-tar-and-zip", points=10, critical=True, passed=passed("safe-tar", "safe-zip"), detail={key: case_results.get(key) for key in ("safe-tar", "safe-zip")})
    add_check(checks, "portable-path-rejection", points=10, critical=True, passed=passed("parent", "absolute", "backslash-parent", "windows-drive"), detail={key: case_results.get(key) for key in ("parent", "absolute", "backslash-parent", "windows-drive")})
    add_check(checks, "links-special-and-encrypted", points=8, critical=True, passed=passed("symlink-tar", "hardlink-tar", "fifo-tar", "symlink-zip", "encrypted-zip"), detail={key: case_results.get(key) for key in ("symlink-tar", "hardlink-tar", "fifo-tar", "symlink-zip", "encrypted-zip")})
    add_check(checks, "ambiguous-member-names", points=6, critical=True, passed=passed("duplicate", "case-collision"), detail={key: case_results.get(key) for key in ("duplicate", "case-collision")})
    add_check(checks, "metadata-resource-limits", points=8, critical=True, passed=passed("entry-limit", "size-limit"), detail={key: case_results.get(key) for key in ("entry-limit", "size-limit")})
    add_check(checks, "stable-error-contract", points=4, critical=True, passed=passed("corrupt", "missing-input", "invalid-limit"), detail={key: case_results.get(key) for key in ("corrupt", "missing-input", "invalid-limit")})
    no_side_effects = bool(case_results) and all(
        not row["actual"]["filesystemChanged"] and not row["actual"]["escapeMarkerExists"]
        for row in case_results.values()
    )
    add_check(checks, "no-extraction-side-effects", points=2, critical=True, passed=no_side_effects, detail={"allCasesFilesystemStable": no_side_effects})

    available = sum(check["pointsAvailable"] for check in checks.values())
    awarded = sum(check["pointsAwarded"] for check in checks.values())
    critical_failures = [name for name, check in checks.items() if check["critical"] and not check["passed"]]
    report = {
        "schemaVersion": 1,
        "candidateAggregateSha256": manifest["aggregateSha256"],
        "deterministicPointsAvailable": available,
        "deterministicPointsAwarded": awarded,
        "criticalFailures": critical_failures,
        "recommendableArtifact": not critical_failures and awarded >= 63,
        "checks": checks,
        "caseResults": case_results,
    }
    output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"points": f"{awarded}/{available}", "criticalFailures": critical_failures, "recommendableArtifact": report["recommendableArtifact"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
