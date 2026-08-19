#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
benchmark="$root/benchmarks/toolboxmd-use-grok/four-arm-creator"
prereg="$benchmark/preregistration.json"
amendment="$benchmark/results/2026-08-19/post-run-amendment.json"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/toolboxmd-four-arm-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

hash_tree() {
  node "$root/scripts/hash-tree.mjs" "$1" | jq -r '.aggregateSha256'
}

[[ "$(shasum -a 256 "$root/benchmarks/toolboxmd-use-grok/base-brief.md" | awk '{print $1}')" == "$(jq -r '.inputs.baseBrief.sha256' "$prereg")" ]] || fail "base brief hash drifted"
[[ "$(shasum -a 256 "$root/benchmarks/toolboxmd-use-grok/contract.json" | awk '{print $1}')" == "$(jq -r '.inputs.contract.sha256' "$prereg")" ]] || fail "contract hash drifted"
[[ "$(shasum -a 256 "$benchmark/authoring-prompt.md" | awk '{print $1}')" == "$(jq -r '.inputs.authoringPrompt.sha256' "$prereg")" ]] || fail "authoring prompt hash drifted"
[[ "$(shasum -a 256 "$benchmark/judge-prompt.md" | awk '{print $1}')" == "$(jq -r '.inputs.judgePrompt.sha256' "$prereg")" ]] || fail "judge prompt hash drifted"

for arm in A B C D; do
  path="$(jq -r --arg arm "$arm" '.treatments[$arm].path' "$prereg")"
  expected="$(jq -r --arg arm "$arm" '.treatments[$arm].aggregateSha256' "$prereg")"
  actual="$(hash_tree "$root/$path")"
  [[ "$actual" == "$expected" ]] || fail "treatment $arm hash drifted: $actual"
done

[[ "$(hash_tree "$benchmark/harness")" == "$(jq -r '.liveAfterFix.harnessAggregateSha256' "$amendment")" ]] || fail "current harness hash drifted"
[[ "$(jq -r '.harness.aggregateSha256' "$prereg")" == "$(jq -r '.preregistration.harnessAggregateSha256' "$amendment")" ]] || fail "preregistered harness hash drifted"
[[ "$(jq -r '.claimBoundary.rankingAllowed' "$amendment")" == "false" ]] || fail "post-run amendment allowed ranking"

find "$root/benchmarks/toolboxmd-use-grok" -name '*.json' -type f -print0 | xargs -0 -n 1 jq empty
PYTHONDONTWRITEBYTECODE=1 python3 -B - "$benchmark/harness" <<'PY'
import ast
from pathlib import Path
import sys

for path in sorted(Path(sys.argv[1]).glob("*.py")):
    ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
PY

PYTHONDONTWRITEBYTECODE=1 python3 -B - "$benchmark/harness" <<'PY'
from pathlib import Path
import runpy
import sys

harness = Path(sys.argv[1])
runner = runpy.run_path(str(harness / "run_authoring.py"))
preflight = runpy.run_path(str(harness / "isolation_preflight.py"))

server, thread, url, control = runner["start_network_probe"]()
try:
    assert control["kind"] == "live-loopback-http"
    assert control["succeeded"] is True
    assert control["httpStatus"] == 200
    assert preflight["valid_network_probe_url"](url) is True
    assert preflight["valid_network_probe_url"]("https://example.com/") is False
    assert preflight["network_denied"](6, False, True) is False
    assert preflight["network_denied"](6, True, True) is True
    assert preflight["network_denied"](0, True, True) is False
    config = runner["common_config"](
        Path("/tmp/sandbox"),
        Path("/tmp/sandbox/home/.codex/skills/creator-under-test/SKILL.md"),
        Path("/usr"),
        url,
    )
    rendered = "\n".join(config)
    assert "BENCHMARK_NETWORK_CONTROL_SUCCEEDED" in rendered
    assert "BENCHMARK_NETWORK_PROBE_URL" in rendered
finally:
    runner["stop_network_probe"](server, thread)
PY

PYTHONDONTWRITEBYTECODE=1 python3 -B - "$benchmark/harness/grade_candidate.py" "$tmp" <<'PY'
from pathlib import Path
import runpy
import sys

grader = runpy.run_path(sys.argv[1])
process_alive = grader["process_alive"]
proc_root = Path(sys.argv[2]) / "synthetic-proc"
stat_path = proc_root / "123" / "stat"
stat_path.parent.mkdir(parents=True)
stat_path.write_text("123 (fake child) Z 1 2 3\n", encoding="utf-8")
assert process_alive(123, proc_root=proc_root, linux=True) is False
stat_path.write_text("123 (fake child) S 1 2 3\n", encoding="utf-8")
assert process_alive(123, proc_root=proc_root, linux=True) is True
PY

for script in "$benchmark"/harness/*.py; do
  [[ -x "$script" ]] || fail "harness script is not executable: $script"
done

PYTHONDONTWRITEBYTECODE=1 python3 -B "$benchmark/harness/grade_candidate.py" \
  --candidate "$root/skills/toolboxmd-use-grok" \
  --fake-source "$benchmark/harness/fake_grok.py" \
  --contract "$root/benchmarks/toolboxmd-use-grok/contract.json" \
  --output "$tmp/refined-reference-grade.json" >/dev/null

[[ "$(jq -r '.deterministicPointsAwarded' "$tmp/refined-reference-grade.json")" == "70" ]] || fail "refined reference no longer earns 70 deterministic points"
[[ "$(jq '.criticalFailures | length' "$tmp/refined-reference-grade.json")" == "0" ]] || fail "refined reference has a critical deterministic failure"

echo "PASS: four-arm Grok benchmark preregistration and deterministic harness"
