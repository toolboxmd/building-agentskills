#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
benchmark="$root/benchmarks/toolboxmd-creating-skills/refinement-v1"
results="$benchmark/results/2026-08-20"
known="$results/known-grok"
archive="$results/safe-archive-inspector"
fixture="$archive/post-run-audit-fixtures/nul-name.zip"
temporary="$(mktemp -d "${TMPDIR:-/tmp}/toolboxmd-refinement-result.XXXXXX")"
trap 'rm -rf "$temporary"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

find "$results" -type f -name '*.json' -print0 | xargs -0 -n 1 jq empty

[[ "$(jq -c '.armTrajectories.R0.scores' "$known/comparison.json")" == '[45,47,42]' ]] || fail "R0 known-task trajectory drifted"
[[ "$(jq -c '.armTrajectories.R1.scores' "$known/comparison.json")" == '[35,45,45]' ]] || fail "R1 known-task trajectory drifted"
[[ "$(jq -r '.ranked' "$known/comparison.json")" == 'false' ]] || fail "known task became ranked"
[[ "$(jq -r '.armTrajectories.R0.finalRecommendableArtifact' "$known/comparison.json")" == 'false' ]] || fail "R0 known artifact became recommendable"
[[ "$(jq -r '.armTrajectories.R1.finalRecommendableArtifact' "$known/comparison.json")" == 'false' ]] || fail "R1 known artifact became recommendable"

comparison="$archive/comparison.json"
audit="$archive/post-run-contract-audit.json"
[[ "$(jq -r '.verdict' "$comparison")" == 'INCONCLUSIVE' ]] || fail "held-out verdict drifted"
[[ "$(jq -r '.comparisonEligible' "$comparison")" == 'false' ]] || fail "invalid held-out comparison became eligible"
[[ "$(jq -r '.treatmentLeadClaimAllowed' "$comparison")" == 'false' ]] || fail "treatment lead claim was enabled"
[[ "$(jq -r '.reportedScores.R0.total' "$comparison")" == '100' ]] || fail "R0 reported score drifted"
[[ "$(jq -r '.reportedScores.R1.total' "$comparison")" == '98' ]] || fail "R1 reported score drifted"
[[ "$(jq -r '.resultEligibilityAffected' "$audit")" == 'true' ]] || fail "contract audit no longer affects eligibility"
[[ "$(jq -r '.contractRequirement' "$audit")" == 'nul-or-ascii-control' ]] || fail "contract-audit requirement drifted"

[[ "$(stat -f '%z' "$fixture")" == '116' ]] || fail "NUL fixture size drifted"
[[ "$(shasum -a 256 "$fixture" | awk '{print $1}')" == '563d7fc9a4abee276f93025af0bde830b156ac87064d6decd1116e71e1f0d9b7' ]] || fail "NUL fixture hash drifted"

PYTHONDONTWRITEBYTECODE=1 python3 -B - "$fixture" <<'PY'
import sys
import zipfile

member = zipfile.ZipFile(sys.argv[1]).infolist()[0]
assert member.filename == "safe"
assert member.orig_filename == "safe\x00name"
PY

for arm in R0 R1; do
  summary="$archive/arms/$arm/summary.json"
  grade="$archive/arms/$arm/round-0/deterministic-grade.json"
  authoring="$archive/arms/$arm/round-0/authoring/run-metadata.json"
  judge="$archive/arms/$arm/judge/run-metadata.json"
  semantic="$archive/arms/$arm/judge/semantic-score.json"
  candidate="$archive/arms/$arm/round-0/authoring/output-snapshot/skills/safe-archive-inspector"

  [[ "$(jq -r '.rounds | length' "$summary")" == '1' ]] || fail "$arm did not stop after the green initial round"
  [[ "$(jq -r '.rounds[0].deterministicPointsAwarded' "$summary")" == '70' ]] || fail "$arm deterministic report drifted"
  [[ "$(jq -r '.recommendableArtifact' "$grade")" == 'true' ]] || fail "$arm raw deterministic recommendation drifted"
  [[ "$(jq -r '.isolationEligible' "$authoring")" == 'true' ]] || fail "$arm authoring isolation failed"
  [[ "$(jq -r '.limits.tokenEligibilityCap' "$authoring")" == 'null' ]] || fail "$arm authoring regained a token cap"
  [[ "$(jq -r '.realExternalCalls' "$authoring")" == '0' ]] || fail "$arm made an external call"
  [[ "$(jq -r '.isolationEligible' "$judge")" == 'true' ]] || fail "$arm judge isolation failed"
  [[ "$(jq -r '.limits.tokenEligibilityCap' "$judge")" == 'null' ]] || fail "$arm judge regained a token cap"
  [[ "$(jq -r '.finalCandidate.aggregateSha256' "$summary")" == "$(jq -r '.candidate.aggregateSha256' "$judge")" ]] || fail "$arm judge candidate drifted"
  rg -q 'member\.filename' "$candidate/scripts/inspect_archive.py" || fail "$arm no longer exhibits the audited implementation pattern"

  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$candidate/scripts/inspect_archive.py" \
    --archive "$fixture" --max-entries 10 --max-total-bytes 1000 >"$temporary/$arm-nul.json"
  status=$?
  set -e
  [[ "$status" == '0' ]] || fail "$arm audited NUL behavior drifted"
  [[ "$(jq -r '.status' "$temporary/$arm-nul.json")" == 'safe' ]] || fail "$arm no longer reproduces the shared NUL defect"

  expected_semantic=30.0
  if [[ "$arm" == 'R1' ]]; then
    expected_semantic=28.0
  fi
  [[ "$(jq -r '.semanticPointsAwarded' "$semantic")" == "$expected_semantic" ]] || fail "$arm semantic score drifted"
done

[[ "$(jq -r '.privacyReliabilityPoints' "$archive/arms/R0/judge/semantic-score.json")" == '10' ]] || fail "R0 privacy score drifted"
[[ "$(jq -r '.privacyReliabilityPoints' "$archive/arms/R1/judge/semantic-score.json")" == '9' ]] || fail "R1 privacy score drifted"

if rg -n 'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|sk-[A-Za-z0-9_-]{12,}|xai-[A-Za-z0-9_-]{12,}' "$results"; then
  fail "result tree contains credential-shaped evidence"
fi

echo "PASS: bounded Creator refinement result remains inconclusive"
