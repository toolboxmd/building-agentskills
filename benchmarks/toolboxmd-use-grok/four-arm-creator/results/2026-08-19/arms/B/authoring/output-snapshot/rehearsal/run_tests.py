#!/usr/bin/env python3
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
ADAPTER = ROOT / "output/skills/toolboxmd-use-grok/scripts/consult-grok"
FAKE = ROOT / "harness/fake_grok.py"
BASE = ROOT / "output/rehearsal/matrix"
PROMPT = ROOT / "output/rehearsal/prompt.txt"
HOME = ROOT / "output/rehearsal/home"


def invoke(name, scenario=None, timeout="5", grok=None, mode="explicit"):
    case = BASE / name
    bin_dir = case / "bin"
    runs = case / "runs"
    bin_dir.mkdir(parents=True, exist_ok=True)
    runs.mkdir(parents=True, exist_ok=True)
    fake = bin_dir / "grok"
    shutil.copyfile(FAKE, fake)
    fake.chmod(0o755)
    if scenario == "timeout":
        source = fake.read_text(encoding="utf-8")
        source = source.replace(
            'child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"])\n'
            '        CHILD_PID.write_text(str(child.pid), encoding="utf-8")',
            'child_pid = os.fork()\n'
            '        if child_pid == 0:\n'
            '            time.sleep(60)\n'
            '            os._exit(0)\n'
            '        CHILD_PID.write_text(str(child_pid), encoding="utf-8")',
        )
        fake.write_text(source, encoding="utf-8")
    if scenario:
        (bin_dir / "scenario.txt").write_text(scenario + "\n", encoding="utf-8")
    command = [
        str(ADAPTER), "--mode", mode, "--prompt-file", str(PROMPT),
        "--output-dir", str(runs), "--grok-home", str(HOME),
        "--grok-bin", str(grok or fake), "--timeout", timeout, "--max-turns", "3",
    ]
    result = subprocess.run(command, text=True, capture_output=True, check=False)
    lines = result.stdout.splitlines()
    assert len(lines) == 1, (name, result.stdout, result.stderr)
    value = json.loads(lines[0])
    return result, value, bin_dir


expected = {
    "direct": "ok",
    "envelope": "ok",
    "streaming": "ok",
    "bad-inspect": "isolation-failure",
    "missing-inspect-fields": "isolation-failure",
    "runtime-tool-call": "isolation-failure",
    "incomplete": "incomplete-stop-reason",
    "result-error": "nonzero-exit",
    "max-turns": "max-turns",
    "invalid-json": "invalid-json",
    "nonzero": "nonzero-exit",
}
for scenario, status in expected.items():
    result, value, bin_dir = invoke(scenario, scenario)
    assert value["status"] == status, (scenario, value)
    assert result.returncode == (0 if status == "ok" else 1), (scenario, result.returncode)
    if scenario in {"direct", "envelope", "streaming"}:
        assert value["review"]["verdict"] == "PROCEED WITH CHANGES"
        invocation = json.loads((bin_dir / "invocation.json").read_text(encoding="utf-8"))
        prompt = PROMPT.read_text(encoding="utf-8")
        assert invocation["prompt"] == prompt
        assert all(prompt not in argument for argument in invocation["argv"])
        assert invocation["cwdFiles"] == ["agent.md", "prompt.txt", "review-schema.json"]
        assert "--always-approve" not in invocation["argv"] and "--yolo" not in invocation["argv"]

result, value, bin_dir = invoke("timeout", "timeout", timeout="0.3")
assert value["status"] == "timeout" and result.returncode == 1
pid = int((bin_dir / "child.pid").read_text(encoding="utf-8"))
for _ in range(40):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        break
    time.sleep(0.05)
else:
    raise AssertionError("timeout child still exists")

result, value, _ = invoke("missing", grok=BASE / "missing/no-grok")
assert value["status"] == "missing-cli" and result.returncode == 1
result, value, bin_dir = invoke("automatic", mode="automatic")
assert value["status"] == "isolation-failure" and result.returncode == 1
assert not (bin_dir / "invocation.json").exists()
assert not (ROOT / "SHOULD_NOT_EXIST").exists() and not (ROOT / "ALSO_NOT").exists()
print(json.dumps({"passed": True, "scenarios": len(expected) + 3}, sort_keys=True))
