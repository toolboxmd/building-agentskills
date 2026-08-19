#!/usr/bin/env python3
"""Fail-closed filesystem, environment, write, and network preflight."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys


def readable(path: Path) -> bool:
    try:
        path.read_bytes()
    except OSError:
        return False
    return True


def main() -> int:
    label = sys.argv[1] if len(sys.argv) == 2 else "unspecified"
    cwd = Path.cwd()
    output = cwd / "output"
    output.mkdir(parents=True, exist_ok=True)

    allowed_read = readable(cwd / "input/base-brief.md")
    denied_repository_read = not readable(Path(os.environ["BENCHMARK_DENIED_READ"]))
    denied_auth_read = not readable(cwd / "home/.codex/auth.json")

    write_probe = output / f".write-probe-{label}"
    output_write = False
    try:
        write_probe.write_text("bounded-write-probe\n", encoding="utf-8")
        output_write = write_probe.read_text(encoding="utf-8") == "bounded-write-probe\n"
    except OSError:
        output_write = False
    finally:
        try:
            write_probe.unlink()
        except OSError:
            pass

    network = subprocess.run(
        [
            "/usr/bin/curl",
            "--fail",
            "--silent",
            "--show-error",
            "--max-time",
            "2",
            "https://example.com/",
        ],
        text=True,
        capture_output=True,
        check=False,
    )
    network_denied = network.returncode != 0

    sensitive_fragments = ("KEY", "TOKEN", "SECRET", "PASSWORD", "AUTH", "CREDENTIAL")
    permitted_sensitive_names = {"CODEX_SANDBOX_NETWORK_DISABLED"}
    environment_keys = sorted(os.environ)
    unexpected_sensitive = [
        key
        for key in environment_keys
        if key not in permitted_sensitive_names
        and any(fragment in key.upper() for fragment in sensitive_fragments)
    ]

    checks = {
        "allowedInputRead": allowed_read,
        "deniedRepositoryRead": denied_repository_read,
        "deniedAuthRead": denied_auth_read,
        "allowedOutputWrite": output_write,
        "networkDenied": network_denied,
        "sensitiveEnvironmentNamesAbsent": not unexpected_sensitive,
    }
    report = {
        "schemaVersion": 1,
        "label": label,
        "cwd": str(cwd),
        "checks": checks,
        "passed": all(checks.values()),
        "environmentKeys": environment_keys,
        "unexpectedSensitiveEnvironmentKeys": unexpected_sensitive,
        "networkProbeExitStatus": network.returncode,
        "networkProbeStderr": network.stderr.strip(),
    }
    (output / f"isolation-preflight-{label}.json").write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps({"label": label, "passed": report["passed"]}, sort_keys=True))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
