#!/usr/bin/env python3
"""Run one equal-budget Creator arm through initial generation and two repairs."""

import argparse
from hashlib import sha256
import json
from pathlib import Path
import subprocess
import sys


def tree_hash(root: Path) -> dict:
    files = sorted((path for path in root.rglob("*") if path.is_file()), key=lambda path: path.relative_to(root).as_posix().encode())
    lines = "".join(f"{sha256(path.read_bytes()).hexdigest()}  {path.relative_to(root).as_posix()}\n" for path in files)
    return {
        "aggregateSha256": sha256(lines.encode()).hexdigest(),
        "bytes": sum(path.stat().st_size for path in files),
        "fileCount": len(files),
    }


def run(argv):
    completed = subprocess.run(argv, text=True)
    if completed.returncode != 0:
        raise SystemExit(f"command failed with exit {completed.returncode}: {argv[0]}")


def run_grader(argv, grade_path: Path) -> int:
    completed = subprocess.run(argv, text=True)
    if completed.returncode not in (0, 1):
        raise SystemExit(f"grader failed with exit {completed.returncode}: {argv[0]}")
    if not grade_path.is_file():
        raise SystemExit(
            f"grader exited {completed.returncode} without writing its report: {grade_path}"
        )
    return completed.returncode


def task_config(root: Path, task: str) -> dict:
    if task == "known-grok":
        grok_root = root.parents[1] / "toolboxmd-use-grok"
        return {
            "skillName": "toolboxmd-use-grok",
            "brief": grok_root / "base-brief.md",
            "contract": grok_root / "contract.json",
            "initialPrompt": grok_root / "two-arm-creator/authoring-prompt.md",
            "support": [grok_root / "two-arm-creator/harness/fake_grok.py"],
            "grader": grok_root / "two-arm-creator/harness/grade_candidate.py",
            "graderArgs": ["--fake-source", str(grok_root / "two-arm-creator/harness/fake_grok.py"), "--contract", str(grok_root / "contract.json")],
            "promotionEligible": False,
        }
    held_out = root / "held-out/safe-archive-inspector"
    return {
        "skillName": "safe-archive-inspector",
        "brief": held_out / "brief.md",
        "contract": held_out / "contract.json",
        "initialPrompt": held_out / "authoring-prompt.md",
        "support": [],
        "grader": root / "harness/grade_archive_candidate.py",
        "graderArgs": [],
        "promotionEligible": False,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--task", required=True, choices=("known-grok", "safe-archive-inspector"))
    parser.add_argument("--arm", required=True, choices=("R0", "R1"))
    parser.add_argument("--result-root", required=True, type=Path)
    parser.add_argument("--codex-bin", required=True, type=Path)
    parser.add_argument("--auth-file", required=True, type=Path)
    parser.add_argument("--python-bin", required=True, type=Path)
    args = parser.parse_args()

    harness = Path(__file__).resolve().parent
    root = harness.parent
    treatment_id = "r0-merged-vnext" if args.arm == "R0" else "r1-bounded-refinement"
    treatment = root / "treatments" / treatment_id / "package"
    config = task_config(root, args.task)
    result_root = args.result_root.resolve()
    arm_root = result_root / args.task / "arms" / args.arm
    if arm_root.exists():
        raise SystemExit(f"arm result already exists: {arm_root}")
    arm_root.mkdir(parents=True)

    for path in (treatment, config["brief"], config["contract"], config["initialPrompt"], config["grader"], args.codex_bin, args.auth_file, args.python_bin, *config["support"]):
        if not path.exists():
            raise SystemExit(f"missing required input: {path}")

    rounds = []
    candidate = None
    feedback = None
    for round_index in range(3):
        phase = "initial" if round_index == 0 else f"repair-{round_index}"
        round_root = arm_root / f"round-{round_index}"
        authoring_result = round_root / "authoring"
        prompt = config["initialPrompt"] if round_index == 0 else root / "repair-prompt.md"
        command = [
            sys.executable,
            "-B",
            str(harness / "run_phase.py"),
            "--arm",
            args.arm,
            "--phase",
            phase,
            "--treatment",
            str(treatment),
            "--brief",
            str(config["brief"]),
            "--contract",
            str(config["contract"]),
            "--prompt",
            str(prompt),
            "--result-dir",
            str(authoring_result),
            "--codex-bin",
            str(args.codex_bin),
            "--auth-file",
            str(args.auth_file),
            "--python-bin",
            str(args.python_bin),
        ]
        if candidate is not None and feedback is not None:
            command.extend(["--candidate", str(candidate), "--feedback", str(feedback)])
        for support in config["support"]:
            command.extend(["--support-file", str(support)])
        run(command)

        metadata = json.loads((authoring_result / "run-metadata.json").read_text(encoding="utf-8"))
        candidate = authoring_result / "output-snapshot/skills" / config["skillName"]
        if not candidate.is_dir():
            raise SystemExit(f"phase did not retain expected candidate: {candidate}")
        grade_path = round_root / "deterministic-grade.json"
        grade_command = [
            sys.executable,
            "-B",
            str(config["grader"]),
            "--candidate",
            str(candidate),
            *config["graderArgs"],
            "--output",
            str(grade_path),
        ]
        run_grader(grade_command, grade_path)
        grade = json.loads(grade_path.read_text(encoding="utf-8"))
        candidate_hash = tree_hash(candidate)
        rounds.append(
            {
                "round": round_index,
                "phase": phase,
                "candidate": candidate_hash,
                "deterministicPointsAwarded": grade["deterministicPointsAwarded"],
                "deterministicPointsAvailable": grade["deterministicPointsAvailable"],
                "criticalFailures": grade["criticalFailures"],
                "recommendableArtifact": grade["recommendableArtifact"],
                "durationSeconds": metadata["authoring"]["durationSeconds"],
                "usage": metadata["authoring"]["usage"],
                "isolationEligible": metadata["isolationEligible"],
            }
        )
        if grade["recommendableArtifact"]:
            break
        if round_index < 2:
            feedback = arm_root / f"feedback-for-round-{round_index + 1}.json"
            run(
                [
                    sys.executable,
                    "-B",
                    str(harness / "extract_feedback.py"),
                    "--grade",
                    str(grade_path),
                    "--round",
                    str(round_index + 1),
                    "--output",
                    str(feedback),
                ]
            )

    total_usage = {}
    for key in ("input_tokens", "cached_input_tokens", "output_tokens", "reasoning_output_tokens"):
        values = [row["usage"].get(key) for row in rounds]
        total_usage[key] = sum(value for value in values if isinstance(value, int)) if all(isinstance(value, int) for value in values) else None
    summary = {
        "schemaVersion": 1,
        "task": args.task,
        "arm": args.arm,
        "treatmentId": treatment_id,
        "treatment": tree_hash(treatment),
        "promotionEligibleTask": config["promotionEligible"],
        "roundLimit": 3,
        "repairLimit": 2,
        "tokenEligibilityCap": None,
        "rounds": rounds,
        "stoppedEarlyOnGreen": len(rounds) < 3 and rounds[-1]["recommendableArtifact"],
        "finalRecommendableArtifact": rounds[-1]["recommendableArtifact"],
        "finalCandidate": rounds[-1]["candidate"],
        "totalUsage": total_usage,
        "totalDurationSeconds": round(sum(row["durationSeconds"] for row in rounds), 3),
    }
    (arm_root / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"task": args.task, "arm": args.arm, "rounds": len(rounds), "finalScore": f"{rounds[-1]['deterministicPointsAwarded']}/{rounds[-1]['deterministicPointsAvailable']}", "recommendable": rounds[-1]["recommendableArtifact"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
