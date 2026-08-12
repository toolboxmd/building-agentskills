#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

function fail(message) {
  console.error(`FAIL: ${message}`);
  process.exit(2);
}

if (process.argv.length !== 5) {
  fail("usage: validate-blind-judgment.mjs <judgment.json> <review-root> <comma-separated-case-ids>");
}

const judgmentPath = path.resolve(process.argv[2]);
const reviewRoot = path.resolve(process.argv[3]);
const expectedCaseIds = process.argv[4].split(",").filter(Boolean);
const rawJudgment = fs.readFileSync(judgmentPath, "utf8");
const judgment = JSON.parse(rawJudgment);
const reasons = [];
const derivedCases = [];
const dimensionKeys = [
  "primitiveInvocation",
  "sourceFidelity",
  "workflowMechanism",
  "progressiveDisclosure",
  "downstreamUtility",
];

function assert(condition, message) {
  if (!condition) reasons.push(message);
}

assert(judgment.schemaVersion === 1, "schemaVersion must be 1");
assert(Array.isArray(judgment.cases), "cases must be an array");
if (/toolboxmd|skill-creator|\bbuiltin\b|\bbaseline\b|\bcandidate\b/i.test(rawJudgment)) {
  reasons.push("judgment contains treatment identity language");
}

const observedCaseIds = Array.isArray(judgment.cases) ? judgment.cases.map(item => item.caseId) : [];
assert(
  JSON.stringify([...observedCaseIds].sort()) === JSON.stringify([...expectedCaseIds].sort()),
  `expected exactly these cases: ${expectedCaseIds.join(", ")}`,
);

for (const item of judgment.cases ?? []) {
  const prefix = item.caseId ?? "unknown-case";
  assert(new Set(["A", "B", "tie"]).has(item.verdict), `${prefix}: invalid verdict`);
  assert(new Set(["high", "medium", "low"]).has(item.confidence), `${prefix}: invalid confidence`);
  assert(item.scores && typeof item.scores === "object", `${prefix}: missing scores`);
  assert(item.criticalFailures && typeof item.criticalFailures === "object", `${prefix}: missing criticalFailures`);

  const totals = {};
  for (const arm of ["A", "B"]) {
    const scores = item.scores?.[arm] ?? {};
    assert(JSON.stringify(Object.keys(scores)) === JSON.stringify(dimensionKeys), `${prefix}/${arm}: score keys differ from frozen schema`);
    let total = 0;
    for (const key of dimensionKeys) {
      const score = scores[key];
      assert(Number.isInteger(score) && score >= 0 && score <= 4, `${prefix}/${arm}/${key}: score must be an integer from 0 to 4`);
      if (Number.isInteger(score)) total += score;
    }
    totals[arm] = total;
    assert(Array.isArray(item.criticalFailures?.[arm]), `${prefix}/${arm}: critical failures must be an array`);
  }

  assert(Array.isArray(item.observations) && item.observations.length >= 2, `${prefix}: at least two observations are required`);
  for (const [index, observation] of (item.observations ?? []).entries()) {
    assert(typeof observation.path === "string" && observation.path.length > 0, `${prefix}: observation ${index + 1} has no path`);
    assert(typeof observation.observation === "string" && observation.observation.length > 0, `${prefix}: observation ${index + 1} has no text`);
    if (typeof observation.path === "string") {
      const withoutLine = observation.path.replace(/:[0-9]+$/, "");
      const absolute = path.resolve(reviewRoot, withoutLine);
      const inside = absolute === reviewRoot || absolute.startsWith(`${reviewRoot}${path.sep}`);
      assert(inside && fs.existsSync(absolute), `${prefix}: observation path does not exist: ${observation.path}`);
    }
  }

  if (item.verdict === "A" || item.verdict === "B") {
    const winner = item.verdict;
    const loser = winner === "A" ? "B" : "A";
    assert(!item.criticalFailures?.[winner]?.length, `${prefix}: winning arm has a critical failure`);
    assert(totals[winner] - totals[loser] >= 2, `${prefix}: winning score advantage is less than two points`);
    assert(item.confidence === "medium" || item.confidence === "high", `${prefix}: win confidence must be medium or high`);
    assert(
      item.scores?.[winner]?.downstreamUtility > item.scores?.[loser]?.downstreamUtility,
      `${prefix}: win has no scored downstream-utility advantage`,
    );
  }

  assert(typeof item.explanation === "string" && item.explanation.length > 0, `${prefix}: explanation is required`);
  derivedCases.push({ caseId: item.caseId, verdict: item.verdict, confidence: item.confidence, totals });
}

const uniqueReasons = [...new Set(reasons)];
const result = {
  schemaVersion: 1,
  valid: uniqueReasons.length === 0,
  expectedCaseIds,
  derivedCases,
  reasons: uniqueReasons,
};
process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
if (!result.valid) process.exit(1);
