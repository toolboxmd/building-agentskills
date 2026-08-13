#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
package="$root/skills/toolboxmd-creating-skills"
validator="$package/scripts/validate_skill.py"
freeze="$root/benchmarks/toolboxmd-creating-skills/vnext/manifest.json"
test_tmp="$(mktemp -d "${TMPDIR:-/tmp}/toolboxmd-creator-vnext.XXXXXX")"
trap 'rm -rf "$test_tmp"' EXIT

retained=(
  "$root/benchmarks/toolboxmd-creating-skills/v1/results/2026-08-12/candidate/toolboxmd-creating-skills"
  "$root/benchmarks/toolboxmd-creating-skills/v2/results/2026-08-13/cases/meeting-followups/toolboxmd/skill"
  "$root/benchmarks/toolboxmd-creating-skills/v2/results/2026-08-13/cases/weekly-status-deck/toolboxmd/skill"
)
for index in "${!retained[@]}"; do
  node "$root/scripts/hash-tree.mjs" "${retained[$index]}" > "$test_tmp/retained-$index-before.json"
done

help_output="$(cd "$test_tmp" && PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --help)"
[[ "$help_output" == *"Exit: 0 valid, 1 invalid, 2 inspection error."* ]]

human_output="$(cd "$test_tmp" && PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" \
  --warnings-as-errors \
  --max-description-chars 300 \
  --max-skill-lines 150 \
  --max-skill-bytes 10500 \
  --max-files 3 \
  --max-package-bytes 24000 \
  --max-reference-files 0 \
  --max-eval-files 0 \
  --max-script-files 1 \
  "$package")"
[[ "$human_output" == *"METRICS: description_chars=278 skill_lines=114 skill_bytes=6353 files=3 package_bytes=23496 references=0 evals=0 scripts=1"* ]]
[[ "$human_output" == *"PASS: portable skill package validation succeeded"* ]]

cd "$test_tmp"
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json \
  --warnings-as-errors \
  --max-description-chars 300 \
  --max-skill-lines 150 \
  --max-skill-bytes 10500 \
  --max-files 3 \
  --max-package-bytes 24000 \
  --max-reference-files 0 \
  --max-eval-files 0 \
  --max-script-files 1 \
  "$package" > "$test_tmp/product.json"

set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" "$test_tmp/missing" > "$test_tmp/missing.out" 2>&1
missing_exit=$?
set -e
[[ $missing_exit -eq 2 ]]
grep -Fq "ERROR: not a directory:" "$test_tmp/missing.out"

make_fixture() {
  local directory="$1"
  local command_text="$2"
  mkdir -p "$directory/scripts"
  cat > "$directory/SKILL.md" <<EOF
---
name: $(basename "$directory")
description: Run a deterministic fixture when testing installed script path examples.
---

# Fixture

Run:

\`\`\`bash
$command_text
\`\`\`
EOF
  printf 'print("ok")\n' > "$directory/scripts/run.py"
  printf 'console.log("ok");\n' > "$directory/scripts/run.js"
  printf '#!/usr/bin/env bash\ntrue\n' > "$directory/scripts/run.sh"
}

make_fixture "$test_tmp/bare-fixture" $'python3 scripts/run.py\nnode scripts/run.js\nbash scripts/run.sh\nsh scripts/run.sh\nruby scripts/run.py'
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/bare-fixture" > "$test_tmp/bare.json"
bare_exit=$?
set -e
[[ $bare_exit -eq 1 ]]

make_fixture "$test_tmp/portable-fixture" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/portable-fixture" > "$test_tmp/portable.json"

set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$root/benchmarks/toolboxmd-creating-skills/v2/results/2026-08-13/cases/meeting-followups/toolboxmd/skill" > "$test_tmp/meeting.json"
meeting_exit=$?
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$root/benchmarks/toolboxmd-creating-skills/v2/results/2026-08-13/cases/weekly-status-deck/toolboxmd/skill" > "$test_tmp/deck.json"
deck_exit=$?
set -e
[[ $meeting_exit -eq 1 && $deck_exit -eq 1 ]]

node - "$root" "$freeze" "$test_tmp" <<'NODE'
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const [root, freezePath, temporary] = process.argv.slice(2);
const freeze = JSON.parse(fs.readFileSync(freezePath));
const product = JSON.parse(fs.readFileSync(path.join(temporary, "product.json")));
const bare = JSON.parse(fs.readFileSync(path.join(temporary, "bare.json")));
const portable = JSON.parse(fs.readFileSync(path.join(temporary, "portable.json")));
const meeting = JSON.parse(fs.readFileSync(path.join(temporary, "meeting.json")));
const deck = JSON.parse(fs.readFileSync(path.join(temporary, "deck.json")));

function assert(condition, message) {
  if (!condition) {
    console.error(`FAIL: ${message}`);
    process.exit(1);
  }
}

function fileSha(relative) {
  return crypto.createHash("sha256").update(fs.readFileSync(path.join(root, relative))).digest("hex");
}

assert(freeze.claimBoundary.newModelSessions === 0, "freeze must record zero model sessions");
assert(freeze.claimBoundary.superiorityClaimAllowed === false, "freeze must forbid a superiority claim");
assert(freeze.claimBoundary.promotionClaimAllowed === false, "freeze must forbid a promotion claim");
assert(freeze.source.v1ResultManifest.eligibleCreatorComparisons === 0, "v1 claim boundary changed");
assert(freeze.source.v2ResultManifest.eligibleCreatorComparisons === 0, "v2 claim boundary changed");
for (const source of [freeze.source.v1ResultManifest, freeze.source.v2ResultManifest, freeze.source.diagnosticRecommendations]) {
  assert(fileSha(source.path) === source.sha256, `source changed: ${source.path}`);
}

assert(product.status === "pass" && product.errorCount === 0 && product.warningCount === 0, "product validation failed");
assert(product.aggregateSha256 === freeze.package.aggregateSha256, "package aggregate differs from freeze");
assert(product.files.length === freeze.package.files.length, "per-file package count changed");
for (const actual of product.files) {
  const expected = freeze.package.files.find(item => item.path === actual.path);
  assert(expected && expected.bytes === actual.bytes && expected.sha256 === actual.sha256, `package file changed: ${actual.path}`);
}
const bytewise = [...product.files].sort((left, right) => Buffer.compare(Buffer.from(left.path, "utf8"), Buffer.from(right.path, "utf8")));
const independentAggregate = crypto.createHash("sha256").update(bytewise.map(item => `${item.sha256}  ${item.path}\n`).join("")).digest("hex");
assert(independentAggregate === freeze.package.aggregateSha256, "bytewise UTF-8 aggregate does not reproduce");
assert(product.metrics.descriptionCharacters === freeze.package.skillMd.descriptionCharacters, "description metric changed");
assert(product.metrics.skillMdLines === freeze.package.skillMd.lines, "line metric changed");
assert(product.metrics.skillMdBytes === freeze.package.skillMd.bytes, "core byte metric changed");
assert(product.metrics.fileCount === 3 && product.metrics.packageBytes === 23496, "package budget changed");
assert(product.metrics.referenceFileCount === 0 && product.metrics.evalFileCount === 0 && product.metrics.scriptFileCount === 1, "package ownership changed");

assert(bare.status === "fail", "bare script fixture must fail under warnings-as-errors");
assert(bare.issues.filter(item => item.code === "FRAGILE_SCRIPT_PATH").length === 5, "all bare interpreter examples must be detected");
assert(portable.status === "pass" && portable.warningCount === 0, "explicit skill-directory fixture must pass");
for (const [name, result, expectedEvals] of [["meeting", meeting, 1], ["deck", deck, 2]]) {
  assert(result.issues.some(item => item.code === "FRAGILE_SCRIPT_PATH"), `${name}: retained bare script pattern not detected`);
  assert(result.metrics.referenceFileCount === 1, `${name}: retained always-read reference pattern changed`);
  assert(result.metrics.evalFileCount === expectedEvals, `${name}: retained eval baggage pattern changed`);
}

const skillText = fs.readFileSync(path.join(root, freeze.package.path, "SKILL.md"), "utf8");
assert(!/\bgit\s+(?:status|rev-parse|diff|log)\b/i.test(skillText), "creator embeds an unconditional Git command");
assert(/Inspect Git state only when .*user requested Git delivery/.test(skillText), "conditional Git boundary missing");
assert(skillText.includes('"<skill-dir>/scripts/validate_skill.py"'), "portable creator command missing");
assert(skillText.includes("always-read reference belongs in activated-core cost"), "always-read cost rule missing");
NODE

if find "$package" "${retained[@]}" -type d -name __pycache__ -o -type f \( -name '*.pyc' -o -name '*.pyo' \) | grep -q .; then
  echo "FAIL: regression wrote Python bytecode" >&2
  exit 1
fi

for index in "${!retained[@]}"; do
  node "$root/scripts/hash-tree.mjs" "${retained[$index]}" > "$test_tmp/retained-$index-after.json"
  cmp "$test_tmp/retained-$index-before.json" "$test_tmp/retained-$index-after.json"
done

echo "PASS: ToolboxMD creating-skills vNext deterministic regression"
