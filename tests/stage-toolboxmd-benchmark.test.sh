#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_tmp="$(mktemp -d "${TMPDIR:-/tmp}/toolboxmd-stage-benchmark.XXXXXX")"
trap 'rm -rf "$test_tmp"' EXIT

mkdir -p "$test_tmp/sealed/demo/visible-inputs" "$test_tmp/sealed/demo/downstream-inputs"
mkdir -p "$test_tmp/creator/references" "$test_tmp/generated/scripts"
printf 'Create the required demo skill.\n' > "$test_tmp/sealed/demo/authoring-prompt.md"
printf 'Use the generated skill on this held-out task.\n' > "$test_tmp/sealed/demo/downstream-prompt.md"
printf '%s\n' '{"schemaVersion":1,"caseId":"demo","requiredSkillName":"generated-fixture"}' > "$test_tmp/sealed/demo/deterministic-contract.json"
printf 'visible\n' > "$test_tmp/sealed/demo/visible-inputs/source.txt"
printf 'hidden\n' > "$test_tmp/sealed/demo/downstream-inputs/challenge.txt"
printf '%s\n' '---' 'name: creator-fixture' 'description: Create a fixture.' '---' > "$test_tmp/creator/SKILL.md"
printf '# Guide\n' > "$test_tmp/creator/references/guide.md"
printf '%s\n' '---' 'name: generated-fixture' 'description: Use a generated fixture.' '---' > "$test_tmp/generated/SKILL.md"
printf '#!/usr/bin/env python3\n' > "$test_tmp/generated/scripts/run.py"

node "$root/scripts/stage-toolboxmd-benchmark.mjs" authoring \
  "$test_tmp/sealed" demo "$test_tmp/creator" "$test_tmp/authoring-root"

for required in task.md creator/SKILL.md creator/references/guide.md visible-inputs/source.txt; do
  [[ -f "$test_tmp/authoring-root/$required" ]] || { echo "FAIL: missing $required" >&2; exit 1; }
done
[[ ! -e "$test_tmp/authoring-root/downstream-inputs" ]]
[[ ! -e "$test_tmp/authoring-root/rubric.md" ]]
grep -q 'Read `creator/SKILL.md`' "$test_tmp/authoring-root/task.md"
grep -q 'Create the required demo skill' "$test_tmp/authoring-root/task.md"

node "$root/scripts/stage-toolboxmd-benchmark.mjs" downstream \
  "$test_tmp/sealed" demo "$test_tmp/generated" "$test_tmp/downstream-root"

for required in task.md output/generated-fixture/SKILL.md output/generated-fixture/scripts/run.py downstream-inputs/challenge.txt; do
  [[ -f "$test_tmp/downstream-root/$required" ]] || { echo "FAIL: missing $required" >&2; exit 1; }
done
[[ ! -e "$test_tmp/downstream-root/creator" ]]
[[ ! -e "$test_tmp/downstream-root/visible-inputs" ]]
grep -q 'Read `output/generated-fixture/SKILL.md`' "$test_tmp/downstream-root/task.md"
grep -q 'Use the generated skill on this held-out task' "$test_tmp/downstream-root/task.md"

if node "$root/scripts/stage-toolboxmd-benchmark.mjs" authoring \
  "$test_tmp/sealed" demo "$test_tmp/creator" "$test_tmp/authoring-root" >/dev/null 2>&1; then
  echo "FAIL: staging over an existing run root should fail" >&2
  exit 1
fi

echo "PASS: benchmark staging keeps authoring and downstream roots isolated"
