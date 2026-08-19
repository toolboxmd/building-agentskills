#!/usr/bin/env python3
"""Combine frozen deterministic and blind semantic evidence without retuning."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


ARMS = ("A", "B", "C", "D")
RECOMMENDATION_MINIMUM = 85.0
RECOMMENDATION_LEAD = 8.0
HELD_OUT_MINIMUM = 85.0


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def event_cost(path: Path) -> dict:
    command_count = 0
    commands = []
    tool_item_count = 0
    if path.exists():
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            if event.get("type") not in {"item.started", "item.completed"}:
                continue
            item = event.get("item")
            if not isinstance(item, dict):
                continue
            item_type = item.get("type")
            if item_type not in {"agent_message", "reasoning"}:
                tool_item_count += 1
            if event.get("type") == "item.completed" and item_type == "command_execution":
                command_count += 1
                commands.append(item.get("command"))
    return {"commandCount": command_count, "toolItemCount": tool_item_count, "commands": commands}


def candidate_cost(authoring_dir: Path) -> dict:
    manifest = load(authoring_dir / "output-manifest.json")
    candidate_files = [
        item
        for item in manifest["files"]
        if item["path"].startswith("skills/toolboxmd-use-grok/")
    ]
    skill_path = authoring_dir / "output-snapshot/skills/toolboxmd-use-grok/SKILL.md"
    description_characters = None
    skill_lines = None
    if skill_path.exists():
        text = skill_path.read_text(encoding="utf-8", errors="replace")
        skill_lines = len(text.splitlines())
        frontmatter = text.split("---", 2)
        if len(frontmatter) == 3:
            for line in frontmatter[1].splitlines():
                if line.startswith("description:"):
                    description_characters = len(line.split(":", 1)[1].strip().strip("\"'"))
                    break
    return {
        "packageBytes": sum(item["bytes"] for item in candidate_files),
        "fileCount": len(candidate_files),
        "skillMdLines": skill_lines,
        "descriptionCharactersApproximate": description_characters,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--results-root", required=True, type=Path)
    parser.add_argument("--preregistration", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    preregistration = load(args.preregistration)
    arms = {}
    all_isolation_eligible = True
    for arm in ARMS:
        arm_root = args.results_root / "arms" / arm
        authoring = load(arm_root / "authoring/run-metadata.json")
        deterministic = load(arm_root / "deterministic-grade.json")
        judge_metadata = load(arm_root / "judge/run-metadata.json")
        semantic = load(arm_root / "judge/semantic-score.json")
        authoring_eligible = authoring.get("isolationEligible") is True
        judge_eligible = judge_metadata.get("isolationEligible") is True
        isolation_eligible = authoring_eligible and judge_eligible
        all_isolation_eligible = all_isolation_eligible and isolation_eligible
        deterministic_points = float(deterministic["deterministicPointsAwarded"])
        semantic_points = float(semantic["semanticPointsAwarded"])
        total = round(deterministic_points + semantic_points, 3)
        arm_entry = {
            "treatment": preregistration["treatments"][arm],
            "isolationEligible": isolation_eligible,
            "authoringIsolationEligible": authoring_eligible,
            "judgeIsolationEligible": judge_eligible,
            "criticalFailures": deterministic["criticalFailures"],
            "recommendableArtifact": deterministic["recommendableArtifact"],
            "score": {
                "deterministic": deterministic_points,
                "semantic": semantic_points,
                "total": total,
                "available": 100,
            },
            "authoringCost": {
                "durationSeconds": authoring["authoring"]["durationSeconds"],
                "usage": authoring["authoring"]["usage"],
                **event_cost(arm_root / "authoring/evidence/events.jsonl"),
            },
            "artifactCost": candidate_cost(arm_root / "authoring"),
        }
        arms[arm] = arm_entry

    ranked = sorted(
        (
            (arm, value)
            for arm, value in arms.items()
            if value["isolationEligible"] and not value["criticalFailures"]
        ),
        key=lambda item: (
            -item[1]["score"]["total"],
            -item[1]["score"]["deterministic"],
            item[1]["artifactCost"]["packageBytes"],
            item[0],
        ),
    )
    recommendation = None
    verdict = "INCONCLUSIVE"
    repeat_required = False
    if all_isolation_eligible and ranked:
        first_arm, first = ranked[0]
        second_score = ranked[1][1]["score"]["total"] if len(ranked) > 1 else 0.0
        lead = round(first["score"]["total"] - second_score, 3)
        exact_top_tie = len(ranked) > 1 and lead == 0
        repeat_required = exact_top_tie
        if (
            not exact_top_tie
            and first["score"]["total"] >= RECOMMENDATION_MINIMUM
            and lead >= RECOMMENDATION_LEAD
        ):
            verdict = "KNOWN_TASK_WINNER"
            recommendation = {
                "arm": first_arm,
                "score": first["score"]["total"],
                "lead": lead,
                "claimBoundary": "winner only on the known Grok brief under this frozen harness",
            }
    elif not all_isolation_eligible:
        verdict = "INELIGIBLE_ISOLATION"

    held_out_candidates = [
        (arm, value)
        for arm, value in ranked
        if value["score"]["total"] >= HELD_OUT_MINIMUM
    ][:2]
    held_out_admission = [arm for arm, _ in held_out_candidates]
    held_out_ready = all_isolation_eligible and len(held_out_admission) == 2

    summary = {
        "schemaVersion": 1,
        "claimBoundary": preregistration["claimBoundary"],
        "allArmsIsolationEligible": all_isolation_eligible,
        "arms": arms,
        "decision": {
            "verdict": verdict,
            "recommendation": recommendation,
            "pairedRepeatRequired": repeat_required,
            "pairedRepeatRule": preregistration["decisionRules"]["pairedRepeat"],
        },
        "heldOut": {
            "readyToFreeze": held_out_ready,
            "admittedArms": held_out_admission,
            "rule": preregistration["decisionRules"]["heldOutAdmission"],
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "output": str(args.output),
                "verdict": verdict,
                "allArmsIsolationEligible": all_isolation_eligible,
                "heldOutAdmission": held_out_admission,
            },
            sort_keys=True,
        )
    )
    return 0 if all_isolation_eligible else 1


if __name__ == "__main__":
    raise SystemExit(main())
