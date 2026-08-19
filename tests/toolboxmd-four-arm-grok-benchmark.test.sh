#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
benchmark="$root/benchmarks/toolboxmd-use-grok/four-arm-creator"
prereg="$benchmark/preregistration.json"
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

[[ "$(hash_tree "$benchmark/harness")" == "$(jq -r '.harness.aggregateSha256' "$prereg")" ]] || fail "harness hash drifted"

find "$root/benchmarks/toolboxmd-use-grok" -name '*.json' -type f -print0 | xargs -0 -n 1 jq empty
PYTHONDONTWRITEBYTECODE=1 python3 -B - "$benchmark/harness" <<'PY'
import ast
from pathlib import Path
import sys

for path in sorted(Path(sys.argv[1]).glob("*.py")):
    ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
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
