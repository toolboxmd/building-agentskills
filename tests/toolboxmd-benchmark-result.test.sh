#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bench="$root/benchmarks/toolboxmd-creating-skills/v1"
result="$bench/results/2026-08-12"
evidence="$root/case-studies/evidence/2026-08-12-toolboxmd-creating-skills-benchmark.json"

for required in \
  "$result/manifest.json" \
  "$result/README.md" \
  "$result/candidate/toolboxmd-creating-skills/SKILL.md" \
  "$result/blind/initial/judgment.json" \
  "$result/blind/initial/judgment-validation.json" \
  "$result/blind/replay-webhook/judgment-validation.json" \
  "$result/blind/identity-map.json" \
  "$evidence"
do
  [[ -f "$required" ]] || { echo "FAIL: missing ${required#"$root/"}" >&2; exit 1; }
done

active_candidate="$root/skills/toolboxmd-creating-skills"
vnext_freeze="$root/benchmarks/toolboxmd-creating-skills/vnext/manifest.json"
if [[ -e "$active_candidate" && ! -f "$vnext_freeze" ]]; then
  echo "FAIL: an active creator needs an independent vNext freeze" >&2
  exit 1
fi

node - "$root" "$bench" "$result" "$evidence" <<'NODE'
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const [repositoryRoot, benchmarkRoot, resultRoot, evidencePath] = process.argv.slice(2);
const commitments = JSON.parse(fs.readFileSync(path.join(benchmarkRoot, "commitments.json"), "utf8"));
const sealedManifest = JSON.parse(fs.readFileSync(path.join(benchmarkRoot, "sealed-cases-manifest.json"), "utf8"));
const manifestPath = path.join(resultRoot, "manifest.json");
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const evidence = JSON.parse(fs.readFileSync(evidencePath, "utf8"));
const activeCandidatePath = path.join(repositoryRoot, "skills", "toolboxmd-creating-skills");
const vnextFreezePath = path.join(repositoryRoot, "benchmarks", "toolboxmd-creating-skills", "vnext", "manifest.json");

function assert(condition, message) {
  if (!condition) {
    console.error(`FAIL: ${message}`);
    process.exit(1);
  }
}

function treeManifest(root) {
  const files = [];
  function walk(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const absolute = path.join(directory, entry.name);
      if (entry.isSymbolicLink()) assert(false, `unexpected symbolic link: ${absolute}`);
      if (entry.isDirectory()) walk(absolute);
      else if (entry.isFile()) {
        const contents = fs.readFileSync(absolute);
        files.push({
          path: path.relative(root, absolute).split(path.sep).join("/"),
          bytes: contents.length,
          sha256: crypto.createHash("sha256").update(contents).digest("hex"),
        });
      }
    }
  }
  walk(root);
  files.sort((left, right) => left.path < right.path ? -1 : left.path > right.path ? 1 : 0);
  const lines = files.map(file => `${file.sha256}  ${file.path}\n`).join("");
  return {
    aggregateSha256: crypto.createHash("sha256").update(lines).digest("hex"),
    files,
  };
}

assert(manifest.schemaVersion === 2, "result manifest schemaVersion must be 2");
assert(manifest.decision.status === "inconclusive", "benchmark decision must reflect the isolation correction");
assert(manifest.decision.candidateRecommended === false, "unqualified candidate must not be recommended");
assert(manifest.acceptance.passed === false, "acceptance must remain false");
assert(manifest.acceptance.eligibleCreatorComparisons === 0, "an ineligible creator comparison was counted");
assert(manifest.acceptance.eligibleCandidateBlindWins === 0, "an eligible candidate win was claimed");
assert(manifest.acceptance.eligibleBaselineBlindWins === 0, "an eligible baseline win was claimed");
assert(manifest.acceptance.eligibleBlindTies === 0, "an eligible tie was claimed");
assert(manifest.acceptance.requiredBlindWins === 2, "required blind wins changed");
assert(manifest.acceptance.diagnosticCandidateCriticalMechanicalPasses === 3, "diagnostic candidate mechanical pass count changed");
assert(manifest.acceptance.originalFrozenScoring.candidateBlindWins === 0, "original frozen candidate score changed");
assert(manifest.acceptance.originalFrozenScoring.baselineBlindWins === 1, "original frozen baseline score changed");
assert(manifest.acceptance.originalFrozenScoring.blindTies === 1, "original frozen tie count changed");

const correction = manifest.postResultEvidenceCorrection;
assert(correction.retainedCompactEventAuditCount === 15, "retained compact event-audit count changed");
assert(correction.commandBearingCompactEventAuditCount === 15, "command-bearing compact event-audit count changed");
assert(correction.ineligibleCompactEventAuditCount === 15 && correction.eligibleCompactEventAuditCount === 0, "corrected eligibility totals changed");
assert(correction.rawModelEventJsonlRetained === false && correction.exactCommandReauditPossible === false, "missing raw events were overstated");
assert(correction.independentlyVerifiableIsolationEvidencePresent === false, "isolation evidence was fabricated");
assert(correction.modelSessionsAdded === 0, "post-result correction must not add model sessions");

const candidate = treeManifest(path.join(resultRoot, "candidate", "toolboxmd-creating-skills"));
assert(candidate.aggregateSha256 === commitments.candidate.aggregateSha256, "retained candidate does not match frozen commitment");
assert(candidate.aggregateSha256 === manifest.freezes.candidatePackageSha256, "candidate result hash differs from manifest");

const sealed = treeManifest(path.join(resultRoot, "sealed-cases"));
assert(sealed.aggregateSha256 === sealedManifest.aggregateSha256, "tracked sealed cases differ from freeze manifest");
assert(sealed.aggregateSha256 === manifest.freezes.sealedCasesSha256, "sealed result hash differs from manifest");
assert(sealed.files.length === sealedManifest.files.length, "tracked sealed case file count changed");
for (const expected of sealedManifest.files) {
  const actual = sealed.files.find(file => file.path === expected.path);
  assert(actual?.sha256 === expected.sha256 && actual?.bytes === expected.bytes, `sealed case drift: ${expected.path}`);
}

const casesTree = treeManifest(path.join(resultRoot, "cases"));
const blindTree = treeManifest(path.join(resultRoot, "blind"));
assert(casesTree.aggregateSha256 === manifest.retainedArtifactHashes.casesEvidenceTreeSha256, "case evidence tree changed");
assert(blindTree.aggregateSha256 === manifest.retainedArtifactHashes.blindEvidenceTreeSha256, "blind evidence tree changed");
assert(manifest.retainedArtifactHashes.preCorrectionCasesEvidenceTreeSha256 === "840bd98e7215419f8c743f4a8f83dd68153f2d7a48e3bcad42b1f6cc05c8cd90", "pre-correction case lineage changed");
assert(manifest.retainedArtifactHashes.preCorrectionBlindEvidenceTreeSha256 === "61bd52a65bddb0be455ec9170d623c31bc6251b7e43ad71499b995761f46a7cc", "pre-correction blind lineage changed");

const resultTree = treeManifest(resultRoot);
const auditRelativePaths = [
  "candidate-authoring/event-audit.json",
  ...casesTree.files.filter(file => file.path.endsWith("event-audit.json")).map(file => `cases/${file.path}`),
  ...blindTree.files.filter(file => file.path.endsWith("event-audit.json")).map(file => `blind/${file.path}`),
].sort();
assert(auditRelativePaths.length === 15, `expected exactly 15 retained compact event audits, got ${auditRelativePaths.length}`);
for (const relative of auditRelativePaths) {
  const audit = JSON.parse(fs.readFileSync(path.join(resultRoot, relative), "utf8"));
  assert(audit.schemaVersion === 2 && audit.eligible === false, `${relative}: correction eligibility changed`);
  assert(Number.isInteger(audit.commandCount) && audit.commandCount > 0, `${relative}: retained positive command count missing`);
  assert(Array.isArray(audit.reasons) && audit.reasons.length === 0, `${relative}: original compact reasons were rewritten`);
  assert(audit.eligibilityCorrection?.originalSchemaVersion === 1 && audit.eligibilityCorrection?.originalEligible === true, `${relative}: original audit status missing`);
  assert(audit.eligibilityCorrection?.rawEventsRetained === false && audit.eligibilityCorrection?.modelSessionsAdded === 0, `${relative}: correction provenance changed`);
  assert(audit.isolationEvidence?.required === true && audit.isolationEvidence?.status === "not_recorded" && audit.isolationEvidence?.trusted === false, `${relative}: missing-isolation classification changed`);
}
const retainedModelEventJsonl = resultTree.files.filter(file => file.path.endsWith(".jsonl") && !file.path.startsWith("sealed-cases/"));
assert(retainedModelEventJsonl.length === 0, "result unexpectedly claims retained raw model-event JSONL");

const preflight = JSON.parse(fs.readFileSync(path.join(resultRoot, "preflight", "summary.json"), "utf8"));
assert(preflight.networkProbe.blocked === true, "historical failed DNS observation changed");
assert(preflight.eligibilityCorrection.strictIsolationEligible === false, "behavioral preflight was promoted to isolation proof");

for (const caseId of ["webhook-triage", "csv-sanitizer", "release-evidence"]) {
  for (const treatment of ["builtin", "toolboxmd"]) {
    const grade = JSON.parse(fs.readFileSync(path.join(resultRoot, "cases", caseId, treatment, "evidence", "downstream-deterministic-grade.json"), "utf8"));
    assert(grade.passed === true && grade.failedCheckCount === 0, `${caseId}/${treatment}: deterministic grade changed`);
  }
  const candidateBoundary = JSON.parse(fs.readFileSync(path.join(resultRoot, "cases", caseId, "toolboxmd", "evidence", "authoring-boundary-audit.json"), "utf8"));
  assert(candidateBoundary.eligible === true, `${caseId}: historical file-mutation boundary check changed`);
}

const initialValidation = JSON.parse(fs.readFileSync(path.join(resultRoot, "blind", "initial", "judgment-validation.json"), "utf8"));
const replayValidation = JSON.parse(fs.readFileSync(path.join(resultRoot, "blind", "replay-webhook", "judgment-validation.json"), "utf8"));
const identityMap = JSON.parse(fs.readFileSync(path.join(resultRoot, "blind", "identity-map.json"), "utf8"));
assert(initialValidation.valid === true, "initial frozen-rubric validation changed");
assert(replayValidation.valid === false, "invalid replay must not become valid");
assert(identityMap.revealed === true, "identity map must be revealed only in retained evidence");

const manifestSha256 = crypto.createHash("sha256").update(fs.readFileSync(manifestPath)).digest("hex");
assert(evidence.evidence.result_manifest_sha256 === manifestSha256, "case-study evidence points to a different result manifest");
assert(evidence.benchmark.decision === "inconclusive" && evidence.benchmark.candidate_recommended === false, "case-study evidence overstates the result");
assert(evidence.benchmark.acceptance.eligible_creator_comparisons === 0, "case-study evidence claims an eligible comparison");
assert(evidence.post_result_evidence_correction.ineligible_compact_event_audits === 15, "case-study correction count changed");
assert(evidence.post_result_evidence_correction.raw_model_event_jsonl_retained === false, "case-study evidence overstates retained traces");
assert(evidence.evidence.candidate_package_sha256 === candidate.aggregateSha256, "case-study candidate hash changed");
assert(evidence.evidence.sealed_cases_sha256 === sealed.aggregateSha256, "case-study sealed-case hash changed");

const auditorPath = path.join(repositoryRoot, "scripts", "audit-codex-events.mjs");
const auditorSha256 = crypto.createHash("sha256").update(fs.readFileSync(auditorPath)).digest("hex");
assert(manifest.retainedArtifactHashes.genericEventAuditorSha256 === auditorSha256, "generic event-auditor hash changed");
assert(evidence.evidence.generic_event_auditor_sha256 === auditorSha256, "case-study auditor hash changed");

if (fs.existsSync(activeCandidatePath)) {
  assert(fs.existsSync(vnextFreezePath), "active creator lacks its vNext freeze");
  const active = treeManifest(activeCandidatePath);
  const vnext = JSON.parse(fs.readFileSync(vnextFreezePath, "utf8"));
  assert(active.aggregateSha256 === vnext.package.aggregateSha256, "active creator differs from vNext freeze");
  assert(active.aggregateSha256 !== candidate.aggregateSha256, "failed v1 candidate was restored to the active path");
  assert(vnext.claimBoundary.superiorityClaimAllowed === false && vnext.claimBoundary.promotionClaimAllowed === false, "vNext overstates the v1 result");
}
NODE

echo "PASS: v1 ToolboxMD evidence remains preserved, ineligible, and non-promoted"
