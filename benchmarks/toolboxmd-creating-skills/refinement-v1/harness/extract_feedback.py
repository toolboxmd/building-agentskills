#!/usr/bin/env python3
"""Create bounded equal-surface repair feedback from a deterministic grade."""

import argparse
import json
from pathlib import Path


def compact(value, depth=0):
    if depth > 4:
        return "<nested detail omitted>"
    if value is None or isinstance(value, (bool, int, float)):
        return value
    if isinstance(value, str):
        return value if len(value) <= 240 else value[:237] + "..."
    if isinstance(value, list):
        return [compact(item, depth + 1) for item in value[:8]]
    if isinstance(value, dict):
        preferred = {}
        for key, item in value.items():
            if key in {
                "actual",
                "expected",
                "passed",
                "status",
                "format",
                "exitStatus",
                "issueCodes",
                "files",
                "bytes",
                "executable",
                "syntaxError",
                "forbiddenImports",
                "forbiddenCalls",
                "argvContractPassed",
                "promptFilePreserved",
                "fakeInvoked",
                "retainedSyntheticSecrets",
                "childAliveAfterGrace",
                "allCasesFilesystemStable",
            }:
                preferred[key] = compact(item, depth + 1)
        if preferred:
            return preferred
        return {key: compact(item, depth + 1) for key, item in list(value.items())[:8]}
    return repr(value)[:240]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--grade", required=True, type=Path)
    parser.add_argument("--round", required=True, type=int)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    grade = json.loads(args.grade.read_text(encoding="utf-8"))
    failed = []
    for check_id, check in grade.get("checks", {}).items():
        if check.get("passed") is True:
            continue
        failed.append(
            {
                "id": check_id,
                "critical": bool(check.get("critical")),
                "pointsAwarded": check.get("pointsAwarded"),
                "pointsAvailable": check.get("pointsAvailable"),
                "evidence": compact(check.get("detail")),
            }
        )
    payload = {
        "schemaVersion": 1,
        "repairRound": args.round,
        "sourceGradeSha256": __import__("hashlib").sha256(args.grade.read_bytes()).hexdigest(),
        "deterministicPointsAwarded": grade.get("deterministicPointsAwarded"),
        "deterministicPointsAvailable": grade.get("deterministicPointsAvailable"),
        "criticalFailures": grade.get("criticalFailures", []),
        "failedChecks": failed,
        "boundary": "Reproduce failures from the visible brief and contract. Do not search for or infer the hidden grader.",
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"failedChecks": len(failed), "criticalFailures": len(payload["criticalFailures"])}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
