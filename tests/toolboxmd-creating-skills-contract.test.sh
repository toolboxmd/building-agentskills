#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bench="$root/benchmarks/toolboxmd-creating-skills/v1"

required=(
  "$bench/README.md"
  "$bench/rubric.md"
  "$bench/run-config.json"
  "$bench/commitments.json"
  "$bench/baselines/codex-skill-creator-0.147.0/manifest.json"
  "$bench/baselines/codex-skill-creator-0.147.0/package/SKILL.md"
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

expected_cases=(csv-sanitizer.md release-evidence.md webhook-triage.md)
if [[ "${case_names[*]}" != "${expected_cases[*]}" ]]; then
  echo "FAIL: expected exactly ${expected_cases[*]}, found ${case_names[*]:-none}" >&2
  exit 1
fi

required_headings=(
  "## Archetype"
  "## Required skill name"
  "## Visible source material"
  "## Hidden downstream challenge"
  "## Required authored output"
  "## Required downstream output"
  "## Critical failures"
  "## Semantic dimensions"
  "## Generator may vary"
  "## Generator must preserve"
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

node - "$bench/run-config.json" "$bench/commitments.json" "$bench/baselines/codex-skill-creator-0.147.0/manifest.json" "$bench/sealed-cases-manifest.json" "$bench" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const [configPath, commitmentsPath, baselinePath, sealedManifestPath, benchmarkRoot] = process.argv.slice(2);
const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
const commitments = JSON.parse(fs.readFileSync(commitmentsPath, "utf8"));
const baseline = JSON.parse(fs.readFileSync(baselinePath, "utf8"));
const sealed = JSON.parse(fs.readFileSync(sealedManifestPath, "utf8"));

function assert(condition, message) {
  if (!condition) {
    console.error(`FAIL: ${message}`);
    process.exit(1);
  }
}

assert(config.schemaVersion === 1, "run-config schemaVersion must be 1");
assert(config.benchmarkId === "toolboxmd-creating-skills-v1", "unexpected benchmarkId");
assert(JSON.stringify(config.cases) === JSON.stringify(["webhook-triage", "csv-sanitizer", "release-evidence"]), "run-config must freeze three ordered cases");
assert(config.baseline.packageManifestSha256 === "473b9dd5ff3df1d352b499d83e00864290bd2874ac3f9243e33f09ab7e9e835c", "baseline aggregate hash changed");
assert(config.baseline.skillMdSha256 === "da44c88f6b3845a8fa8c60792ec9a722110a55a9793c279757b48fefb11f819c", "baseline SKILL.md hash changed");
assert(config.harness.codexCliVersion === "0.147.0", "Codex CLI version is not frozen");
assert(config.harness.model === "gpt-5.6-sol", "model is not frozen");
assert(config.harness.modelReasoningEffort === "medium", "reasoning effort is not frozen");
assert(config.harness.sandbox === "workspace-write", "sandbox is not frozen");
assert(config.harness.networkAccess === false, "network must be disabled");
assert(config.harness.noNestedDelegation === true, "nested delegation must be forbidden");
assert(config.runBudget.authoring === 6 && config.runBudget.downstream === 6 && config.runBudget.blindJudge === 1, "initial run budget must be 6 + 6 + 1");
assert(config.runBudget.maxAmbiguousCaseReplays === 1, "only one ambiguous-case replay is allowed");

assert(commitments.schemaVersion === 1, "commitments schemaVersion must be 1");
assert(/^[a-f0-9]{64}$/.test(commitments.publicContract.treeSha256), "public contract tree hash missing");
assert(commitments.candidate === null || /^[a-f0-9]{64}$/.test(commitments.candidate.aggregateSha256), "candidate commitment is malformed");
assert(commitments.sealedCases?.aggregateSha256 === sealed.aggregateSha256, "sealed case commitment and manifest differ");
assert(commitments.sealedCases?.generatedAfterCandidateSha256 === commitments.candidate?.aggregateSha256, "sealed cases must be generated after the frozen candidate");
assert(sealed.publicContractTreeSha256 === commitments.publicContract.treeSha256, "sealed cases were not generated from the frozen public contract");
assert(Array.isArray(sealed.files) && sealed.files.length === 24, "sealed case manifest must list all 24 files");
assert(sealed.files.every(file => /^[a-f0-9]{64}$/.test(file.sha256) && Number.isInteger(file.bytes)), "sealed case entries need hash and size");

const publicLines = [...commitments.publicContract.files]
  .sort((a, b) => a.path < b.path ? -1 : a.path > b.path ? 1 : 0)
  .map(file => {
    const contents = fs.readFileSync(path.join(benchmarkRoot, file.path));
    const actual = crypto.createHash("sha256").update(contents).digest("hex");
    assert(actual === file.sha256, `public contract hash changed: ${file.path}`);
    return `${actual}  ${file.path}\n`;
  })
  .join("");
const publicTree = crypto.createHash("sha256").update(publicLines).digest("hex");
assert(publicTree === commitments.publicContract.treeSha256, "public contract tree hash changed");

assert(baseline.aggregateSha256 === config.baseline.packageManifestSha256, "baseline manifest and run-config hashes differ");
assert(Array.isArray(baseline.files) && baseline.files.length >= 8, "baseline per-file manifest is incomplete");
assert(baseline.files.every(file => /^[a-f0-9]{64}$/.test(file.sha256) && Number.isInteger(file.bytes)), "baseline file entries need hash and size");
const baselineLines = [...baseline.files]
  .sort((a, b) => a.path < b.path ? -1 : a.path > b.path ? 1 : 0)
  .map(file => {
    const contents = fs.readFileSync(path.join(path.dirname(baselinePath), "package", file.path));
    const actual = crypto.createHash("sha256").update(contents).digest("hex");
    assert(actual === file.sha256, `baseline hash changed: ${file.path}`);
    assert(contents.length === file.bytes, `baseline size changed: ${file.path}`);
    return `${actual}  ./${file.path}\n`;
  })
  .join("");
const baselineTree = crypto.createHash("sha256").update(baselineLines).digest("hex");
assert(baselineTree === baseline.aggregateSha256, "baseline aggregate hash changed");
NODE

echo "PASS: ToolboxMD creator benchmark contract is frozen"
