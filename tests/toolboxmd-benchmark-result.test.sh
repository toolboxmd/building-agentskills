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

if [[ -e "$root/skills/toolboxmd-creating-skills" ]]; then
  echo "FAIL: failed candidate must not remain in the active skills directory" >&2
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

assert(manifest.schemaVersion === 1, "result manifest schemaVersion must be 1");
assert(manifest.decision.status === "fail", "benchmark decision must remain fail");
assert(manifest.decision.candidateRecommended === false, "failed candidate must not be recommended");
assert(manifest.acceptance.passed === false, "acceptance must remain false");
assert(manifest.acceptance.candidateBlindWins === 0, "candidate blind wins changed");
assert(manifest.acceptance.requiredBlindWins === 2, "required blind wins changed");
assert(manifest.acceptance.candidateCriticalMechanicalPasses === 3, "candidate mechanical pass count changed");

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

for (const caseId of ["webhook-triage", "csv-sanitizer", "release-evidence"]) {
  for (const treatment of ["builtin", "toolboxmd"]) {
    const grade = JSON.parse(fs.readFileSync(path.join(resultRoot, "cases", caseId, treatment, "evidence", "downstream-deterministic-grade.json"), "utf8"));
    assert(grade.passed === true && grade.failedCheckCount === 0, `${caseId}/${treatment}: deterministic grade changed`);
  }
  const candidateBoundary = JSON.parse(fs.readFileSync(path.join(resultRoot, "cases", caseId, "toolboxmd", "evidence", "authoring-boundary-audit.json"), "utf8"));
  assert(candidateBoundary.eligible === true, `${caseId}: candidate authoring boundary is not eligible`);
}

const initialValidation = JSON.parse(fs.readFileSync(path.join(resultRoot, "blind", "initial", "judgment-validation.json"), "utf8"));
const replayValidation = JSON.parse(fs.readFileSync(path.join(resultRoot, "blind", "replay-webhook", "judgment-validation.json"), "utf8"));
const identityMap = JSON.parse(fs.readFileSync(path.join(resultRoot, "blind", "identity-map.json"), "utf8"));
assert(initialValidation.valid === true, "initial blind judgment must remain valid");
assert(replayValidation.valid === false, "invalid replay must not become valid");
assert(identityMap.revealed === true, "identity map must be revealed only in retained evidence");

const manifestSha256 = crypto.createHash("sha256").update(fs.readFileSync(manifestPath)).digest("hex");
assert(evidence.evidence.result_manifest_sha256 === manifestSha256, "case-study evidence points to a different result manifest");
assert(evidence.benchmark.decision === "fail" && evidence.benchmark.candidate_recommended === false, "case-study evidence overstates the result");
assert(evidence.evidence.candidate_package_sha256 === candidate.aggregateSha256, "case-study candidate hash changed");
assert(evidence.evidence.sealed_cases_sha256 === sealed.aggregateSha256, "case-study sealed-case hash changed");

assert(!fs.existsSync(path.join(repositoryRoot, "skills", "toolboxmd-creating-skills")), "active candidate unexpectedly exists");
NODE

echo "PASS: failed ToolboxMD benchmark remains reproducible and non-promoted"
