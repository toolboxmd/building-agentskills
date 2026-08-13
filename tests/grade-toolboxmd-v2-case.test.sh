#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_tmp="$(mktemp -d "${TMPDIR:-/tmp}/toolboxmd-grade-v2.XXXXXX")"
trap 'rm -rf "$test_tmp"' EXIT
mkdir -p "$test_tmp/run/output"

printf '%s\n' \
  '# Report' \
  '## Facts' \
  'Alpha [X1]' > "$test_tmp/run/output/report.md"
printf '%s\n' \
  '---' \
  'marp: true' \
  'theme: default' \
  '---' \
  '# One' \
  'Alpha [X1]' \
  '---' \
  '# Two' \
  'Beta [X2]' > "$test_tmp/run/output/deck.md"
printf '%s\n' '{"ok":true,"count":2}' > "$test_tmp/run/output/check.json"
printf 'a,b\n1,2\n' > "$test_tmp/run/output/data.csv"

node - "$test_tmp/contract.json" <<'NODE'
const fs = require("node:fs");
const output = process.argv[2];
const contract = {
  schemaVersion: 2,
  caseId: "fixture",
  targetSkillName: "fixture",
  criticalCheckIds: ["exists", "headings", "contains", "not", "exact", "json", "frontmatter", "slides"],
  checks: [
    { id: "exists", type: "file-exists", path: "output/report.md" },
    { id: "headings", type: "markdown-headings-exact", path: "output/report.md", headings: ["Report", "Facts"] },
    { id: "contains", type: "contains-all", path: "output/report.md", caseSensitive: false, values: ["alpha", "[x1]"] },
    { id: "not", type: "not-contains", path: "output/report.md", caseSensitive: false, values: ["forbidden"] },
    { id: "exact", type: "exact-text", path: "output/data.csv", value: "a,b\n1,2\n" },
    { id: "json", type: "json-equals", path: "output/check.json", value: { ok: true, count: 2 } },
    { id: "frontmatter", type: "frontmatter-equals", path: "output/deck.md", value: { marp: "true", theme: "default" } },
    { id: "slides", type: "marp-slide-headings-exact", path: "output/deck.md", headings: ["One", "Two"] },
  ],
};
fs.writeFileSync(output, `${JSON.stringify(contract, null, 2)}\n`);
NODE

grade=$(node "$root/scripts/grade-toolboxmd-v2-case.mjs" "$test_tmp/contract.json" "$test_tmp/run")
node - "$grade" <<'NODE'
const grade = JSON.parse(process.argv[2]);
if (!grade.passed || grade.failedCheckCount !== 0) process.exit(1);
if (grade.criticalPassCount !== 8 || grade.criticalCheckCount !== 8) process.exit(1);
NODE

printf 'a,b\n9,9\n' > "$test_tmp/run/output/data.csv"
set +e
failed=$(node "$root/scripts/grade-toolboxmd-v2-case.mjs" "$test_tmp/contract.json" "$test_tmp/run")
status=$?
set -e
[[ $status -eq 1 ]] || { echo "FAIL: incorrect fixture should fail with status 1" >&2; exit 1; }
node - "$failed" <<'NODE'
const grade = JSON.parse(process.argv[2]);
if (grade.passed || grade.failedCheckIds.join(",") !== "exact") process.exit(1);
NODE

echo "PASS: v2 deterministic grader covers declared assertion types"
