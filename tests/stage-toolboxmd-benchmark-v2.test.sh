#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_tmp="$(mktemp -d "${TMPDIR:-/tmp}/toolboxmd-stage-v2.XXXXXX")"
trap 'rm -rf "$test_tmp"' EXIT

case_root="$test_tmp/cases/demo"
mkdir -p "$case_root/authoring-sources/knowledge" "$case_root/downstream-workspace/knowledge" "$case_root/downstream-workspace/workspace"
mkdir -p "$test_tmp/creator/references" "$test_tmp/generated/demo-target"

printf 'Build demo-target under output.\n' > "$case_root/authoring-prompt.md"
printf 'Process workspace/input.txt into output.\n' > "$case_root/downstream-prompt.md"
printf 'Give general advice only.\n' > "$case_root/near-miss-prompt.md"
printf '%s\n' '{"schemaVersion":2,"caseId":"demo","targetSkillName":"demo-target","criticalCheckIds":["x"],"checks":[]}' > "$case_root/contract.json"
printf 'rules\n' > "$case_root/authoring-sources/knowledge/rules.md"
printf 'rules\n' > "$case_root/downstream-workspace/knowledge/rules.md"
printf 'input\n' > "$case_root/downstream-workspace/workspace/input.txt"
printf '%s\n' '---' 'name: creator-fixture' 'description: Create a fixture.' '---' > "$test_tmp/creator/SKILL.md"
printf 'reference\n' > "$test_tmp/creator/references/guide.md"
printf '%s\n' '---' 'name: demo-target' 'description: Use for the exact demo processing request.' '---' > "$test_tmp/generated/demo-target/SKILL.md"

node "$root/scripts/stage-toolboxmd-benchmark-v2.mjs" authoring \
  "$test_tmp/cases" demo "$test_tmp/creator" "$test_tmp/authoring-root"

for required in task.md creator/SKILL.md creator/references/guide.md authoring-sources/knowledge/rules.md; do
  [[ -f "$test_tmp/authoring-root/$required" ]] || { echo "FAIL: authoring missing $required" >&2; exit 1; }
done
[[ ! -e "$test_tmp/authoring-root/downstream-workspace" ]]

node "$root/scripts/stage-toolboxmd-benchmark-v2.mjs" noskill \
  "$test_tmp/cases" demo "$test_tmp/no-skill-root"

for required in task.md knowledge/rules.md workspace/input.txt; do
  [[ -f "$test_tmp/no-skill-root/$required" ]] || { echo "FAIL: no-skill missing $required" >&2; exit 1; }
done
[[ ! -e "$test_tmp/no-skill-root/.agents" ]]

node "$root/scripts/stage-toolboxmd-benchmark-v2.mjs" downstream \
  "$test_tmp/cases" demo "$test_tmp/generated/demo-target" "$test_tmp/downstream-root"

for required in task.md knowledge/rules.md workspace/input.txt .agents/skills/demo-target/SKILL.md; do
  [[ -f "$test_tmp/downstream-root/$required" ]] || { echo "FAIL: downstream missing $required" >&2; exit 1; }
done

mkdir -p "$test_tmp/treatment-skills/demo-target"
cp "$test_tmp/generated/demo-target/SKILL.md" "$test_tmp/treatment-skills/demo-target/SKILL.md"
node "$root/scripts/stage-toolboxmd-benchmark-v2.mjs" near-miss \
  "$test_tmp/cases" demo "$test_tmp/treatment-skills" "$test_tmp/near-miss-root"

[[ -f "$test_tmp/near-miss-root/task.md" ]]
[[ -f "$test_tmp/near-miss-root/.agents/skills/demo-target/SKILL.md" ]]
grep -Fq 'Give general advice only.' "$test_tmp/near-miss-root/task.md"

if node "$root/scripts/stage-toolboxmd-benchmark-v2.mjs" noskill \
  "$test_tmp/cases" demo "$test_tmp/no-skill-root" >/dev/null 2>&1; then
  echo "FAIL: staging over an existing root should fail" >&2
  exit 1
fi

echo "PASS: v2 staging preserves the creator and downstream counterfactual"
