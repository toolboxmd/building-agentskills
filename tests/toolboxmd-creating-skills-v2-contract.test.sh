#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bench="$root/benchmarks/toolboxmd-creating-skills/v2"

required=(
  "$root/docs/superpowers/specs/2026-08-13-toolboxmd-creating-skills-benchmark-v2-design.md"
  "$root/docs/superpowers/plans/2026-08-13-toolboxmd-creating-skills-benchmark-v2-implementation.md"
  "$bench/README.md"
  "$bench/rubric.md"
  "$bench/run-config.json"
  "$bench/commitments.json"
  "$bench/treatment-hash-provenance.json"
  "$bench/cases-manifest.json"
)

for path in "${required[@]}"; do
  if [[ ! -f "$path" ]]; then
    echo "FAIL: missing ${path#"$root/"}" >&2
    exit 1
  fi
done

case_names=()
while IFS= read -r case_path; do
  case_names+=("$(basename "$case_path")")
done < <(find "$bench/case-contracts" -maxdepth 1 -type f -name '*.md' -print | LC_ALL=C sort)

expected_cases=(meeting-followups.md personal-expense-rollup.md weekly-status-deck.md)
if [[ "${case_names[*]}" != "${expected_cases[*]}" ]]; then
  echo "FAIL: expected exactly ${expected_cases[*]}, found ${case_names[*]:-none}" >&2
  exit 1
fi

required_headings=(
  "## Daily job"
  "## Target skill"
  "## Why a skill should help"
  "## No-skill qualification"
  "## Positive trigger"
  "## Near miss"
  "## Authoring material"
  "## Held-out downstream task"
  "## Critical assertions"
  "## Cost and trace evidence"
)

for case_name in "${expected_cases[@]}"; do
  case_path="$bench/case-contracts/$case_name"
  for heading in "${required_headings[@]}"; do
    if ! grep -Fxq "$heading" "$case_path"; then
      echo "FAIL: $case_name missing heading: $heading" >&2
      exit 1
    fi
  done
done

node - "$root" "$bench" <<'NODE'
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const [repositoryRoot, benchmarkRoot] = process.argv.slice(2);
const config = JSON.parse(fs.readFileSync(path.join(benchmarkRoot, "run-config.json"), "utf8"));
const commitmentsPath = path.join(benchmarkRoot, "commitments.json");
const commitmentsBytes = fs.readFileSync(commitmentsPath);
const commitments = JSON.parse(commitmentsBytes);
const hashProvenance = JSON.parse(fs.readFileSync(path.join(benchmarkRoot, "treatment-hash-provenance.json"), "utf8"));
const casesManifest = JSON.parse(fs.readFileSync(path.join(benchmarkRoot, "cases-manifest.json"), "utf8"));

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

function resolveJsonPointer(document, pointer) {
  if (pointer === "") return document;
  assert(pointer.startsWith("/"), `invalid JSON pointer: ${pointer}`);
  return pointer.slice(1).split("/").reduce((value, token) => {
    const key = token.replace(/~1/g, "/").replace(/~0/g, "~");
    assert(value !== null && typeof value === "object" && Object.hasOwn(value, key), `missing JSON pointer token: ${pointer}`);
    return value[key];
  }, document);
}

function treatmentTreeManifest(root, declaration) {
  const algorithm = declaration.aggregateAlgorithm;
  assert(algorithm.fileDigest === "sha256", `${declaration.source}: unsupported file digest`);
  assert(algorithm.aggregateDigest === "sha256", `${declaration.source}: unsupported aggregate digest`);
  assert(algorithm.relativePathStyle === "posix", `${declaration.source}: unsupported path style`);
  assert(algorithm.pathEncoding === "utf8", `${declaration.source}: unsupported path encoding`);
  assert(["", "./"].includes(algorithm.pathPrefix), `${declaration.source}: unsupported path prefix`);
  assert(algorithm.sort === "bytewise_utf8_emitted_path_ascending", `${declaration.source}: unsupported sort`);
  assert(algorithm.entryFormat === "<file-sha256>  <emitted-path>\n", `${declaration.source}: unsupported entry format`);

  const files = treeManifest(root).files.map(file => ({
    ...file,
    emittedPath: `${algorithm.pathPrefix}${file.path}`,
  }));
  files.sort((left, right) => Buffer.compare(Buffer.from(left.emittedPath, "utf8"), Buffer.from(right.emittedPath, "utf8")));
  const manifestBytes = files.map(file => `${file.sha256}  ${file.emittedPath}\n`).join("");
  return {
    aggregateSha256: crypto.createHash("sha256").update(manifestBytes).digest("hex"),
    files,
  };
}

assert(config.schemaVersion === 2, "run-config schemaVersion must be 2");
assert(config.benchmarkId === "toolboxmd-creating-skills-v2", "unexpected benchmarkId");
assert(config.protocolRevision === 2, "protocol revision must record the pre-run bytecode correction");
assert(JSON.stringify(config.caseRoles.primary) === JSON.stringify(["meeting-followups", "weekly-status-deck"]), "two primary cases are not frozen");
assert(JSON.stringify(config.caseRoles.reserve) === JSON.stringify(["personal-expense-rollup"]), "reserve case is not frozen");
assert(config.harness.codexCliVersion === "0.147.0", "Codex CLI version is not frozen");
assert(config.harness.model === "gpt-5.6-sol", "model is not frozen");
assert(config.harness.modelReasoningEffort === "medium", "reasoning effort is not frozen");
assert(config.harness.sameModelAcrossTreatments === true, "treatments must use the same model");
assert(config.harness.implicitPositivePrompt === true, "positive downstream prompts must be implicit");
assert(config.harness.otherSkillsEnabled === false, "other skills must be disabled");
assert(config.harness.networkAccess === false, "network must be disabled");
assert(config.harness.noNestedDelegation === true, "nested delegation must be forbidden");
assert(config.harness.runnerPath === "scripts/run-isolated-codex-v2.sh", "v2 runner path is not frozen");
assert(config.harness.pythonBytecodeIsolation === true && config.harness.pythonBytecodeWritesDisabled === true, "Python bytecode boundary is not frozen");
assert(config.runBudget.cleanPathSessions === 12, "clean path must use 12 sessions");
assert(config.runBudget.hardMaximumSessions === 17, "hard maximum must be 17 sessions");
assert(config.runBudget.reserveOnlyWhenDecisionIsMixed === true, "reserve case must be conditional");
assert(config.runBudget.repeatsOnlyWhenDecisionChanging === true, "repeats must be decision-changing");
assert(config.controls.noSkillQualification === true, "no-skill qualification is required");
assert(config.controls.sameOrdinaryWorkspaceAcrossArms === true, "ordinary downstream workspace must be identical");
assert(config.controls.traceProvesSkillLoad === true, "skill load must be proved by trace");
assert(config.controls.agentSelfReportIsEvidence === false, "agent self-report cannot prove triggering");
assert(config.controls.blindReviewRequired === false, "blind review must not be a core gate");
assert(config.decision.toolboxmdPrimaryWinsRequired === 2, "ToolboxMD must sweep both primary cases");
assert(config.decision.criticalRegressionsAllowed === 0, "critical regressions must be forbidden");
assert(config.decision.equalUtilityHigherRuntimeCostLoses === true, "runtime cost tie-break is not frozen");

assert(config.treatments.builtin.aggregateSha256 === "473b9dd5ff3df1d352b499d83e00864290bd2874ac3f9243e33f09ab7e9e835c", "built-in snapshot changed");
assert(config.treatments.toolboxmd.aggregateSha256 === "b06582ca95a430f5d0ae5a046019f8f7495db7bc0837dc035ea84acd1583c8d7", "ToolboxMD snapshot changed");

assert(hashProvenance.schemaVersion === 1, "treatment hash provenance schemaVersion must be 1");
assert(hashProvenance.benchmarkId === commitments.benchmarkId, "treatment hash provenance benchmarkId changed");
assert(hashProvenance.status === "post_freeze_hash_provenance_correction", "treatment hash provenance status changed");
assert(hashProvenance.correction.frozenCommitmentsPath === "commitments.json", "frozen commitments path changed");
const commitmentsSha256 = crypto.createHash("sha256").update(commitmentsBytes).digest("hex");
assert(hashProvenance.correction.frozenCommitmentsSha256 === commitmentsSha256, "frozen commitments bytes changed");

assert(JSON.stringify(Object.keys(hashProvenance.treatments).sort()) === JSON.stringify(Object.keys(config.treatments).sort()), "hash provenance treatment set changed");
for (const [treatmentId, treatment] of Object.entries(config.treatments)) {
  const declaration = hashProvenance.treatments[treatmentId];
  assert(declaration.source === treatment.path, `${treatmentId}: provenance source differs from run-config`);
  assert(declaration.source === commitments.treatments[treatmentId].source, `${treatmentId}: provenance source differs from commitments`);
  assert(declaration.aggregateSha256 === treatment.aggregateSha256, `${treatmentId}: provenance hash differs from run-config`);
  assert(declaration.aggregateSha256 === commitments.treatments[treatmentId].aggregateSha256, `${treatmentId}: provenance hash differs from commitments`);

  const treatmentRoot = path.resolve(benchmarkRoot, declaration.source);
  assert(treatmentRoot.startsWith(repositoryRoot + path.sep), `treatment escapes repository: ${declaration.source}`);
  assert(fs.existsSync(path.join(treatmentRoot, "SKILL.md")), `missing treatment SKILL.md: ${declaration.source}`);
  const actualTree = treatmentTreeManifest(treatmentRoot, declaration);
  assert(actualTree.files.length === declaration.fileCount, `${treatmentId}: declared file count changed`);
  assert(actualTree.aggregateSha256 === declaration.aggregateSha256, `${treatmentId}: package bytes do not reproduce declared aggregate`);

  const sourceManifestPath = path.resolve(benchmarkRoot, declaration.provenance.manifest);
  assert(sourceManifestPath.startsWith(repositoryRoot + path.sep), `${treatmentId}: provenance manifest escapes repository`);
  const sourceManifestBytes = fs.readFileSync(sourceManifestPath);
  const sourceManifestSha256 = crypto.createHash("sha256").update(sourceManifestBytes).digest("hex");
  assert(sourceManifestSha256 === declaration.provenance.manifestSha256, `${treatmentId}: provenance manifest hash changed`);
  const sourceManifest = resolveJsonPointer(JSON.parse(sourceManifestBytes), declaration.provenance.jsonPointer);
  assert(sourceManifest.aggregateSha256 === declaration.aggregateSha256, `${treatmentId}: source manifest aggregate differs`);
  assert(Array.isArray(sourceManifest.files) && sourceManifest.files.length === actualTree.files.length, `${treatmentId}: source per-file manifest is incomplete`);
  for (const actual of actualTree.files) {
    const expected = sourceManifest.files.find(file => file.path === actual.path);
    assert(expected?.sha256 === actual.sha256 && expected?.bytes === actual.bytes, `${treatmentId}: source manifest differs for ${actual.path}`);
  }
}

const expectedCaseIds = ["meeting-followups", "personal-expense-rollup", "weekly-status-deck"];
for (const caseId of expectedCaseIds) {
  const caseRoot = path.join(benchmarkRoot, "cases", caseId);
  for (const relative of ["authoring-prompt.md", "downstream-prompt.md", "near-miss-prompt.md", "contract.json"]) {
    assert(fs.existsSync(path.join(caseRoot, relative)), `${caseId}: missing ${relative}`);
  }
  const contract = JSON.parse(fs.readFileSync(path.join(caseRoot, "contract.json"), "utf8"));
  assert(contract.schemaVersion === 2 && contract.caseId === caseId, `${caseId}: malformed contract`);
  assert(contract.targetSkillName === config.targetSkills[caseId], `${caseId}: target skill name differs from run-config`);
  assert(Array.isArray(contract.criticalCheckIds) && contract.criticalCheckIds.length > 0, `${caseId}: no critical assertions`);

  const positivePrompt = fs.readFileSync(path.join(caseRoot, "downstream-prompt.md"), "utf8");
  const nearMissPrompt = fs.readFileSync(path.join(caseRoot, "near-miss-prompt.md"), "utf8");
  for (const [label, prompt] of [["positive", positivePrompt], ["near-miss", nearMissPrompt]]) {
    assert(!/\.agents\/skills|SKILL\.md/i.test(prompt), `${caseId}: ${label} prompt leaks a skill path`);
    assert(!new RegExp(`\\b${contract.targetSkillName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\b`, "i").test(prompt), `${caseId}: ${label} prompt names the target skill`);
    assert(!/\b(?:use|invoke|load|read|open)\s+(?:the\s+|a\s+)?skill\b/i.test(prompt), `${caseId}: ${label} prompt explicitly requests skill use`);
  }

  const authoringKnowledge = path.join(caseRoot, "authoring-sources", "knowledge");
  const downstreamKnowledge = path.join(caseRoot, "downstream-workspace", "knowledge");
  assert(treeManifest(authoringKnowledge).aggregateSha256 === treeManifest(downstreamKnowledge).aggregateSha256, `${caseId}: ordinary knowledge differs between authoring and downstream controls`);
}

const actualCases = treeManifest(path.join(benchmarkRoot, "cases"));
assert(casesManifest.schemaVersion === 2, "cases manifest schemaVersion must be 2");
assert(casesManifest.aggregateSha256 === actualCases.aggregateSha256, "case fixtures changed after freeze");
assert(JSON.stringify(casesManifest.files) === JSON.stringify(actualCases.files), "case fixture manifest entries changed");

assert(commitments.schemaVersion === 2, "commitments schemaVersion must be 2");
assert(commitments.cases.aggregateSha256 === casesManifest.aggregateSha256, "commitments and case manifest differ");
assert(commitments.treatments.builtin.aggregateSha256 === config.treatments.builtin.aggregateSha256, "built-in commitment differs");
assert(commitments.treatments.toolboxmd.aggregateSha256 === config.treatments.toolboxmd.aggregateSha256, "ToolboxMD commitment differs");
assert(/^[a-f0-9]{64}$/.test(commitments.protocol.aggregateSha256), "protocol commitment is missing");
const protocolLines = [...commitments.protocol.files]
  .sort((left, right) => Buffer.compare(Buffer.from(left.path), Buffer.from(right.path)))
  .map(expected => {
    const contents = fs.readFileSync(path.join(repositoryRoot, expected.path));
    assert(contents.length === expected.bytes, `protocol size changed: ${expected.path}`);
    const sha256 = crypto.createHash("sha256").update(contents).digest("hex");
    assert(sha256 === expected.sha256, `protocol file changed: ${expected.path}`);
    return `${sha256}  ${expected.path}\n`;
  })
  .join("");
assert(crypto.createHash("sha256").update(protocolLines).digest("hex") === commitments.protocol.aggregateSha256, "protocol aggregate commitment changed");
NODE

echo "PASS: ToolboxMD creator benchmark v2 contract is frozen"
