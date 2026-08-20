#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
benchmark="$root/benchmarks/toolboxmd-use-grok/two-arm-creator"
prereg="$benchmark/preregistration.json"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/toolboxmd-two-arm-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

hash_tree() {
  node "$root/scripts/hash-tree.mjs" "$1" | jq -r '.aggregateSha256'
}

jq empty "$prereg"

[[ "$(jq -r '.treatments | keys | join(",")' "$prereg")" == "C,D" ]] || fail "ranked treatments are not exactly C and D"
[[ "$(jq -r '.authoringRun.wallTimeLimitSeconds' "$prereg")" == "900" ]] || fail "authoring wall time is not 900 seconds"
[[ "$(jq -r '.authoringRun.tokenEligibilityCap' "$prereg")" == "null" ]] || fail "authoring token quantity still gates eligibility"
[[ "$(jq -r '.blindJudgeRun.tokenEligibilityCap' "$prereg")" == "null" ]] || fail "judge token quantity still gates eligibility"
[[ "$(jq -r '.blindJudgeRun.mandatoryForIsolationEligibleCandidate' "$prereg")" == "true" ]] || fail "semantic judge is not mandatory"
[[ "$(jq -r '.blindJudgeRun.runsDespiteDeterministicCriticalFailure' "$prereg")" == "true" ]] || fail "critical artifacts would skip semantic grading"
[[ "$(jq -r '.evaluation.semanticDoesNotOverrideCriticalFailure' "$prereg")" == "true" ]] || fail "semantic score can override a critical failure"
[[ "$(jq -r '.acceptanceRefinementHypothesis.testedInThisRun' "$prereg")" == "false" ]] || fail "acceptance refinement leaked into this treatment"

[[ "$(shasum -a 256 "$root/benchmarks/toolboxmd-use-grok/base-brief.md" | awk '{print $1}')" == "$(jq -r '.inputs.baseBrief.sha256' "$prereg")" ]] || fail "base brief hash drifted"
[[ "$(shasum -a 256 "$root/benchmarks/toolboxmd-use-grok/contract.json" | awk '{print $1}')" == "$(jq -r '.inputs.contract.sha256' "$prereg")" ]] || fail "contract hash drifted"
[[ "$(shasum -a 256 "$benchmark/authoring-prompt.md" | awk '{print $1}')" == "$(jq -r '.inputs.authoringPrompt.sha256' "$prereg")" ]] || fail "authoring prompt hash drifted"
[[ "$(shasum -a 256 "$benchmark/judge-prompt.md" | awk '{print $1}')" == "$(jq -r '.inputs.judgePrompt.sha256' "$prereg")" ]] || fail "judge prompt hash drifted"

for arm in C D; do
  path="$(jq -r --arg arm "$arm" '.treatments[$arm].path' "$prereg")"
  expected="$(jq -r --arg arm "$arm" '.treatments[$arm].aggregateSha256' "$prereg")"
  [[ "$(hash_tree "$root/$path")" == "$expected" ]] || fail "treatment $arm hash drifted"
done

[[ "$(hash_tree "$benchmark/harness")" == "$(jq -r '.harness.aggregateSha256' "$prereg")" ]] || fail "two-arm harness hash drifted"

PYTHONDONTWRITEBYTECODE=1 python3 -B - "$benchmark/harness" <<'PY'
import ast
from pathlib import Path
import runpy
import sys

harness = Path(sys.argv[1])
for path in sorted(harness.glob("*.py")):
    ast.parse(path.read_text(encoding="utf-8"), filename=str(path))

sys.path.insert(0, str(harness))
authoring = runpy.run_path(str(harness / "run_authoring.py"))
judge = runpy.run_path(str(harness / "run_blind_judge.py"))
aggregate = runpy.run_path(str(harness / "aggregate_results.py"))
assert authoring["WALL_TIME_LIMIT_SECONDS"] == 900
assert judge["WALL_TIME_LIMIT_SECONDS"] == 600
assert aggregate["ARMS"] == ("C", "D")
for module in (authoring, judge):
    assert "INPUT_TOKEN_LIMIT" not in module
    assert "OUTPUT_TOKEN_LIMIT" not in module
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

echo "PASS: two-arm Grok semantic preregistration and harness"
