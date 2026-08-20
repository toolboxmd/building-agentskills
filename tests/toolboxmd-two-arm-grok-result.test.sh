#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
benchmark="$root/benchmarks/toolboxmd-use-grok/two-arm-creator"
results="$benchmark/results/2026-08-20"
summary="$results/summary.json"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/toolboxmd-two-arm-result-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

find "$results" -type f -name '*.json' -print0 | xargs -0 -n 1 jq empty

[[ "$(jq -r '.decision.verdict' "$summary")" == "INCONCLUSIVE" ]] || fail "result is not inconclusive"
[[ "$(jq -r '.allArmsIsolationEligible' "$summary")" == "true" ]] || fail "not all authoring and judge runs are isolation-eligible"
[[ "$(jq -r '.heldOut.readyToFreeze' "$summary")" == "false" ]] || fail "known brief admitted held-out promotion"
[[ "$(jq '.heldOut.admittedArms | length' "$summary")" == "0" ]] || fail "a critical artifact was admitted to held-out"

[[ "$(jq -r '.arms.C.score.deterministic' "$summary")" == "35.0" ]] || fail "unexpected C deterministic score"
[[ "$(jq -r '.arms.C.score.semantic' "$summary")" == "29.0" ]] || fail "unexpected C semantic score"
[[ "$(jq -r '.arms.C.score.total' "$summary")" == "64.0" ]] || fail "unexpected C total"
[[ "$(jq -r '.arms.D.score.deterministic' "$summary")" == "20.0" ]] || fail "unexpected D deterministic score"
[[ "$(jq -r '.arms.D.score.semantic' "$summary")" == "27.0" ]] || fail "unexpected D semantic score"
[[ "$(jq -r '.arms.D.score.total' "$summary")" == "47.0" ]] || fail "unexpected D total"

for arm in C D; do
  authoring="$results/arms/$arm/authoring/run-metadata.json"
  judge="$results/arms/$arm/judge/run-metadata.json"
  grade="$results/arms/$arm/deterministic-grade.json"
  [[ "$(jq -r '.isolationEligible' "$authoring")" == "true" ]] || fail "arm $arm authoring is isolation-ineligible"
  [[ "$(jq -r '.authoring.tokenUsageRecorded' "$authoring")" == "true" ]] || fail "arm $arm authoring usage missing"
  [[ "$(jq -r '.limits.tokenEligibilityCap' "$authoring")" == "null" ]] || fail "arm $arm authoring has a token eligibility cap"
  [[ "$(jq -r '.realGrokCalls' "$authoring")" == "0" ]] || fail "arm $arm made a real Grok call"
  [[ "$(jq -r '.isolationEligible' "$judge")" == "true" ]] || fail "arm $arm judge is isolation-ineligible"
  [[ "$(jq -r '.judge.tokenUsageRecorded' "$judge")" == "true" ]] || fail "arm $arm judge usage missing"
  [[ "$(jq -r '.limits.tokenEligibilityCap' "$judge")" == "null" ]] || fail "arm $arm judge has a token eligibility cap"
  [[ "$(jq -r '.recommendableArtifact' "$grade")" == "false" ]] || fail "critical arm $arm was marked recommendable"
  [[ "$(jq '.criticalFailures | length' "$grade")" -gt 0 ]] || fail "arm $arm unexpectedly has no critical failure"
  [[ "$(jq -r '.inputs.treatment.aggregateSha256' "$authoring")" == "$(jq -r '.inputs.copiedTreatment.aggregateSha256' "$authoring")" ]] || fail "arm $arm copied treatment drifted"
  [[ "$(jq -r '.candidateAggregateSha256' "$grade")" == "$(jq -r '.candidate.aggregateSha256' "$judge")" ]] || fail "arm $arm judge did not score the graded candidate"
done

PYTHONDONTWRITEBYTECODE=1 python3 -B "$benchmark/harness/aggregate_results.py" \
  --results-root "$results" \
  --preregistration "$benchmark/preregistration.json" \
  --output "$tmp/summary.json" >/dev/null
cmp "$summary" "$tmp/summary.json" || fail "committed summary does not reproduce"

if rg -n 'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|sk-[A-Za-z0-9_-]{12,}|xai-[A-Za-z0-9_-]{12,}' "$results"; then
  fail "result tree contains credential-shaped evidence"
fi

echo "PASS: two-arm Grok semantic result"
