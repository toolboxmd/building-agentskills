#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

function fail(message) {
  console.error(`FAIL: ${message}`);
  process.exit(2);
}

if (process.argv.length !== 10) {
  fail("usage: prepare-toolboxmd-blind-review.mjs <sealed-root> <authoring-runs> <downstream-runs> <rubric.md> <review-root> <preparation-report.json> <identity-map.json> <seed>");
}

const [
  rawSealedRoot,
  rawAuthoringRuns,
  rawDownstreamRuns,
  rawRubric,
  rawReviewRoot,
  rawPreparationReport,
  rawIdentityMap,
  seed,
] = process.argv.slice(2);

const sealedRoot = path.resolve(rawSealedRoot);
const authoringRuns = path.resolve(rawAuthoringRuns);
const downstreamRuns = path.resolve(rawDownstreamRuns);
const rubricPath = path.resolve(rawRubric);
const reviewRoot = path.resolve(rawReviewRoot);
const preparationReportPath = path.resolve(rawPreparationReport);
const identityMapPath = path.resolve(rawIdentityMap);
const benchmarkId = "toolboxmd-creating-skills-v1";
const caseIds = ["webhook-triage", "csv-sanitizer", "release-evidence"];

for (const required of [sealedRoot, authoringRuns, downstreamRuns]) {
  if (!fs.existsSync(required) || !fs.statSync(required).isDirectory()) fail(`directory not found: ${required}`);
}
if (!fs.existsSync(rubricPath) || !fs.statSync(rubricPath).isFile()) fail(`rubric not found: ${rubricPath}`);
for (const destination of [reviewRoot, preparationReportPath, identityMapPath]) {
  if (fs.existsSync(destination)) fail(`destination already exists: ${destination}`);
}

function listFiles(root) {
  const files = [];
  function walk(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const absolute = path.join(directory, entry.name);
      if (entry.isSymbolicLink()) fail(`symbolic link is not allowed in frozen artifact: ${absolute}`);
      if (entry.isDirectory()) walk(absolute);
      else if (entry.isFile()) files.push(absolute);
      else fail(`unsupported filesystem entry: ${absolute}`);
    }
  }
  walk(root);
  return files.sort();
}

function treeManifest(root) {
  const files = listFiles(root).map(absolute => {
    const contents = fs.readFileSync(absolute);
    return {
      path: path.relative(root, absolute).split(path.sep).join("/"),
      bytes: contents.length,
      sha256: crypto.createHash("sha256").update(contents).digest("hex"),
    };
  });
  const lines = files.map(file => `${file.sha256}  ${file.path}\n`).join("");
  return {
    aggregateSha256: crypto.createHash("sha256").update(lines).digest("hex"),
    files,
  };
}

function copyTree(source, destination) {
  fs.cpSync(source, destination, {
    recursive: true,
    dereference: false,
    errorOnExist: true,
    force: false,
    verbatimSymlinks: true,
  });
  const sourceManifest = treeManifest(source);
  const copiedManifest = treeManifest(destination);
  if (sourceManifest.aggregateSha256 !== copiedManifest.aggregateSha256) {
    fail(`copy changed frozen bytes: ${source} -> ${destination}`);
  }
  return sourceManifest.aggregateSha256;
}

const identityMarkers = [
  { id: "toolboxmd-name", needle: "toolboxmd" },
  { id: "creator-package-name", needle: "skill-creator" },
  { id: "workspace-user-path", needle: "/users/lukaszmaj/" },
  { id: "benchmark-work-path", needle: ".benchmark-work/" },
  { id: "builtin-treatment-path", needle: "/builtin/" },
];

function scanIdentity(root) {
  const findings = [];
  for (const absolute of listFiles(root)) {
    const haystack = fs.readFileSync(absolute).toString("latin1").toLocaleLowerCase("en-US");
    for (const marker of identityMarkers) {
      if (haystack.includes(marker.needle)) {
        findings.push({
          path: path.relative(root, absolute).split(path.sep).join("/"),
          marker: marker.id,
        });
      }
    }
  }
  return findings;
}

const rankedCases = caseIds
  .map(caseId => ({
    caseId,
    rankHash: crypto.createHash("sha256").update(`${benchmarkId}:${caseId}:${seed}`).digest("hex"),
  }))
  .sort((left, right) => left.rankHash.localeCompare(right.rankHash));

const mapping = {};
for (let index = 0; index < rankedCases.length; index += 1) {
  const candidateIsA = index % 2 === 0;
  mapping[rankedCases[index].caseId] = candidateIsA
    ? { A: "toolboxmd", B: "builtin" }
    : { A: "builtin", B: "toolboxmd" };
}

const cases = [];
for (const caseId of caseIds) {
  const contract = JSON.parse(fs.readFileSync(path.join(sealedRoot, caseId, "deterministic-contract.json"), "utf8"));
  const armSources = {};
  const findings = [];
  for (const treatment of ["builtin", "toolboxmd"]) {
    const packageRoot = path.join(authoringRuns, caseId, treatment, "root", "output", contract.requiredSkillName);
    const downstreamRoot = path.join(downstreamRuns, caseId, treatment, "root", "downstream-output");
    armSources[treatment] = { packageRoot, downstreamRoot };
    for (const [artifact, artifactRoot] of [["skill", packageRoot], ["downstream-output", downstreamRoot]]) {
      for (const finding of scanIdentity(artifactRoot)) {
        findings.push({ treatment, artifact, ...finding });
      }
    }
  }

  const eligible = findings.length === 0;
  const caseRecord = {
    caseId,
    eligible,
    findings,
    reviewHashes: {},
  };
  if (eligible) {
    const caseReviewRoot = path.join(reviewRoot, "cases", caseId);
    copyTree(path.join(sealedRoot, caseId), path.join(caseReviewRoot, "case-material"));
    for (const arm of ["A", "B"]) {
      const treatment = mapping[caseId][arm];
      caseRecord.reviewHashes[arm] = {
        skill: copyTree(armSources[treatment].packageRoot, path.join(caseReviewRoot, arm, "skill")),
        downstreamOutput: copyTree(armSources[treatment].downstreamRoot, path.join(caseReviewRoot, arm, "downstream-output")),
      };
    }
  }
  cases.push(caseRecord);
}

fs.mkdirSync(reviewRoot, { recursive: true });
fs.copyFileSync(rubricPath, path.join(reviewRoot, "rubric.md"));
const eligibleCaseIds = cases.filter(item => item.eligible).map(item => item.caseId);
const task = `# Blind semantic review

Read \`rubric.md\` completely, then review only these eligible cases: ${eligibleCaseIds.map(caseId => `\`${caseId}\``).join(", ")}.

For each case, read all files under \`cases/<case-id>/case-material/\`, both frozen packages under \`A/skill/\` and \`B/skill/\`, and both frozen results under \`A/downstream-output/\` and \`B/downstream-output/\`. Do not edit them.

Do not infer, search for, or state creator identity. The parent labels A and B are the only arm names available to you. Do not read parent directories, user memory, prior output, or any file outside this review root. Do not use network access, subagents, another model, or an agentic CLI.

Write \`review-output/judgment.json\` with this structure:

\`\`\`json
{
  "schemaVersion": 1,
  "cases": [
    {
      "caseId": "case-id",
      "verdict": "A | B | tie",
      "confidence": "high | medium | low",
      "scores": {
        "A": {
          "primitiveInvocation": 0,
          "sourceFidelity": 0,
          "workflowMechanism": 0,
          "progressiveDisclosure": 0,
          "downstreamUtility": 0
        },
        "B": {
          "primitiveInvocation": 0,
          "sourceFidelity": 0,
          "workflowMechanism": 0,
          "progressiveDisclosure": 0,
          "downstreamUtility": 0
        }
      },
      "criticalFailures": { "A": [], "B": [] },
      "observations": [
        { "path": "cases/case-id/A/or/B/...", "observation": "concrete fact" },
        { "path": "cases/case-id/A/or/B/...", "observation": "concrete fact" }
      ],
      "explanation": "short downstream-centered explanation"
    }
  ],
  "overallNotes": "optional short note"
}
\`\`\`

Use integer scores from 0 to 4 for every rubric dimension. Apply the rubric's critical gate and verdict rule exactly. Include every eligible case once and no ineligible case. Cite at least two existing relative paths per case. Also write a concise human-readable rendering to \`review-output/judgment.md\`. Write nothing outside \`review-output/\`.
`;
fs.writeFileSync(path.join(reviewRoot, "task.md"), task);

fs.mkdirSync(path.dirname(preparationReportPath), { recursive: true });
fs.writeFileSync(preparationReportPath, `${JSON.stringify({
  schemaVersion: 1,
  benchmarkId,
  seed,
  mappingAlgorithm: "Sort SHA-256(benchmarkId:caseId:seed), then alternate candidate in A by zero-based rank",
  eligibleCaseIds,
  cases,
}, null, 2)}\n`);
fs.mkdirSync(path.dirname(identityMapPath), { recursive: true });
fs.writeFileSync(identityMapPath, `${JSON.stringify({
  schemaVersion: 1,
  benchmarkId,
  revealed: false,
  mappingAlgorithm: "Sort SHA-256(benchmarkId:caseId:seed), then alternate candidate in A by zero-based rank",
  rankedCases,
  mapping,
}, null, 2)}\n`);

process.stdout.write(`${JSON.stringify({ eligibleCaseIds, ineligibleCaseIds: cases.filter(item => !item.eligible).map(item => item.caseId) })}\n`);
