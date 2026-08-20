#!/usr/bin/env python3
"""Minimal visible-contract acceptance cases for the bounded repair."""

from __future__ import annotations

import json
import math
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[2]
ADAPTER = ROOT / "output/skills/toolboxmd-use-grok/scripts/consult-grok"
FAKE = ROOT / "harness/fake_grok.py"
REVIEW_KEYS = {
    "verdict", "overengineering", "missing", "risks",
    "minimum_plan_delta", "user_decisions",
}


def invoke(scenario: str, prompt: str = "Review this bounded plan.", *, timeout: str = "5", max_turns: str = "1"):
    with tempfile.TemporaryDirectory() as raw:
        root = Path(raw)
        fake = root / "grok"
        shutil.copyfile(FAKE, fake)
        fake.chmod(0o755)
        (root / "scenario.txt").write_text(scenario, encoding="utf-8")
        prompt_file = root / "prompt.txt"
        prompt_file.write_text(prompt, encoding="utf-8")
        home = root / "home"
        home.mkdir()
        output = root / "evidence"
        result = subprocess.run(
            [str(ADAPTER), "--mode", "explicit", "--prompt-file", str(prompt_file),
             "--output-dir", str(output), "--grok-home", str(home), "--grok-bin", str(fake),
             "--timeout", timeout, "--max-turns", max_turns],
            text=True, capture_output=True, check=False,
        )
        try:
            status = json.loads(result.stdout)
        except json.JSONDecodeError:
            status = {"status": "no-json-status", "stderr": result.stderr.strip()}
        invocation_path = root / "invocation.json"
        invocation = json.loads(invocation_path.read_text(encoding="utf-8")) if invocation_path.exists() else None
        return result.returncode, status, invocation


def check(name: str, passed: bool, detail: str) -> bool:
    print(json.dumps({"case": name, "passed": passed, "detail": detail}, sort_keys=True))
    return passed


def missing_cli_case():
    with tempfile.TemporaryDirectory() as raw:
        root = Path(raw)
        prompt = root / "prompt.txt"
        prompt.write_text("Review this bounded plan.", encoding="utf-8")
        home = root / "home"
        home.mkdir()
        result = subprocess.run(
            [str(ADAPTER), "--mode", "explicit", "--prompt-file", str(prompt),
             "--output-dir", str(root / "evidence"), "--grok-home", str(home),
             "--grok-bin", str(root / "missing-grok"), "--timeout", "5", "--max-turns", "1"],
            text=True, capture_output=True, check=False,
        )
        return result.returncode, json.loads(result.stdout)


def main() -> int:
    outcomes = []
    for scenario in ("direct", "envelope", "streaming"):
        code, status, _ = invoke(scenario)
        outcomes.append(check(
            f"success-{scenario}",
            code == 0 and status.get("status") == "ok" and set(status.get("review", {})) == REVIEW_KEYS,
            f"exit={code} status={status.get('status')}",
        ))

    code, status, invocation = invoke("streaming", "literal ; $(touch SHOULD_NOT_EXIST) prompt")
    argv = invocation.get("argv", []) if invocation else []
    env = set(invocation.get("environmentKeys", [])) if invocation else set()
    required = {"--prompt-file", "--json-schema", "--permission-mode", "--sandbox", "--no-memory", "--no-web", "--no-subagents", "--deny-mcp", "--max-turns"}
    outcomes.append(check(
        "safe-argv-prompt-and-environment",
        code == 0 and required <= set(argv) and "literal ; $(touch SHOULD_NOT_EXIST) prompt" not in argv
        and invocation.get("prompt") == "literal ; $(touch SHOULD_NOT_EXIST) prompt"
        and env <= {"PATH", "HOME", "GROK_HOME", "LANG", "LC_ALL", "NO_COLOR", "GROK_DISABLE_CURSOR",
                      "GROK_DISABLE_CLAUDE", "GROK_DISABLE_SKILLS", "GROK_DISABLE_AGENTS", "GROK_DISABLE_HOOKS",
                      "GROK_DISABLE_PLUGINS", "GROK_DISABLE_MCP", "GROK_DISABLE_MEMORY", "GROK_DISABLE_WEB", "XAI_API_KEY",
                      "__CF_USER_TEXT_ENCODING"},
        f"exit={code} required_flags={required <= set(argv)} prompt_preserved={bool(invocation and invocation.get('prompt').startswith('literal'))} env={sorted(env)}",
    ))

    code, status, _ = invoke("result-error")
    outcomes.append(check(
        "concrete-failure-result-error",
        code != 0 and status.get("status") == "incomplete-stop-reason",
        f"exit={code} status={status.get('status')}",
    ))

    code, status, invocation = invoke("streaming", "Authorization: Bearer sk-secret-value")
    outcomes.append(check(
        "credential-shaped-input-rejected-before-call",
        code != 0 and status.get("status") == "isolation-failure" and invocation is None,
        f"exit={code} status={status.get('status')} fake_invoked={invocation is not None}",
    ))

    numeric_passed = True
    details = []
    for timeout in ("0", "-1", "nan", "inf"):
        code, status, invocation = invoke("streaming", timeout=timeout)
        passed = code != 0 and status.get("status") == "isolation-failure" and invocation is None
        numeric_passed &= passed
        details.append(f"timeout={timeout}:{passed}")
    code, status, invocation = invoke("streaming", max_turns="0")
    passed = code != 0 and status.get("status") == "isolation-failure" and invocation is None
    numeric_passed &= passed
    details.append(f"max-turns=0:{passed}")
    outcomes.append(check("numeric-bounds-fail-before-call", numeric_passed, " ".join(details)))

    for scenario, expected, timeout in (
        ("bad-inspect", "isolation-failure", "5"),
        ("runtime-tool-call", "isolation-failure", "5"),
        ("incomplete", "incomplete-stop-reason", "5"),
        ("max-turns", "max-turns", "5"),
        ("invalid-json", "invalid-json", "5"),
        ("nonzero", "nonzero-exit", "5"),
        ("timeout", "timeout", "0.2"),
    ):
        code, status, _ = invoke(scenario, timeout=timeout)
        outcomes.append(check(
            f"failure-{scenario}",
            code != 0 and status.get("status") == expected,
            f"exit={code} status={status.get('status')} expected={expected}",
        ))
    code, status = missing_cli_case()
    outcomes.append(check(
        "failure-missing-cli",
        code != 0 and status.get("status") == "missing-cli",
        f"exit={code} status={status.get('status')} expected=missing-cli",
    ))
    return 0 if all(outcomes) else 1


if __name__ == "__main__":
    raise SystemExit(main())
