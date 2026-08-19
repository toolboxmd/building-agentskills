#!/usr/bin/env python3
"""Run one anonymous candidate through the frozen blind semantic rubric."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import uuid

from run_authoring import inline_table
from run_authoring import parse_usage
from run_authoring import run_process
from run_authoring import sanitized_process_environment
from run_authoring import sha256
from run_authoring import toml_string
from run_authoring import tree_manifest


MODEL = "gpt-5.6-sol"
REASONING_EFFORT = "medium"
WALL_TIME_LIMIT_SECONDS = 300
INPUT_TOKEN_LIMIT = 250_000
OUTPUT_TOKEN_LIMIT = 12_000


def judge_config(sandbox: Path, python_runtime_root: Path) -> list[str]:
    denied_read_probe = Path(__file__).resolve().parents[4] / "README.md"
    filesystem = inline_table(
        {
            ":minimal": "read",
            str(python_runtime_root): "read",
            str(sandbox): "read",
            str(sandbox / "home"): "deny",
            str(sandbox / "output"): "write",
        }
    )
    shell_environment = inline_table(
        {
            "PATH": f"{sandbox / 'runtime/bin'}:/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME": str(sandbox / "output/.home"),
            "TMPDIR": str(sandbox / "output/.tmp"),
            "PYTHONDONTWRITEBYTECODE": "1",
            "PYTHONPYCACHEPREFIX": str(sandbox / "output/.pycache"),
            "LANG": "C",
            "LC_ALL": "C",
            "TERM": "dumb",
            "NO_COLOR": "1",
            "BENCHMARK_DENIED_READ": str(denied_read_probe),
        }
    )
    values = [
        ("default_permissions", toml_string("benchmark-judge")),
        ("permissions.benchmark-judge.filesystem", filesystem),
        ("permissions.benchmark-judge.network.enabled", "false"),
        ("approval_policy", toml_string("never")),
        ("allow_login_shell", "false"),
        ("shell_environment_policy.inherit", toml_string("none")),
        ("shell_environment_policy.set", shell_environment),
        ("model_reasoning_effort", toml_string(REASONING_EFFORT)),
        ("project_doc_max_bytes", "0"),
        ("skills.bundled.enabled", "false"),
        ("skills.include_instructions", "false"),
        ("web_search", toml_string("disabled")),
        ("mcp_servers", "{}"),
        ("plugins", "{}"),
        ("apps._default.enabled", "false"),
    ]
    for feature in (
        "apps",
        "auth_elicitation",
        "browser_use",
        "browser_use_external",
        "browser_use_full_cdp_access",
        "chronicle",
        "computer_use",
        "goals",
        "hooks",
        "image_generation",
        "in_app_browser",
        "memories",
        "multi_agent",
        "multi_agent_v2",
        "plugins",
        "recommended_plugins",
        "remote_plugin",
        "shell_snapshot",
        "skill_mcp_dependency_install",
        "skill_search",
        "tool_suggest",
        "view_image",
        "web_search_cached",
        "web_search_request",
        "workspace_dependencies",
    ):
        values.append((f"features.{feature}", "false"))
    args = []
    for key, value in values:
        args.extend(["--config", f"{key}={value}"])
    return args


def load_judge_result(path: Path) -> dict | None:
    if not path.exists():
        return None
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return None
    return value if isinstance(value, dict) else None


def score_result(result: dict | None, answer_key: dict) -> dict:
    expected = answer_key["expected"]
    predictions = {}
    if result and isinstance(result.get("activation_predictions"), list):
        for item in result["activation_predictions"]:
            if isinstance(item, dict) and isinstance(item.get("id"), str) and isinstance(item.get("activate"), bool):
                predictions[item["id"]] = item["activate"]
    ids_valid = set(predictions) == set(expected)
    positive_ids = [key for key, value in expected.items() if value]
    negative_ids = [key for key, value in expected.items() if not value]
    true_positive_rate = (
        sum(predictions.get(key) is True for key in positive_ids) / len(positive_ids)
        if ids_valid
        else 0.0
    )
    true_negative_rate = (
        sum(predictions.get(key) is False for key in negative_ids) / len(negative_ids)
        if ids_valid
        else 0.0
    )
    activation_points = round(5 * (true_positive_rate + true_negative_rate), 3)
    procedure = result.get("procedure_adherence_score") if result else None
    privacy = result.get("privacy_reliability_score") if result else None
    procedure_points = procedure if isinstance(procedure, int) and 0 <= procedure <= 10 else 0
    privacy_points = privacy if isinstance(privacy, int) and 0 <= privacy <= 10 else 0
    return {
        "activationPredictionIdsValid": ids_valid,
        "truePositiveRate": round(true_positive_rate, 3),
        "trueNegativeRate": round(true_negative_rate, 3),
        "activationPoints": activation_points,
        "procedurePoints": procedure_points,
        "privacyReliabilityPoints": privacy_points,
        "semanticPointsAwarded": round(activation_points + procedure_points + privacy_points, 3),
        "semanticPointsAvailable": 30,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--arm", required=True, choices=("A", "B", "C", "D"))
    parser.add_argument("--candidate", required=True, type=Path)
    parser.add_argument("--result-dir", required=True, type=Path)
    parser.add_argument("--codex-bin", required=True, type=Path)
    parser.add_argument("--auth-file", required=True, type=Path)
    parser.add_argument("--python-bin", required=True, type=Path)
    parser.add_argument("--preflight-only", action="store_true")
    args = parser.parse_args()

    harness_dir = Path(__file__).resolve().parent
    benchmark_dir = harness_dir.parent
    prompt = benchmark_dir / "judge-prompt.md"
    base_brief = benchmark_dir.parent / "base-brief.md"
    fixtures = harness_dir / "judge-fixtures.json"
    answer_key_path = harness_dir / "judge-answer-key.json"
    rubric = harness_dir / "judge-rubric.md"
    schema = harness_dir / "judge.schema.json"
    candidate = args.candidate.resolve()
    result_dir = args.result_dir.resolve()
    codex_bin = args.codex_bin.expanduser().absolute()
    auth_file = args.auth_file.resolve()
    python_bin = args.python_bin.expanduser().resolve()
    python_runtime_root = next(
        (parent for parent in python_bin.parents if parent.parent.name.startswith("python@")),
        None,
    )
    if python_runtime_root is None:
        raise SystemExit(f"cannot derive frozen Homebrew Python runtime root from: {python_bin}")
    for required in (
        prompt,
        base_brief,
        fixtures,
        answer_key_path,
        rubric,
        schema,
        candidate / "SKILL.md",
        candidate / "scripts/consult-grok",
        codex_bin,
        auth_file,
        python_bin,
    ):
        if not required.exists():
            raise SystemExit(f"missing required input: {required}")
    if result_dir.exists():
        raise SystemExit(f"result directory already exists: {result_dir}")

    opaque_id = str(uuid.uuid4())
    run_parent = Path("/private/tmp") / f"creator-four-arm-judge-{opaque_id}"
    sandbox = run_parent / "sandbox"
    home = sandbox / "home"
    codex_home = home / ".codex"
    input_dir = sandbox / "input"
    isolated_harness = sandbox / "harness"
    output_dir = sandbox / "output"
    evidence_dir = run_parent / "evidence"
    runtime_bin = sandbox / "runtime/bin"
    for directory in (input_dir, isolated_harness, output_dir, evidence_dir, home / "tmp", runtime_bin):
        directory.mkdir(parents=True, exist_ok=False)
    (runtime_bin / "python3").symlink_to(python_bin)
    (runtime_bin / "python").symlink_to(python_bin)
    shutil.copy2(base_brief, input_dir / "base-brief.md")
    shutil.copy2(fixtures, input_dir / "fixtures.json")
    shutil.copy2(rubric, input_dir / "rubric.md")
    shutil.copytree(candidate, input_dir / "candidate", symlinks=True)
    shutil.copy2(harness_dir / "isolation_preflight.py", isolated_harness / "isolation_preflight.py")
    shutil.copy2(schema, isolated_harness / "judge.schema.json")
    codex_home.mkdir(parents=True, exist_ok=True)
    (codex_home / "auth.json").symlink_to(auth_file)

    environment = sanitized_process_environment(home, codex_bin)
    config = judge_config(sandbox, python_runtime_root)
    version = subprocess.run(
        [str(codex_bin), "--version"], env=environment, text=True, capture_output=True, check=True
    ).stdout.strip()

    debug_status, debug_timed_out, debug_duration = run_process(
        [str(codex_bin), "debug", "prompt-input", *config, prompt.read_text(encoding="utf-8")],
        cwd=sandbox,
        env=environment,
        stdout_path=evidence_dir / "model-visible-prompt.json",
        stderr_path=evidence_dir / "model-visible-prompt.stderr.txt",
        timeout=60,
    )
    preflight_status, preflight_timed_out, preflight_duration = run_process(
        [
            str(codex_bin),
            "sandbox",
            "--log-denials",
            "--permission-profile",
            "benchmark-judge",
            "--cd",
            str(sandbox),
            *config,
            str(runtime_bin / "python3"),
            "harness/isolation_preflight.py",
            "control",
        ],
        cwd=sandbox,
        env=environment,
        stdout_path=evidence_dir / "control-preflight.stdout.txt",
        stderr_path=evidence_dir / "control-preflight.stderr.txt",
        timeout=30,
    )
    control_report = output_dir / "isolation-preflight-control.json"
    control_passed = (
        control_report.exists()
        and json.loads(control_report.read_text(encoding="utf-8")).get("passed") is True
    )

    judge_status = None
    judge_timed_out = False
    judge_duration = 0.0
    if (
        not args.preflight_only
        and debug_status == 0
        and not debug_timed_out
        and preflight_status == 0
        and control_passed
    ):
        judge_status, judge_timed_out, judge_duration = run_process(
            [
                str(codex_bin),
                "exec",
                "--ephemeral",
                "--ignore-user-config",
                "--ignore-rules",
                "--strict-config",
                "--skip-git-repo-check",
                "--model",
                MODEL,
                *config,
                "--output-schema",
                str(isolated_harness / "judge.schema.json"),
                "--json",
                "--color",
                "never",
                "--output-last-message",
                str(evidence_dir / "judge.json"),
                "--cd",
                str(sandbox),
                "-",
            ],
            cwd=sandbox,
            env=environment,
            stdout_path=evidence_dir / "events.jsonl",
            stderr_path=evidence_dir / "stderr.txt",
            timeout=WALL_TIME_LIMIT_SECONDS,
            stdin_path=prompt,
        )
    usage = parse_usage(evidence_dir / "events.jsonl")
    token_cap_passed = (
        isinstance(usage["input_tokens"], int)
        and isinstance(usage["output_tokens"], int)
        and usage["input_tokens"] <= INPUT_TOKEN_LIMIT
        and usage["output_tokens"] <= OUTPUT_TOKEN_LIMIT
    )
    model_report = output_dir / "isolation-preflight-model.json"
    model_preflight_passed = (
        model_report.exists()
        and json.loads(model_report.read_text(encoding="utf-8")).get("passed") is True
    )
    judge_result = load_judge_result(evidence_dir / "judge.json")
    score = score_result(judge_result, json.loads(answer_key_path.read_text(encoding="utf-8")))
    isolation_eligible = (
        not args.preflight_only
        and debug_status == 0
        and not debug_timed_out
        and preflight_status == 0
        and control_passed
        and judge_status == 0
        and not judge_timed_out
        and model_preflight_passed
        and token_cap_passed
        and score["activationPredictionIdsValid"]
    )
    preflight_eligible = (
        debug_status == 0
        and not debug_timed_out
        and preflight_status == 0
        and control_passed
    )

    result_dir.mkdir(parents=True)
    shutil.copytree(evidence_dir, result_dir / "evidence")
    (result_dir / "semantic-score.json").write_text(
        json.dumps(score, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    metadata = {
        "schemaVersion": 1,
        "arm": args.arm,
        "opaqueRunId": opaque_id,
        "actualCommandCwd": str(sandbox),
        "codexVersion": version,
        "model": MODEL,
        "modelReasoningEffort": REASONING_EFFORT,
        "preflightOnly": args.preflight_only,
        "candidate": tree_manifest(candidate),
        "pythonRuntime": {
            "executable": str(python_bin),
            "root": str(python_runtime_root),
            "version": subprocess.run(
                [str(python_bin), "--version"], text=True, capture_output=True, check=True
            ).stdout.strip(),
        },
        "inputs": {
            "promptSha256": sha256(prompt),
            "baseBriefSha256": sha256(base_brief),
            "fixturesSha256": sha256(fixtures),
            "rubricSha256": sha256(rubric),
            "schemaSha256": sha256(schema),
            "answerKeySha256": sha256(answer_key_path),
        },
        "limits": {
            "wallTimeSeconds": WALL_TIME_LIMIT_SECONDS,
            "inputTokens": INPUT_TOKEN_LIMIT,
            "outputTokens": OUTPUT_TOKEN_LIMIT,
        },
        "debugPromptInput": {
            "exitStatus": debug_status,
            "timedOut": debug_timed_out,
            "durationSeconds": round(debug_duration, 3),
        },
        "controlPreflight": {
            "exitStatus": preflight_status,
            "timedOut": preflight_timed_out,
            "durationSeconds": round(preflight_duration, 3),
            "passed": control_passed,
        },
        "judge": {
            "exitStatus": judge_status,
            "timedOut": judge_timed_out,
            "durationSeconds": round(judge_duration, 3),
            "usage": usage,
            "tokenCapPassed": token_cap_passed,
            "modelPreflightPassed": model_preflight_passed,
        },
        "isolationEligible": isolation_eligible,
        "preflightEligible": preflight_eligible,
    }
    (result_dir / "run-metadata.json").write_text(
        json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(
        json.dumps(
            {
                "arm": args.arm,
                "resultDir": str(result_dir),
                "isolationEligible": isolation_eligible,
                "semanticPoints": score["semanticPointsAwarded"],
                "usage": usage,
            },
            sort_keys=True,
        )
    )
    if args.preflight_only:
        return 0 if preflight_eligible else 1
    return 0 if isolation_eligible else 1


if __name__ == "__main__":
    raise SystemExit(main())
