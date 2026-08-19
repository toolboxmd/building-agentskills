#!/usr/bin/env python3
"""Scenario-driven fake Grok CLI used by the frozen candidate grader."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import time


SCRIPT = Path(sys.argv[0])
SCENARIO_FILE = SCRIPT.with_name("scenario.txt")
SCENARIO = SCENARIO_FILE.read_text(encoding="utf-8").strip() if SCENARIO_FILE.exists() else "streaming"
LOG = SCRIPT.with_name("invocation.json")
CHILD_PID = SCRIPT.with_name("child.pid")

REVIEW = {
    "verdict": "PROCEED WITH CHANGES",
    "overengineering": ["Remove the speculative queue."],
    "missing": ["Name the rollback signal."],
    "risks": ["The first canary may be noisy."],
    "minimum_plan_delta": ["Add one bounded canary."],
    "user_decisions": [],
}


def argument_value(name: str) -> str | None:
    try:
        return sys.argv[sys.argv.index(name) + 1]
    except (ValueError, IndexError):
        return None


def write_invocation() -> None:
    prompt_path = argument_value("--prompt-file")
    agent_path = argument_value("--agent")
    payload = {
        "argv": sys.argv[1:],
        "cwd": os.getcwd(),
        "cwdFiles": sorted(path.name for path in Path.cwd().iterdir()),
        "environmentKeys": sorted(os.environ),
        "prompt": Path(prompt_path).read_text(encoding="utf-8") if prompt_path else None,
        "agent": Path(agent_path).read_text(encoding="utf-8") if agent_path else None,
        "xaiKeyPresent": "XAI_API_KEY" in os.environ,
    }
    LOG.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def inspect() -> None:
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
    }
    if SCENARIO == "bad-inspect":
        value["mcpServers"] = [{"name": "ambient", "disabled": False}]
    if SCENARIO == "missing-inspect-fields":
        value.pop("mcpServers")
        value.pop("permissions")
    print(json.dumps(value))


def streaming_result(*, stop_reason: str = "end_turn", is_error: bool = False) -> None:
    init = {
        "type": "system",
        "subtype": "init",
        "session_id": "fake-session",
        "tools": ["todo_write", "search_tool", "use_tool"],
        "skills": [],
        "mcp_servers": [],
    }
    if SCENARIO == "runtime-tool-call":
        tool_call = {
            "type": "assistant",
            "message": {"content": [{"type": "tool_use", "name": "todo_write", "input": {}}]},
        }
    else:
        tool_call = None
    print(json.dumps(init))
    if tool_call is not None:
        print(json.dumps(tool_call))
    print(
        json.dumps(
            {
                "type": "result",
                "subtype": "success",
                "is_error": is_error,
                "session_id": "fake-session",
                "stop_reason": stop_reason,
                "usage": {
                    "input_tokens": 10,
                    "output_tokens": 5,
                    "server_tool_use": {"web_search_requests": 0},
                },
                "structured_output": REVIEW,
            }
        )
    )


def main() -> int:
    if "--version" in sys.argv:
        print("grok 1.0.3 (fake) [stable]")
        return 0
    if len(sys.argv) > 1 and sys.argv[1] == "inspect":
        inspect()
        return 0

    write_invocation()
    if SCENARIO == "direct":
        print(json.dumps(REVIEW))
    elif SCENARIO == "envelope":
        print(json.dumps({"structured_output": REVIEW, "stopReason": "end_turn"}))
    elif SCENARIO in ("streaming", "runtime-tool-call"):
        streaming_result()
    elif SCENARIO == "incomplete":
        streaming_result(stop_reason="cancelled")
    elif SCENARIO == "result-error":
        streaming_result(is_error=True)
    elif SCENARIO == "max-turns":
        print(json.dumps({"type": "result", "subtype": "error_max_turns", "is_error": True}))
        return 1
    elif SCENARIO == "invalid-json":
        print("{not-json")
    elif SCENARIO == "nonzero":
        print(json.dumps({"type": "error", "message": "synthetic failure"}))
        print("synthetic stderr", file=sys.stderr)
        return 42
    elif SCENARIO == "timeout":
        child = subprocess.Popen(["/bin/sleep", "60"])
        CHILD_PID.write_text(str(child.pid), encoding="utf-8")
        time.sleep(60)
    else:
        raise SystemExit(f"unknown fake scenario: {SCENARIO}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
