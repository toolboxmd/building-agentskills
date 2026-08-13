#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
result="$root/benchmarks/toolboxmd-creating-skills/v2/results/2026-08-13"

required=(
  "$result/README.md"
  "$result/manifest.json"
  "$result/recommendations.md"
  "$result/retention-manifest.json"
  "$result/session-usage.json"
  "$result/discarded-authoring/failure.json"
  "$root/case-studies/2026-08-13-toolboxmd-creating-skills-benchmark-v2.md"
  "$root/case-studies/evidence/2026-08-13-toolboxmd-creating-skills-benchmark-v2.json"
)

for path in "${required[@]}"; do
  if [[ ! -f "$path" ]]; then
    echo "FAIL: missing ${path#"$root/"}" >&2
    exit 1
  fi
done

active_candidate="$root/skills/toolboxmd-creating-skills"
vnext_freeze="$root/benchmarks/toolboxmd-creating-skills/vnext/manifest.json"
if [[ -e "$active_candidate" && ! -f "$vnext_freeze" ]]; then
  echo "FAIL: an active creator needs an independent vNext freeze" >&2
  exit 1
fi

raw_event_count="$(find "$result" -type f \( -name 'events.jsonl' -o -name '*-events.jsonl' \) | wc -l | tr -d ' ')"
if [[ "$raw_event_count" != "17" ]]; then
  echo "FAIL: expected 17 inspectable raw event streams, found $raw_event_count" >&2
  exit 1
fi

node - "$root" "$result" <<'NODE'
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const [repositoryRoot, resultRoot] = process.argv.slice(2);
const activeCandidatePath = path.join(repositoryRoot, "skills", "toolboxmd-creating-skills");
const vnextFreezePath = path.join(repositoryRoot, "benchmarks", "toolboxmd-creating-skills", "vnext", "manifest.json");

function readJson(relative) {
  return JSON.parse(fs.readFileSync(path.join(resultRoot, relative), "utf8"));
}

function assert(condition, message) {
  if (!condition) {
    console.error(`FAIL: ${message}`);
    process.exit(1);
  }
}

function sha256File(file) {
  return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}

function treeManifest(root) {
  const files = [];
  function walk(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const absolute = path.join(directory, entry.name);
      assert(!entry.isSymbolicLink(), `unexpected symbolic link: ${absolute}`);
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
  const aggregateSha256 = crypto.createHash("sha256")
    .update(files.map(file => `${file.sha256}  ${file.path}\n`).join(""))
    .digest("hex");
  return { aggregateSha256, files };
}

const manifest = readJson("manifest.json");
assert(manifest.schemaVersion === 2, "unexpected result schema");
assert(manifest.benchmarkId === "toolboxmd-creating-skills-v2", "unexpected benchmark ID");
assert(manifest.decision.status === "inconclusive", "corrected result must remain inconclusive");
assert(manifest.decision.recommendedCreator === null, "a general creator recommendation is not supported");
assert(manifest.decision.toolboxmdCandidateRecommended === false, "ToolboxMD candidate must remain unpromoted");
assert(manifest.decision.publicSuperiorityClaimAllowed === false, "superiority claim must remain forbidden");
assert(manifest.acceptance.builtinCaseWins === 0, "built-in win count changed");
assert(manifest.acceptance.toolboxmdCaseWins === 0, "ToolboxMD win count changed");
assert(manifest.acceptance.toolboxmdPromotionGatePassed === false, "ToolboxMD promotion gate changed");
assert(manifest.acceptance.primaryCasesQualified === 0, "command-bearing qualification streams must remain unqualified");
assert(manifest.acceptance.eligiblePairedCases === 0, "no paired case may remain eligible");
assert(manifest.acceptance.ineligibleAuthoringRuns === 4, "corrected authoring exclusion count changed");
assert(manifest.acceptance.ineligiblePositiveRuns === 4, "corrected downstream exclusion count changed");
assert(manifest.acceptance.ineligibleScoredStreams === 8, "corrected scored-stream exclusion count changed");
assert(manifest.acceptance.positiveTargetLoads === 4, "all positive runs must load their target skill");
assert(manifest.acceptance.nearMissTargetLoads === 0, "near-miss runs must not load target skills");
assert(manifest.acceptance.reserveUsed === false, "reserve must remain unopened");
assert(manifest.acceptance.sessionsRemainingUnderHardLimit === 1, "hard-limit accounting changed");
if (fs.existsSync(activeCandidatePath)) {
  assert(fs.existsSync(vnextFreezePath), "active creator lacks its vNext freeze");
  const active = treeManifest(activeCandidatePath);
  const vnext = JSON.parse(fs.readFileSync(vnextFreezePath, "utf8"));
  assert(active.aggregateSha256 === vnext.package.aggregateSha256, "active creator differs from vNext freeze");
  assert(active.aggregateSha256 !== manifest.freezes.toolboxmdCreatorSha256, "unpromoted v2 treatment was restored to the active path");
  assert(vnext.claimBoundary.superiorityClaimAllowed === false && vnext.claimBoundary.promotionClaimAllowed === false, "vNext overstates the v2 result");
}

const condensed = JSON.parse(fs.readFileSync(
  path.join(repositoryRoot, "case-studies/evidence/2026-08-13-toolboxmd-creating-skills-benchmark-v2.json"),
  "utf8",
));
assert(condensed.benchmark.id === manifest.benchmarkId, "condensed evidence benchmark ID changed");
assert(condensed.benchmark.decision === manifest.decision.status, "condensed evidence decision changed");
assert(condensed.benchmark.recommended_creator === null, "condensed evidence overstates a winner");
assert(condensed.benchmark.toolboxmd_candidate_recommended === false, "condensed evidence overstates ToolboxMD promotion");
assert(condensed.evidence.result_manifest === "benchmarks/toolboxmd-creating-skills/v2/results/2026-08-13/manifest.json", "condensed result path changed");
assert(sha256File(path.join(resultRoot, "manifest.json")) === condensed.evidence.result_manifest_sha256, "condensed result hash changed");
assert(condensed.evidence.retention_manifest_sha256 === manifest.retainedEvidence.retentionManifestSha256, "condensed retention hash changed");
assert(condensed.post_result_audit_correction.ineligible_stream_count === 15, "condensed corrected ineligible stream count changed");
assert(condensed.post_result_audit_correction.ineligible_scored_streams === 8, "condensed corrected scored-stream count changed");
assert(condensed.post_result_audit_correction.ineligible_scored_pipelines === 4, "condensed corrected scored-pipeline count changed");

const preflightEvent = readJson("preflight/event-audit.json");
const preflightBoundary = readJson("preflight/boundary-audit.json");
const isolationReason = "command execution lacks recorded trusted filesystem, environment, and network isolation evidence";
assert(preflightEvent.schemaVersion === 3, "preflight audit schema changed");
assert(preflightEvent.eligible === false && preflightBoundary.eligible === true, "historical preflight eligibility changed");
assert(preflightEvent.reasons.includes(isolationReason), "preflight isolation-evidence reason missing");
assert(preflightEvent.isolationEvidence?.status === "not_recorded", "preflight isolation evidence is overstated");
assert(preflightEvent.expectedSkillLoad?.fullContentObserved === true, "preflight did not prove full skill loading");
assert(preflightEvent.networkProbe?.blocked === true, "preflight did not retain the failed curl observation");
assert(JSON.stringify(preflightEvent.networkProbe.exitCodes) === JSON.stringify([6]), "unexpected network probe result");

const expected = {
  "meeting-followups": {
    qualificationPasses: 2,
    qualificationFailures: ["follow-up-file", "qa-file", "follow-up-headings", "follow-up-content", "tracker-exact", "qa-exact"],
    outputHashes: {
      builtin: "6883e931fa86f1a0cf6221e635fd9235e58d0ca7f6d0d59e86ba65d890616589",
      toolboxmd: "6883e931fa86f1a0cf6221e635fd9235e58d0ca7f6d0d59e86ba65d890616589",
    },
    packageHashes: {
      builtin: "9f715024c2f0af89f964360eee9e0ea576142c9e4a3fbf194b63475b277446ac",
      toolboxmd: "6f738c66e2aa13c9e1f8e69aa019a5c1e82451d22e28c9da6a21be53affa102c",
    },
    passes: { builtin: 7, toolboxmd: 7 },
    authoringEligible: { builtin: false, toolboxmd: false },
    downstreamEligible: { builtin: false, toolboxmd: false },
  },
  "weekly-status-deck": {
    qualificationPasses: 7,
    qualificationFailures: ["deck-check-exact"],
    outputHashes: {
      builtin: "c55b4fb1f93a3b4772b969c2467f2e9ff342167eaf623f4bf624e93d42f56b02",
      toolboxmd: "cc1723ac5ee52d0a931b57e872ac82a615798c9e5e2a1232cb4464323bea388b",
    },
    packageHashes: {
      builtin: "97416c354724a671b3f094794e9549a52b27188066cd106e6c5990a92742624f",
      toolboxmd: "8d85b408c77c0c8f625f1c6d5cc574482ccae1e8efa7dc1e79a5828735eb9ea0",
    },
    passes: { builtin: 8, toolboxmd: 8 },
    authoringEligible: { builtin: false, toolboxmd: false },
    downstreamEligible: { builtin: false, toolboxmd: false },
  },
};

for (const [caseId, caseExpected] of Object.entries(expected)) {
  const qualificationGrade = readJson(`qualification/${caseId}/evidence/grade.json`);
  const qualificationEvent = readJson(`qualification/${caseId}/evidence/event-audit.json`);
  const qualificationBoundary = readJson(`qualification/${caseId}/evidence/boundary-audit.json`);
  assert(qualificationEvent.eligible === false && qualificationBoundary.eligible === true, `${caseId}: historical no-skill eligibility changed`);
  assert(qualificationEvent.reasons.includes(isolationReason), `${caseId}: no-skill isolation-evidence reason missing`);
  assert(manifest.qualification[caseId].qualified === false, `${caseId}: ineligible no-skill arm cannot qualify the case`);
  assert(qualificationEvent.observedSkillLoads.length === 0, `${caseId}: no-skill run loaded a skill`);
  assert(qualificationGrade.criticalPassCount === caseExpected.qualificationPasses, `${caseId}: qualification score changed`);
  assert(JSON.stringify(qualificationGrade.criticalFailedCheckIds) === JSON.stringify(caseExpected.qualificationFailures), `${caseId}: qualification failures changed`);

  for (const treatment of ["builtin", "toolboxmd"]) {
    const base = `cases/${caseId}/${treatment}`;
    const grade = readJson(`${base}/evidence/downstream-grade.json`);
    const event = readJson(`${base}/evidence/downstream-event-audit.json`);
    const boundary = readJson(`${base}/evidence/downstream-boundary-audit.json`);
    const authoringEvent = readJson(`${base}/evidence/authoring-event-audit.json`);
    const authoringBoundary = readJson(`${base}/evidence/authoring-boundary-audit.json`);
    const inspection = readJson(`${base}/evidence/authoring-package-inspection.json`);
    const outputManifest = readJson(`${base}/evidence/downstream-output-manifest.json`);

    assert(event.eligible === caseExpected.downstreamEligible[treatment], `${caseId}/${treatment}: corrected downstream eligibility changed`);
    assert(boundary.eligible === true, `${caseId}/${treatment}: downstream write boundary changed`);
    assert(event.expectedSkillLoad?.observed === true, `${caseId}/${treatment}: target skill was not observed`);
    assert(event.expectedSkillLoad?.fullContentObserved === true, `${caseId}/${treatment}: full target skill was not observed`);
    assert(event.expectedSkillLoad?.beforeFirstOutputMutation === true, `${caseId}/${treatment}: skill loaded too late`);
    assert(event.observedSkillLoads.length === 1, `${caseId}/${treatment}: unexpected downstream skill load`);
    assert(boundary.reasons.length === 0, `${caseId}/${treatment}: downstream boundary violation`);
    assert(authoringEvent.eligible === caseExpected.authoringEligible[treatment], `${caseId}/${treatment}: corrected authoring eligibility changed`);
    assert(authoringBoundary.eligible === true, `${caseId}/${treatment}: authoring write boundary changed`);
    assert(authoringEvent.reasons.includes(isolationReason), `${caseId}/${treatment}: authoring isolation-evidence reason missing`);
    assert(event.reasons.includes(isolationReason), `${caseId}/${treatment}: downstream isolation-evidence reason missing`);
    if (caseId === "meeting-followups" && treatment === "toolboxmd") {
      assert(authoringEvent.reasons.includes("parent-directory traversal observed"), "meeting/toolboxmd: traversal reason missing");
    }
    assert(manifest.cases[caseId].comparisonEligible === false, `${caseId}: comparison must remain excluded`);
    const pipelineEligible = caseExpected.authoringEligible[treatment] && caseExpected.downstreamEligible[treatment];
    assert(manifest.cases[caseId][treatment].authoringEligible === caseExpected.authoringEligible[treatment], `${caseId}/${treatment}: manifest authoring eligibility changed`);
    assert(manifest.cases[caseId][treatment].downstreamEligible === caseExpected.downstreamEligible[treatment], `${caseId}/${treatment}: manifest downstream eligibility changed`);
    assert(manifest.cases[caseId][treatment].pipelineEligible === pipelineEligible, `${caseId}/${treatment}: pipeline eligibility changed`);
    assert(authoringEvent.expectedSkillLoad?.fullContentObserved === true, `${caseId}/${treatment}: creator package was not fully loaded`);
    assert(grade.criticalPassCount === caseExpected.passes[treatment], `${caseId}/${treatment}: critical score changed`);
    assert(inspection.aggregateSha256 === caseExpected.packageHashes[treatment], `${caseId}/${treatment}: recorded package hash changed`);
    assert(treeManifest(path.join(resultRoot, base, "skill")).aggregateSha256 === caseExpected.packageHashes[treatment], `${caseId}/${treatment}: retained package changed`);
    assert(outputManifest.aggregateSha256 === caseExpected.outputHashes[treatment], `${caseId}/${treatment}: recorded output hash changed`);
    assert(treeManifest(path.join(resultRoot, base, "downstream-output")).aggregateSha256 === caseExpected.outputHashes[treatment], `${caseId}/${treatment}: retained output changed`);

    const validation = fs.readFileSync(path.join(resultRoot, base, "evidence", "authoring-package-validation.txt"), "utf8");
    assert(validation.startsWith("PASS: valid skill package:"), `${caseId}/${treatment}: package validation evidence changed`);
  }
}

for (const treatment of ["builtin", "toolboxmd"]) {
  const event = readJson(`near-miss/${treatment}/event-audit.json`);
  const boundary = readJson(`near-miss/${treatment}/boundary-audit.json`);
  assert(event.eligible === true && boundary.eligible === true, `${treatment}: near-miss run is ineligible`);
  assert(event.observedSkillLoads.length === 0, `${treatment}: near-miss loaded a target skill`);
  assert(event.falsePositiveSkillLoad === false, `${treatment}: near-miss false positive changed`);
}

const usage = readJson("session-usage.json");
const sum = {
  sessions: 0,
  durationSeconds: 0,
  inputTokens: 0,
  cachedInputTokens: 0,
  uncachedInputTokens: 0,
  outputTokens: 0,
  runtimeTokens: 0,
};
for (const group of Object.values(usage.groups)) {
  for (const key of Object.keys(sum)) sum[key] += group[key];
  assert(group.runs.length === group.sessions, "usage group run count changed");
  for (const run of group.runs) assert(/^[a-f0-9]{64}$/.test(run.rawEvents.sha256), `raw-event hash missing: ${run.run}`);
}
assert(JSON.stringify(sum) === JSON.stringify(usage.total), "session usage total is inconsistent");
assert(sum.sessions === 16 && sum.sessions <= 17, "decision-session budget changed");
assert(sum.durationSeconds === 2759, "cumulative duration changed");
assert(sum.runtimeTokens === 728273, "runtime token total changed");
for (const key of Object.keys(sum)) {
  if (key === "sessions") assert(manifest.sessionUsage.decisionSessions === sum[key], "manifest session total changed");
  else if (key === "durationSeconds") assert(manifest.sessionUsage.cumulativeDurationSeconds === sum[key], "manifest duration total changed");
  else assert(manifest.sessionUsage[key] === sum[key], `manifest usage mismatch: ${key}`);
}

const discarded = readJson("discarded-authoring/failure.json");
assert(discarded.attempts.length === 4, "discarded authoring batch changed");
assert(discarded.attempts.filter(attempt => attempt.pycFiles.length === 1).length === 2, "expected two bytecode boundary failures");
assert(discarded.attempts.every(attempt => /^[a-f0-9]{64}$/.test(attempt.rawEvents.sha256)), "discarded raw-event hash missing");

assert(sha256File(path.join(resultRoot, "session-usage.json")) === manifest.retainedEvidence.sessionUsageSha256, "session usage hash changed");
assert(sha256File(path.join(resultRoot, "discarded-authoring/failure.json")) === manifest.retainedEvidence.discardedAuthoringFailureSha256, "discarded evidence hash changed");
assert(sha256File(path.join(resultRoot, "retention-manifest.json")) === manifest.retainedEvidence.retentionManifestSha256, "retention manifest hash changed");

const eventAudits = [];
function findEventAudits(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const absolute = path.join(directory, entry.name);
    if (entry.isDirectory()) findEventAudits(absolute);
    else if (entry.isFile() && entry.name.endsWith("event-audit.json")) eventAudits.push(absolute);
  }
}
findEventAudits(resultRoot);
assert(eventAudits.length === 17, `expected 17 corrected event audits, found ${eventAudits.length}`);
const ineligibleAudits = eventAudits.filter(file => JSON.parse(fs.readFileSync(file, "utf8")).eligible === false);
assert(ineligibleAudits.length === 15, `expected fifteen ineligible corrected event audits, found ${ineligibleAudits.length}`);
assert(JSON.stringify(ineligibleAudits.map(file => path.relative(resultRoot, file).split(path.sep).join("/")).sort()) === JSON.stringify([
  "cases/meeting-followups/builtin/evidence/authoring-event-audit.json",
  "cases/meeting-followups/builtin/evidence/downstream-event-audit.json",
  "cases/meeting-followups/toolboxmd/evidence/authoring-event-audit.json",
  "cases/meeting-followups/toolboxmd/evidence/downstream-event-audit.json",
  "cases/weekly-status-deck/builtin/evidence/authoring-event-audit.json",
  "cases/weekly-status-deck/builtin/evidence/downstream-event-audit.json",
  "cases/weekly-status-deck/toolboxmd/evidence/authoring-event-audit.json",
  "cases/weekly-status-deck/toolboxmd/evidence/downstream-event-audit.json",
  "discarded-authoring/meeting-followups/builtin/event-audit.json",
  "discarded-authoring/meeting-followups/toolboxmd/event-audit.json",
  "discarded-authoring/weekly-status-deck/builtin/event-audit.json",
  "discarded-authoring/weekly-status-deck/toolboxmd/event-audit.json",
  "preflight/event-audit.json",
  "qualification/meeting-followups/evidence/event-audit.json",
  "qualification/weekly-status-deck/evidence/event-audit.json",
]), "unexpected corrected ineligible streams");
assert(manifest.postResultAuditCorrection.retainedStreamsReaudited === 17, "corrected audit stream count changed");
assert(manifest.postResultAuditCorrection.modelSessionsAdded === 0, "audit correction must not add model sessions");
assert(JSON.stringify(manifest.postResultAuditCorrection.ineligibleStreams) === JSON.stringify([
  "cases/meeting-followups/builtin/evidence/authoring-events.jsonl",
  "cases/meeting-followups/builtin/evidence/downstream-events.jsonl",
  "cases/meeting-followups/toolboxmd/evidence/authoring-events.jsonl",
  "cases/meeting-followups/toolboxmd/evidence/downstream-events.jsonl",
  "cases/weekly-status-deck/builtin/evidence/authoring-events.jsonl",
  "cases/weekly-status-deck/builtin/evidence/downstream-events.jsonl",
  "cases/weekly-status-deck/toolboxmd/evidence/authoring-events.jsonl",
  "cases/weekly-status-deck/toolboxmd/evidence/downstream-events.jsonl",
  "discarded-authoring/meeting-followups/builtin/events.jsonl",
  "discarded-authoring/meeting-followups/toolboxmd/events.jsonl",
  "discarded-authoring/weekly-status-deck/builtin/events.jsonl",
  "discarded-authoring/weekly-status-deck/toolboxmd/events.jsonl",
  "preflight/events.jsonl",
  "qualification/meeting-followups/evidence/events.jsonl",
  "qualification/weekly-status-deck/evidence/events.jsonl",
]), "corrected manifest ineligible stream list changed");
assert(manifest.postResultAuditCorrection.ineligibleStreamCount === 15, "corrected manifest ineligible stream count changed");
assert(manifest.postResultAuditCorrection.ineligibleScoredStreams === 8, "corrected manifest scored-stream count changed");
assert(manifest.postResultAuditCorrection.ineligibleScoredPipelines === 4, "corrected manifest scored-pipeline count changed");
assert(manifest.postResultAuditCorrection.ineligibleDiscardedStreams === 4, "corrected manifest discarded-stream count changed");
assert(manifest.postResultAuditCorrection.ineligibleQualificationStreams === 2, "corrected manifest qualification-stream count changed");
assert(manifest.postResultAuditCorrection.ineligiblePreflightStreams === 1, "corrected manifest preflight-stream count changed");

const retained = readJson("retention-manifest.json");
const aggregateLines = [];
for (const expectedFile of retained.files) {
  const absolute = path.join(resultRoot, expectedFile.path);
  assert(absolute.startsWith(resultRoot + path.sep), `retained path escapes result root: ${expectedFile.path}`);
  assert(fs.existsSync(absolute), `retained file missing: ${expectedFile.path}`);
  assert(fs.statSync(absolute).size === expectedFile.bytes, `retained file size changed: ${expectedFile.path}`);
  assert(sha256File(absolute) === expectedFile.sha256, `retained file hash changed: ${expectedFile.path}`);
  aggregateLines.push(`${expectedFile.sha256}  ${expectedFile.path}\n`);
}
assert(crypto.createHash("sha256").update(aggregateLines.join("")).digest("hex") === retained.aggregateSha256, "retention aggregate changed");

for (const [relative, expectedHash] of Object.entries(manifest.harnessAtResult)) {
  if (relative === "scripts/audit-toolboxmd-v2-events.mjs") continue;
  assert(sha256File(path.join(repositoryRoot, relative)) === expectedHash, `at-result harness hash changed: ${relative}`);
}
assert(sha256File(path.join(repositoryRoot, "scripts/audit-toolboxmd-v2-events.mjs")) === manifest.postResultAuditCorrection.auditorSha256, "corrected auditor hash changed");
NODE

echo "PASS: ToolboxMD creator benchmark v2 result is internally consistent"
