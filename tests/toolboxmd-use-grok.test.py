#!/usr/bin/env python3
"""Contract tests for the toolboxmd-use-grok product and fake CLI."""

from __future__ import annotations

import json
import os
from pathlib import Path
import runpy
import signal
import stat
import subprocess
import sys
import tempfile
import time
import unittest
import uuid


ROOT = Path(__file__).resolve().parents[1]
ADAPTER = ROOT / "skills/toolboxmd-use-grok/scripts/consult-grok"

REQUIRED_FAILURES = {
    "missing-cli",
    "isolation-failure",
    "nonzero-exit",
    "timeout",
    "invalid-json",
    "incomplete-stop-reason",
    "max-turns",
}

SHOULD_TRIGGER = (
    "Zapytaj Groka, czy ten plan nie jest przekombinowany.",
    "Przekaz Grok Build ten brief i popros o druga opinie.",
    "Ask Grok to review this implementation plan before we execute it.",
    "Send this proposal to Grok Build and reconcile its feedback.",
)

REVIEW = {
    "verdict": "PROCEED WITH CHANGES",
    "overengineering": ["Remove the speculative queue."],
    "missing": ["Name the rollback signal."],
    "risks": ["The first canary may be noisy."],
    "minimum_plan_delta": ["Add one bounded canary."],
    "user_decisions": [],
}

FAKE_SOURCE = r'''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import subprocess
import sys
import time

scenario = Path(sys.argv[0]).name.removeprefix("fake-grok-")
log_path = Path(sys.argv[0]).with_suffix(".log")
child_path = Path(sys.argv[0]).with_suffix(".childpid")

if "--version" in sys.argv:
    print("grok 1.0.3 (fake) [stable]")
    raise SystemExit(0)

if len(sys.argv) > 1 and sys.argv[1] == "inspect":
    cells = [
        {"vendor": vendor, "surface": surface, "enabled": False, "source": "env"}
        for vendor in ("cursor", "claude")
        for surface in ("skills", "rules", "agents", "mcps", "hooks", "sessions")
    ]
    value = {
        "grokVersion": "1.0.3",
        "cwd": os.getcwd(),
        "projectRoot": None,
        "projectInstructions": [],
        "skills": [],
        "agents": [
            {"name": "general-purpose", "source": {"type": "builtin"}},
            {"name": "explore", "source": {"type": "builtin"}},
            {"name": "plan", "source": {"type": "builtin"}},
        ],
        "mcpServers": [],
        "plugins": [],
        "hooks": [],
        "marketplaces": [],
        "externalCompat": {"remoteSettingsLoaded": False, "cells": cells},
        "configSources": {"layers": []},
        "configWarnings": None,
        "permissions": {"managedSettingsActive": False},
        "unrelatedProfileDetail": "UNRELATED-INSPECT-CONTENT-MUST-NOT-BE-RETAINED",
    }
    if scenario == "bad-mcp":
        value["mcpServers"] = [{"name": "ambient", "disabled": False}]
    if scenario == "inspect-fields-missing":
        value.pop("mcpServers")
        value.pop("permissions")
    if scenario == "config-warning":
        value["configWarnings"] = [{"kind": "unknown-field", "path": "privacy"}]
    print(json.dumps(value))
    raise SystemExit(0)

args = sys.argv[1:]
prompt_path = Path(args[args.index("--prompt-file") + 1])
entry = {
    "argv": args,
    "cwd": os.getcwd(),
    "cwdFiles": sorted(p.name for p in Path.cwd().iterdir()),
    "prompt": prompt_path.read_text(encoding="utf-8"),
    "agent": Path(args[args.index("--agent") + 1]).read_text(encoding="utf-8"),
    "envKeys": sorted(os.environ),
    "home": os.environ.get("HOME"),
    "grokHome": os.environ.get("GROK_HOME"),
    "xaiKeyPresent": "XAI_API_KEY" in os.environ,
}
log_path.write_text(json.dumps(entry, indent=2, sort_keys=True), encoding="utf-8")

review = {
    "verdict": "PROCEED WITH CHANGES",
    "overengineering": ["Remove the speculative queue."],
    "missing": ["Name the rollback signal."],
    "risks": ["The first canary may be noisy."],
    "minimum_plan_delta": ["Add one bounded canary."],
    "user_decisions": [],
}
if scenario == "runtime-secret":
    review["risks"] = [os.environ.get("XAI_API_KEY", "missing-test-secret")]

if scenario == "direct":
    print(json.dumps(review))
elif scenario == "envelope":
    print(json.dumps({"structured_output": review, "stopReason": "end_turn"}))
elif scenario in (
    "streaming", "runtime-skills", "runtime-tools-changed", "runtime-tool-call",
    "runtime-server-tool", "runtime-fields-missing", "runtime-web", "runtime-secret",
    "config-warning", "result-error"
):
    skills = ["ambient-trap"] if scenario == "runtime-skills" else []
    tools = ["todo_write", "search_tool", "use_tool"]
    if scenario == "runtime-tools-changed":
        tools.append("unexpected_tool")
    init = {
        "type": "system", "subtype": "init", "session_id": "fake-session",
        "tools": tools, "skills": skills, "mcp_servers": []
    }
    if scenario == "runtime-fields-missing":
        init.pop("skills")
        init.pop("mcp_servers")
    print(json.dumps(init))
    if scenario == "runtime-tool-call":
        print(json.dumps({
            "type": "assistant", "message": {
                "content": [{"type": "tool_use", "name": "todo_write", "input": {}}]
            }
        }))
    if scenario == "runtime-server-tool":
        print(json.dumps({
            "type": "assistant", "message": {
                "content": [{"type": "server_tool_use", "name": "web_search", "input": {}}]
            }
        }))
    print(json.dumps({
        "type": "result", "subtype": "success", "is_error": scenario == "result-error",
        "session_id": "fake-session", "stop_reason": "end_turn",
        "usage": {
            "input_tokens": 10, "output_tokens": 5,
            "server_tool_use": {"web_search_requests": 1 if scenario == "runtime-web" else 0}
        },
        "structured_output": review
    }))
elif scenario == "incomplete":
    print(json.dumps({"type": "system", "subtype": "init", "skills": [], "mcp_servers": []}))
    print(json.dumps({
        "type": "result", "subtype": "success", "is_error": False,
        "session_id": "fake-session", "stop_reason": "cancelled",
        "structured_output": review
    }))
elif scenario == "max-turns":
    print(json.dumps({"type": "result", "subtype": "error_max_turns", "is_error": True}))
    raise SystemExit(1)
elif scenario == "invalid":
    print("{not-json")
elif scenario == "nonzero":
    print(json.dumps({"type": "error", "message": "synthetic failure"}))
    print("synthetic stderr", file=sys.stderr)
    raise SystemExit(42)
elif scenario == "timeout":
    child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"])
    child_path.write_text(str(child.pid), encoding="utf-8")
    time.sleep(60)
else:
    raise SystemExit(f"unknown fake scenario: {scenario}")
'''


class UseGrokTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="toolboxmd-use-grok-test-")
        self.root = Path(self.temp.name)
        self.grok_home = self.root / "grok-home"
        self.grok_home.mkdir()
        self.output = self.root / "output"
        self.prompt = self.root / "brief.md"
        self.prompt.write_text("Review this synthetic plan.\n", encoding="utf-8")
        self.stable_temp = tempfile.TemporaryDirectory(
            prefix=".toolboxmd-use-grok-test-",
            dir=Path.home(),
        )
        self.stable_home = Path(self.stable_temp.name)

    def tearDown(self) -> None:
        self.stable_temp.cleanup()
        self.temp.cleanup()

    def fake(self, scenario: str) -> Path:
        path = self.root / f"fake-grok-{scenario}"
        path.with_suffix(".log").unlink(missing_ok=True)
        path.with_suffix(".childpid").unlink(missing_ok=True)
        path.write_text(FAKE_SOURCE, encoding="utf-8")
        path.chmod(0o755)
        return path

    def run_adapter(
        self,
        scenario: str,
        *,
        mode: str = "explicit",
        timeout: float | str = 3,
        max_turns: int = 3,
        prompt: Path | None = None,
        grok_home: Path | None = None,
        extra_env: dict[str, str] | None = None,
    ) -> tuple[subprocess.CompletedProcess, dict, Path]:
        fake = self.fake(scenario)
        selected_home = grok_home or self.grok_home
        env = os.environ.copy()
        env.pop("XAI_API_KEY", None)
        env.update(
            {
                "PYTHONDONTWRITEBYTECODE": "1",
                "AWS_SECRET_ACCESS_KEY": "must-not-be-inherited",
                "UNRELATED_SECRET": "must-not-be-inherited",
            }
        )
        if extra_env:
            env.update(extra_env)
        command = [
            sys.executable,
            str(ADAPTER),
            "--mode",
            mode,
            "--prompt-file",
            str(prompt or self.prompt),
            "--output-dir",
            str(self.output),
            "--grok-home",
            str(selected_home),
            "--grok-bin",
            str(fake),
            f"--timeout={timeout}",
            "--max-turns",
            str(max_turns),
        ]
        result = subprocess.run(command, cwd=self.root, env=env, text=True, capture_output=True, check=False)
        payload = json.loads(result.stdout)
        return result, payload, fake

    def test_activation_contract(self) -> None:
        active_text = (ROOT / "skills/toolboxmd-use-grok/SKILL.md").read_text(encoding="utf-8")
        self.assertTrue(active_text.startswith('---\nname: "toolboxmd-use-grok"\n'))
        description = active_text.split("---", 2)[1]
        self.assertIn("Polish and English", description)
        self.assertIn("Do not auto-review", description)
        self.assertIn("Public default: run only when the user explicitly asks", active_text)
        self.assertIn("Automatic review is currently disabled", active_text)
        self.assertIn("Implementation or repository mutation by Grok is outside this version", active_text)
        for prompt in SHOULD_TRIGGER:
            self.assertRegex(prompt, r"(?i)grok")

    def test_direct_and_enveloped_structured_output(self) -> None:
        for scenario in ("direct", "envelope"):
            with self.subTest(scenario=scenario):
                self.output = self.root / f"output-{scenario}"
                result, payload, _ = self.run_adapter(scenario)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(payload["status"], "ok")
                review = json.loads((Path(payload["runDir"]) / "review.json").read_text(encoding="utf-8"))
                self.assertEqual(review, REVIEW)

    def test_frozen_argv_environment_prompt_and_no_protected_leak(self) -> None:
        protected = self.root / "protected.txt"
        protected.write_text("PROTECTED-CONTENT-MUST-NOT-LEAK", encoding="utf-8")
        injection_marker = self.root / "shell-injection-fired"
        self.prompt.write_text(f"Review literal $(touch {injection_marker}).\n", encoding="utf-8")
        result, payload, fake = self.run_adapter("streaming")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(injection_marker.exists())
        log = json.loads(fake.with_suffix(".log").read_text(encoding="utf-8"))
        argv = log["argv"]
        dynamic_agent = argv[argv.index("--agent") + 1]
        dynamic_prompt = argv[argv.index("--prompt-file") + 1]
        dynamic_cwd = argv[argv.index("--cwd") + 1]
        dynamic_session = argv[argv.index("--session-id") + 1]
        dynamic_leader = argv[argv.index("--leader-socket") + 1]
        dynamic_schema = argv[argv.index("--json-schema") + 1]
        self.assertEqual(
            argv,
            [
                "--agent", dynamic_agent,
                "--prompt-file", dynamic_prompt,
                "--verbatim",
                "--cwd", dynamic_cwd,
                "--session-id", dynamic_session,
                "--leader-socket", dynamic_leader,
                "--sandbox", "read-only",
                "--no-memory",
                "--no-subagents",
                "--disable-web-search",
                "--no-plan",
                "--max-turns", "3",
                "--tools", "todo_write",
                "--disallowed-tools", "Agent",
                "--permission-mode", "dontAsk",
                "--deny", "Read",
                "--deny", "MCPTool",
                "--output-format", "streaming-messages-json",
                "--json-schema", dynamic_schema,
            ],
        )
        self.assertEqual(str(uuid.UUID(dynamic_session)), dynamic_session)
        schema = json.loads(dynamic_schema)
        self.assertIs(schema["additionalProperties"], False)
        self.assertLess(argv.index("--output-format"), argv.index("--json-schema"))
        self.assertIn("--prompt-file", argv)
        self.assertNotIn("-p", argv)
        self.assertNotIn("--always-approve", argv)
        self.assertNotIn("--yolo", argv)
        self.assertEqual(argv[argv.index("--sandbox") + 1], "read-only")
        self.assertEqual(argv[argv.index("--max-turns") + 1], "3")
        self.assertIn("Read", [argv[i + 1] for i, value in enumerate(argv[:-1]) if value == "--deny"])
        self.assertIn("MCPTool", [argv[i + 1] for i, value in enumerate(argv[:-1]) if value == "--deny"])
        self.assertEqual(log["prompt"], self.prompt.read_text(encoding="utf-8"))
        self.assertEqual(log["cwdFiles"], ["brief.md", "reviewer-agent.md"])
        self.assertNotIn("PROTECTED-CONTENT-MUST-NOT-LEAK", json.dumps(log))
        self.assertNotIn("AWS_SECRET_ACCESS_KEY", log["envKeys"])
        self.assertNotIn("UNRELATED_SECRET", log["envKeys"])
        expected_env = {
            key
            for key in ("PATH", "LANG", "LC_ALL", "TERM", "TMPDIR", "SSL_CERT_FILE", "SSL_CERT_DIR")
            if os.environ.get(key)
        }
        expected_env.update({"HOME", "GROK_HOME", "GROK_DISABLE_AUTOUPDATER", "NO_COLOR"})
        expected_env.update(
            f"GROK_{vendor}_{surface}_ENABLED"
            for vendor in ("CURSOR", "CLAUDE")
            for surface in ("SKILLS", "RULES", "AGENTS", "MCPS", "HOOKS", "SESSIONS")
        )
        if sys.platform == "darwin":
            expected_env.add("__CF_USER_TEXT_ENCODING")
        self.assertEqual(set(log["envKeys"]), expected_env)
        for key in (
            "GROK_CURSOR_SKILLS_ENABLED",
            "GROK_CURSOR_MCPS_ENABLED",
            "GROK_CLAUDE_SKILLS_ENABLED",
            "GROK_CLAUDE_MCPS_ENABLED",
        ):
            self.assertIn(key, log["envKeys"])
        metadata = json.loads((Path(payload["runDir"]) / "metadata.json").read_text(encoding="utf-8"))
        self.assertTrue(metadata["invocation"]["shell"] is False)
        self.assertEqual(metadata["runtime"]["tools"], ["todo_write", "search_tool", "use_tool"])
        self.assertEqual(metadata["runtime"]["toolCallsObserved"], 0)
        self.assertEqual(metadata["runtime"]["webSearchRequests"], 0)
        retained = "\n".join(
            path.read_text(encoding="utf-8")
            for path in Path(payload["runDir"]).iterdir()
            if path.is_file()
        )
        self.assertNotIn(str(self.grok_home), retained)
        self.assertIn("<staging-dir>", retained)
        self.assertNotIn("UNRELATED-INSPECT-CONTENT-MUST-NOT-BE-RETAINED", retained)
        self.assertTrue((Path(payload["runDir"]) / "inspect-summary.json").is_file())
        self.assertFalse((Path(payload["runDir"]) / "inspect.json").exists())
        if os.name == "posix":
            self.assertEqual(stat.S_IMODE(Path(payload["runDir"]).stat().st_mode), 0o700)

        self.output = self.root / "output-secret-rejection"
        secret_prompt = self.root / "secret-brief.md"
        secret_prompt.write_text("XAI_API_KEY=synthetic-protected-value\n", encoding="utf-8")
        result, payload, fake = self.run_adapter("no-secret-input-call", prompt=secret_prompt)
        self.assertEqual(result.returncode, 2)
        self.assertEqual(payload["status"], "input")
        self.assertFalse(fake.with_suffix(".log").exists())

        self.output = self.root / "output-secret-redaction"
        result, payload, _ = self.run_adapter(
            "runtime-secret",
            extra_env={"XAI_API_KEY": "synthetic-output-secret-value"},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        retained = "\n".join(
            path.read_text(encoding="utf-8")
            for path in Path(payload["runDir"]).iterdir()
            if path.is_file()
        )
        self.assertNotIn("synthetic-output-secret-value", retained)
        self.assertIn("[REDACTED]", retained)

    def test_automatic_requires_clean_runtime_and_stable_profile(self) -> None:
        result, payload, fake = self.run_adapter(
            "streaming",
            mode="automatic",
            grok_home=self.stable_home,
            extra_env={"XAI_API_KEY": "synthetic-test-key"},
        )
        self.assertEqual(result.returncode, 4)
        self.assertEqual(payload["status"], "isolation-failure")
        self.assertIn("disabled", payload["message"])
        self.assertFalse(fake.with_suffix(".log").exists(), "automatic consultation must not start")

        self.output = self.root / "output-unstable-profile"
        result, payload, fake = self.run_adapter(
            "streaming",
            mode="automatic",
            extra_env={"XAI_API_KEY": "synthetic-test-key"},
        )
        self.assertEqual(result.returncode, 4)
        self.assertEqual(payload["status"], "isolation-failure")
        self.assertFalse(fake.with_suffix(".log").exists())

        self.output = self.root / "output-no-auth"
        result, payload, fake = self.run_adapter(
            "no-auth",
            mode="automatic",
            grok_home=self.stable_home,
        )
        self.assertEqual(result.returncode, 4)
        self.assertEqual(payload["status"], "isolation-failure")
        self.assertFalse(fake.with_suffix(".log").exists())

        adapter = runpy.run_path(str(ADAPTER))
        inspect_reasons = adapter["inspect_reasons"]
        runtime_reasons = adapter["runtime_reasons"]
        count_tool_calls = adapter["count_tool_calls"]

        cells = [
            {"vendor": vendor, "surface": surface, "enabled": False, "source": "env"}
            for vendor in ("cursor", "claude")
            for surface in ("skills", "rules", "agents", "mcps", "hooks", "sessions")
        ]
        clean_inspect = {
            "projectRoot": None,
            "projectInstructions": [],
            "skills": [],
            "mcpServers": [],
            "plugins": [],
            "hooks": [],
            "marketplaces": [],
            "externalCompat": {"remoteSettingsLoaded": False, "cells": cells},
            "configSources": {"layers": []},
            "configWarnings": None,
            "permissions": {"managedSettingsActive": False},
        }
        self.assertEqual(inspect_reasons(clean_inspect, True), [])
        for key in ("skills", "mcpServers", "permissions"):
            with self.subTest(inspect_field=key):
                changed = dict(clean_inspect)
                changed.pop(key)
                self.assertTrue(inspect_reasons(changed, True))
        changed = dict(clean_inspect)
        changed["skills"] = [{"name": "ambient"}]
        self.assertTrue(inspect_reasons(changed, True))
        changed = dict(clean_inspect)
        changed["mcpServers"] = [{"name": "ambient"}]
        self.assertTrue(inspect_reasons(changed, True))

        clean_init = {
            "type": "system",
            "subtype": "init",
            "tools": ["todo_write", "search_tool", "use_tool"],
            "skills": [],
            "mcp_servers": [],
        }
        clean_result = {"usage": {"server_tool_use": {"web_search_requests": 0}}}
        self.assertEqual(runtime_reasons(clean_init, clean_result), [])
        self.assertTrue(runtime_reasons(None, clean_result))
        for key in ("tools", "skills", "mcp_servers"):
            with self.subTest(runtime_field=key):
                changed = dict(clean_init)
                changed.pop(key)
                self.assertTrue(runtime_reasons(changed, clean_result))
        changed = dict(clean_init)
        changed["skills"] = ["ambient"]
        self.assertTrue(runtime_reasons(changed, clean_result))
        changed = dict(clean_init)
        changed["mcp_servers"] = ["ambient"]
        self.assertTrue(runtime_reasons(changed, clean_result))
        changed = dict(clean_init)
        changed["tools"] = [*clean_init["tools"], "unexpected_tool"]
        self.assertTrue(runtime_reasons(changed, clean_result))
        self.assertTrue(runtime_reasons(clean_init, {"usage": {"server_tool_use": {}}}))
        self.assertTrue(
            runtime_reasons(
                clean_init,
                {"usage": {"server_tool_use": {"web_search_requests": 1}}},
            )
        )
        self.assertEqual(count_tool_calls('{"type":"result"}\n'), 0)
        self.assertGreater(
            count_tool_calls(
                '{"type":"assistant","message":{"content":'
                '[{"type":"tool_use","name":"todo_write"}]}}\n'
            ),
            0,
        )
        self.assertGreater(count_tool_calls('{"type":"server_tool_use"}\n'), 0)

        for scenario in (
            "runtime-skills",
            "runtime-tools-changed",
            "runtime-tool-call",
            "runtime-server-tool",
            "runtime-fields-missing",
            "runtime-web",
        ):
            with self.subTest(scenario=scenario):
                self.output = self.root / f"output-{scenario}-explicit"
                result, payload, _ = self.run_adapter(scenario)
                self.assertEqual(result.returncode, 4)
                self.assertEqual(payload["status"], "isolation-failure")

    def test_inspect_allowlist_fails_closed(self) -> None:
        result, payload, fake = self.run_adapter("bad-mcp")
        self.assertEqual(result.returncode, 4)
        self.assertEqual(payload["status"], "isolation-failure")
        self.assertFalse(fake.with_suffix(".log").exists(), "main Grok call must not run after failed inspect")

        self.output = self.root / "output-inspect-fields-missing"
        result, payload, fake = self.run_adapter(
            "inspect-fields-missing",
            mode="automatic",
            grok_home=self.stable_home,
            extra_env={"XAI_API_KEY": "synthetic-test-key"},
        )
        self.assertEqual(result.returncode, 4)
        self.assertEqual(payload["status"], "isolation-failure")
        self.assertFalse(fake.with_suffix(".log").exists())

    def test_explicit_records_config_warning_but_automatic_fails_closed(self) -> None:
        result, payload, explicit_fake = self.run_adapter("config-warning")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(payload["status"], "ok")
        explicit_fake.with_suffix(".log").unlink()

        self.output = self.root / "output-config-warning-auto"
        result, payload, fake = self.run_adapter(
            "config-warning",
            mode="automatic",
            grok_home=self.stable_home,
            extra_env={"XAI_API_KEY": "synthetic-test-key"},
        )
        self.assertEqual(result.returncode, 4)
        self.assertEqual(payload["status"], "isolation-failure")
        self.assertFalse(fake.with_suffix(".log").exists())

    def test_nonzero_invalid_incomplete_missing_and_max_turns(self) -> None:
        expected = {
            "nonzero": (5, "nonzero-exit"),
            "invalid": (7, "invalid-json"),
            "incomplete": (8, "incomplete-stop-reason"),
            "result-error": (8, "incomplete-stop-reason"),
            "max-turns": (9, "max-turns"),
        }
        for scenario, (code, category) in expected.items():
            with self.subTest(scenario=scenario):
                self.output = self.root / f"output-{scenario}"
                result, payload, _ = self.run_adapter(scenario)
                self.assertEqual(result.returncode, code, result.stderr)
                self.assertEqual(payload["status"], category)
                self.assertIn(category, REQUIRED_FAILURES)

        missing = self.root / "not-installed-grok"
        command = [
            sys.executable,
            str(ADAPTER),
            "--mode",
            "explicit",
            "--prompt-file",
            str(self.prompt),
            "--output-dir",
            str(self.root / "output-missing"),
            "--grok-home",
            str(self.grok_home),
            "--grok-bin",
            str(missing),
        ]
        result = subprocess.run(command, cwd=self.root, text=True, capture_output=True, check=False)
        payload = json.loads(result.stdout)
        self.assertEqual(result.returncode, 3)
        self.assertEqual(payload["status"], "missing-cli")

    def test_numeric_boundaries_fail_before_consultation(self) -> None:
        self.output = self.root / "output-max-turns-eight"
        result, payload, fake = self.run_adapter("streaming", max_turns=8)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(payload["status"], "ok")
        log = json.loads(fake.with_suffix(".log").read_text(encoding="utf-8"))
        self.assertEqual(log["argv"][log["argv"].index("--max-turns") + 1], "8")

        for max_turns in (0, 9):
            with self.subTest(max_turns=max_turns):
                self.output = self.root / f"output-max-turns-{max_turns}"
                result, payload, fake = self.run_adapter("streaming", max_turns=max_turns)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(payload["status"], "input")
                self.assertFalse(fake.with_suffix(".log").exists())

        self.output = self.root / "output-timeout-six-hundred"
        result, payload, fake = self.run_adapter("streaming", timeout=600)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(payload["status"], "ok")
        metadata = json.loads((Path(payload["runDir"]) / "metadata.json").read_text(encoding="utf-8"))
        self.assertEqual(metadata["process"]["timeoutSeconds"], 600)
        self.assertTrue(fake.with_suffix(".log").exists())

        invalid_timeouts = (
            ("zero", 0),
            ("over-limit", 601),
            ("nan", "NaN"),
            ("positive-infinity", "+inf"),
            ("negative-infinity", "-inf"),
        )
        for label, timeout in invalid_timeouts:
            with self.subTest(timeout=label):
                self.output = self.root / f"output-timeout-{label}"
                result, payload, fake = self.run_adapter("streaming", timeout=timeout)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(payload["status"], "input")
                self.assertFalse(fake.with_suffix(".log").exists())

    def test_timeout_kills_child_process_tree_separately_from_max_turns(self) -> None:
        result, payload, fake = self.run_adapter("timeout", timeout=0.3)
        self.assertEqual(result.returncode, 6, result.stderr)
        self.assertEqual(payload["status"], "timeout")
        child_pid = int(fake.with_suffix(".childpid").read_text(encoding="utf-8"))
        alive = True
        for _ in range(30):
            try:
                os.kill(child_pid, 0)
            except ProcessLookupError:
                alive = False
                break
            time.sleep(0.1)
        self.assertFalse(alive, f"timeout child process {child_pid} survived process-tree termination")


if __name__ == "__main__":
    unittest.main(verbosity=2)
