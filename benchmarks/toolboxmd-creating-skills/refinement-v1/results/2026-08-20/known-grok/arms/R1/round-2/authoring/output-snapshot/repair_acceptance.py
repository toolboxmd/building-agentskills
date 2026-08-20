#!/usr/bin/env python3
"""Visible-contract acceptance cases for the bounded repair round."""

from __future__ import annotations

import argparse
from importlib.machinery import SourceFileLoader
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
ADAPTER = ROOT / "output/skills/toolboxmd-use-grok/scripts/consult-grok"
FAKE_SOURCE = ROOT / "harness/fake_grok.py"
REVIEW_KEYS = {
    "verdict", "overengineering", "missing", "risks",
    "minimum_plan_delta", "user_decisions",
}


def invoke(area: Path, scenario: str, prompt_text: str = "Review this bounded plan.", *,
           timeout: str = "5", max_turns: str = "1", env: dict[str, str] | None = None):
    fake = area / "fake_grok.py"
    shutil.copyfile(FAKE_SOURCE, fake)
    fake.chmod(0o755)
    (area / "scenario.txt").write_text(scenario, encoding="utf-8")
    prompt = area / "prompt.txt"
    prompt.write_text(prompt_text, encoding="utf-8")
    home = area / "grok-home"
    home.mkdir(exist_ok=True)
    output = area / "evidence"
    command = [
        str(ADAPTER), "--mode", "explicit", "--prompt-file", str(prompt),
        "--output-dir", str(output), "--grok-home", str(home),
        "--grok-bin", str(fake), "--timeout", timeout, "--max-turns", max_turns,
    ]
    completed = subprocess.run(command, text=True, capture_output=True, env=env)
    status = json.loads(completed.stdout)
    return completed, status, fake.with_name("invocation.json")


def credential_case(root: Path) -> None:
    area = root / "credential"
    area.mkdir()
    completed, status, log = invoke(
        area, "direct",
        "Review this plan. Temporary credential: github_pat_11AA22BB33CC44DD55EE66FF77GG88HH99II.",
    )
    assert completed.returncode != 0 and status["status"] == "isolation-failure"
    assert not log.exists(), "credential-shaped input reached the fake CLI"


def output_shapes_case(root: Path) -> None:
    for scenario in ("direct", "envelope", "streaming"):
        area = root / scenario
        area.mkdir()
        completed, status, _ = invoke(area, scenario)
        assert completed.returncode == 0 and status["status"] == "ok", (scenario, status)
        assert set(status["review"]) == REVIEW_KEYS
        if scenario == "direct":
            assert status["stop_reason"] is None, "direct output fabricated a stop reason"
        elif scenario == "envelope":
            assert status["stop_reason"] == "end_turn"
        else:
            assert status["stop_reason"] == "end_turn" and status["session_id"] == "fake-session"


def numeric_case(root: Path) -> None:
    cases = (("timeout", "301", "1"), ("max-turns", "5", "11"))
    for name, timeout, turns in cases:
        area = root / name
        area.mkdir()
        completed, status, log = invoke(area, "direct", timeout=timeout, max_turns=turns)
        assert completed.returncode != 0 and status["status"] == "isolation-failure"
        assert not log.exists(), f"unbounded {name} reached the fake CLI"


def safe_argv_environment_case(root: Path) -> None:
    spec = importlib.util.spec_from_loader("consult_grok", SourceFileLoader("consult_grok", str(ADAPTER)))
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    old_path = os.environ.get("PATH")
    os.environ["PATH"] = "/tmp/ambient-bin:/usr/bin:/bin"
    try:
        safe = module.safe_environment(root)
    finally:
        if old_path is None:
            os.environ.pop("PATH", None)
        else:
            os.environ["PATH"] = old_path
    assert "/tmp/ambient-bin" not in safe["PATH"], "ambient executable search path was retained"
    assert safe["PATH"] == module.SAFE_PATH

    area = root / "argv"
    area.mkdir()
    prompt_text = "Review literal shell text: $(touch NEVER) and `touch ALSO_NEVER`."
    completed, status, log = invoke(area, "direct", prompt_text)
    assert completed.returncode == 0 and status["status"] == "ok"
    recorded = json.loads(log.read_text(encoding="utf-8"))
    argv = recorded["argv"]
    assert prompt_text not in argv and recorded["prompt"] == prompt_text
    for flag in ("--output-format", "--json-schema", "--prompt-file", "--agent",
                 "--permission-mode", "--sandbox", "--no-memory", "--no-web",
                 "--no-subagents", "--deny-mcp", "--max-turns"):
        assert flag in argv
    assert argv[argv.index("--sandbox") + 1] == "read-only"
    assert argv[argv.index("--permission-mode") + 1] == "plan"


CASES = {
    "credential-shaped-input-rejected-before-call": credential_case,
    "direct-envelope-streaming-success": output_shapes_case,
    "numeric-bounds-fail-before-call": numeric_case,
    "safe-argv-prompt-and-environment": safe_argv_environment_case,
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("cases", nargs="*", choices=sorted(CASES))
    args = parser.parse_args()
    selected = args.cases or list(CASES)
    failures = 0
    with tempfile.TemporaryDirectory(dir=ROOT / "output") as temporary:
        base = Path(temporary)
        for name in selected:
            area = base / name
            area.mkdir()
            try:
                CASES[name](area)
            except Exception as error:
                failures += 1
                print(f"FAIL {name}: {error}")
            else:
                print(f"PASS {name}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
