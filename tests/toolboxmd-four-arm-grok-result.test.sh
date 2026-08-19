#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
benchmark="$root/benchmarks/toolboxmd-use-grok/four-arm-creator"
results="$benchmark/results/2026-08-19"
summary="$results/summary.json"
amendment="$results/post-run-amendment.json"
validator="$root/skills/toolboxmd-creating-skills/scripts/validate_skill.py"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/toolboxmd-four-arm-result-test.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

jq empty "$summary"
[[ "$(jq -r '.verdict.code' "$summary")" == "INELIGIBLE_TOKEN_CAP" ]] || fail "unexpected verdict"
[[ "$(jq -r '.verdict.rankingAllowed' "$summary")" == "false" ]] || fail "ranking must remain disabled"
[[ "$(jq -r '.abort.judgeRunsStarted' "$summary")" == "0" ]] || fail "judge run count drifted"
[[ "$(jq -r '.abort.semanticScoringStarted' "$summary")" == "false" ]] || fail "semantic scoring must remain absent"
[[ "$(jq -r '.conditions.realGrokCalls' "$summary")" == "0" ]] || fail "real Grok call count drifted"
[[ "$(jq -r '.postRunReviewAmendment.verdictChanged' "$summary")" == "false" ]] || fail "post-run amendment changed the verdict"
[[ "$(jq -r '.postRunReviewAmendment.historicalNetworkIsolationEvidenceSufficient' "$summary")" == "false" ]] || fail "historical network evidence was promoted"
[[ "$(jq -r '.liveAfterFix.networkPreflightVerification.unsandboxedControlHttpStatus' "$amendment")" == "200" ]] || fail "live network control evidence drifted"
[[ "$(jq -r '.liveAfterFix.networkPreflightVerification.sandboxProbeExitStatus' "$amendment")" == "7" ]] || fail "sandbox network denial evidence drifted"
[[ "$(jq -r '.liveAfterFix.networkPreflightVerification.modelCalls' "$amendment")" == "0" ]] || fail "network preflight unexpectedly used a model"
[[ "$(jq -r '.postRunReviewAmendment.activeGrokRedactedSchemaResolution' "$summary")" == *"returns invalid-json"* ]] || fail "redacted review schema resolution drifted"
[[ "$(node "$root/scripts/hash-tree.mjs" "$root/skills/toolboxmd-use-grok" | jq -r '.aggregateSha256')" == "$(jq -r '.postRunReviewAmendment.currentActiveGrokAggregateSha256' "$summary")" ]] || fail "current active Grok hash drifted"
[[ "$(node "$root/scripts/hash-tree.mjs" "$benchmark/harness" | jq -r '.aggregateSha256')" == "$(jq -r '.postRunReviewAmendment.currentHarnessAggregateSha256' "$summary")" ]] || fail "current post-run harness hash drifted"
[[ "$(jq -r '.liveAfterFix.activeGrokAggregateSha256' "$amendment")" == "$(jq -r '.postRunReviewAmendment.currentActiveGrokAggregateSha256' "$summary")" ]] || fail "post-run active Grok amendment drifted"
[[ "$(jq -r '.liveAfterFix.harnessAggregateSha256' "$amendment")" == "$(jq -r '.postRunReviewAmendment.currentHarnessAggregateSha256' "$summary")" ]] || fail "post-run harness amendment drifted"
[[ "$(jq -r '.claimBoundary.rankingAllowed' "$amendment")" == "false" ]] || fail "post-run amendment allowed ranking"

if find "$results/arms" -path '*/judge/*' -type f -print -quit | grep -q .; then
  fail "judge evidence exists despite the recorded abort"
fi

for arm in A B C D; do
  arm_root="$results/arms/$arm"
  metadata="$arm_root/authoring/run-metadata.json"
  grade="$arm_root/deterministic-grade.json"
  manifest="$arm_root/authoring/output-manifest.json"
  candidate="$arm_root/authoring/output-snapshot/skills/toolboxmd-use-grok"

  jq empty "$metadata" "$grade" "$manifest"
  [[ "$(jq -r '.controlPreflight.passed' "$metadata")" == "true" ]] || fail "$arm control preflight failed"
  [[ "$(jq -r '.authoring.modelPreflightPassed' "$metadata")" == "true" ]] || fail "$arm model preflight failed"
  [[ "$(jq -r '.authoring.exitStatus' "$metadata")" == "0" ]] || fail "$arm authoring exit drifted"
  [[ "$(jq -r '.realGrokCalls' "$metadata")" == "0" ]] || fail "$arm real Grok count drifted"

  [[ "$(jq -r '.authoring.usage.input_tokens' "$metadata")" == "$(jq -r --arg arm "$arm" '.arms[$arm].authoring.inputTokens' "$summary")" ]] || fail "$arm input-token count drifted"
  [[ "$(jq -r '.authoring.tokenCapPassed' "$metadata")" == "$(jq -r --arg arm "$arm" '.arms[$arm].authoring.tokenCapPassed' "$summary")" ]] || fail "$arm token-cap result drifted"
  [[ "$(jq -r '.isolationEligible' "$metadata")" == "$(jq -r --arg arm "$arm" '.arms[$arm].authoring.isolationEligible' "$summary")" ]] || fail "$arm isolation eligibility drifted"
  [[ "$(jq -r '.candidateAggregateSha256' "$grade")" == "$(jq -r --arg arm "$arm" '.arms[$arm].candidate.aggregateSha256' "$summary")" ]] || fail "$arm candidate hash drifted"
  [[ "$(jq -r '.deterministicPointsAwarded' "$grade")" == "$(jq -r --arg arm "$arm" '.arms[$arm].deterministicDiagnostic.pointsAwarded' "$summary")" ]] || fail "$arm deterministic score drifted"
  [[ "$(jq -c '.criticalFailures' "$grade")" == "$(jq -c --arg arm "$arm" '.arms[$arm].deterministicDiagnostic.criticalFailures' "$summary")" ]] || fail "$arm critical failures drifted"

  snapshot_hash="$(node "$root/scripts/hash-tree.mjs" "$arm_root/authoring/output-snapshot" | jq -r '.aggregateSha256')"
  retained_manifest_hash="$(
    jq -r '
      . as $manifest
      | .files[]
      | select((.path | split("/")[0]) as $top | ($manifest.excludedDirectories | index($top) | not))
      | "\(.sha256)  \(.path)"
    ' "$manifest" | shasum -a 256 | awk '{print $1}'
  )"
  [[ "$snapshot_hash" == "$retained_manifest_hash" ]] || fail "$arm retained output snapshot drifted"
  [[ "$(jq '.omittedSymlinks | length' "$manifest")" == "0" ]] || fail "$arm omitted a generated symlink"
  if find "$arm_root/authoring/output-snapshot" -type l -print -quit | grep -q .; then
    fail "$arm retained output contains a symlink"
  fi

  candidate_bytes="$(jq '[.files[] | select(.path | startswith("skills/toolboxmd-use-grok/")) | .bytes] | add' "$manifest")"
  [[ "$candidate_bytes" == "$(jq -r --arg arm "$arm" '.arms[$arm].candidate.packageBytes' "$summary")" ]] || fail "$arm candidate bytes drifted"

  adapter_digest="$(shasum -a 256 "$candidate/scripts/consult-grok" | awk '{print $1}')"
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" \
    --json \
    --creation-mode \
    --warnings-as-errors \
    --script-syntax-checked "scripts/consult-grok=$adapter_digest" \
    --max-description-chars 400 \
    --max-skill-lines 150 \
    --max-skill-bytes 10500 \
    --max-files 2 \
    --max-package-bytes 45000 \
    --max-reference-files 0 \
    --max-eval-files 0 \
    --max-script-files 1 \
    "$candidate" >"$tmp/$arm-validator.json"
  validator_exit=$?
  set -e

  expected_exit="$(jq -r --arg arm "$arm" '.arms[$arm].customToolboxmdValidatorDiagnostic.exitStatus' "$summary")"
  [[ "$validator_exit" == "$expected_exit" ]] || fail "$arm custom validator exit drifted"
  [[ "$(jq -r '.status' "$tmp/$arm-validator.json")" == "$(jq -r --arg arm "$arm" '.arms[$arm].customToolboxmdValidatorDiagnostic.status' "$summary")" ]] || fail "$arm custom validator status drifted"
  [[ "$(jq -c '[.issues[].code]' "$tmp/$arm-validator.json")" == "$(jq -c --arg arm "$arm" '.arms[$arm].customToolboxmdValidatorDiagnostic.issueCodes' "$summary")" ]] || fail "$arm custom validator issues drifted"
done

for ref in historical-raw acceptance-refined; do
  grade="$results/references/$ref/deterministic-grade.json"
  summary_key="$(printf '%s' "$ref" | awk -F- '{printf "%s", $1; for (i=2; i<=NF; i++) printf "%s%s", toupper(substr($i,1,1)), substr($i,2)}')"
  [[ "$(jq -r '.deterministicPointsAwarded' "$grade")" == "$(jq -r --arg key "$summary_key" '.unrankedReferences[$key].deterministicPointsAwarded' "$summary")" ]] || fail "$ref deterministic score drifted"
  [[ "$(jq -c '.criticalFailures' "$grade")" == "$(jq -c --arg key "$summary_key" '.unrankedReferences[$key].criticalFailures' "$summary")" ]] || fail "$ref critical failures drifted"
done

echo "PASS: four-arm Grok ineligible diagnostic result"
