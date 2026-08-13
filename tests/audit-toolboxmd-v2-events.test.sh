#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_tmp="$(mktemp -d "${TMPDIR:-/tmp}/toolboxmd-audit-v2.XXXXXX")"
trap 'rm -rf "$test_tmp"' EXIT
mkdir -p "$test_tmp/run/.agents/skills/demo-target"
mkdir -p "$test_tmp/run/creator/scripts" "$test_tmp/run/output/demo"
printf '%s\n' '---' 'name: demo-target' 'description: Use for the demo ritual.' '---' '' '# Demo' '' 'Return the beacon.' > "$test_tmp/run/.agents/skills/demo-target/SKILL.md"

node - "$test_tmp/run" "$test_tmp/positive.jsonl" "$test_tmp/preflight.jsonl" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const [runRoot, positivePath, preflightPath] = process.argv.slice(2);
const skill = fs.readFileSync(path.join(runRoot, ".agents/skills/demo-target/SKILL.md"), "utf8");
const load = {
  type: "item.completed",
  item: {
    type: "command_execution",
    command: "/bin/zsh -lc \"sed -n '1,200p' .agents/skills/demo-target/SKILL.md\"",
    aggregated_output: skill,
    exit_code: 0,
    status: "completed",
  },
};
const usage = { type: "turn.completed", usage: { input_tokens: 100, cached_input_tokens: 20, output_tokens: 10 } };
fs.writeFileSync(positivePath, `${JSON.stringify(load)}\n${JSON.stringify(usage)}\n`);
const curl = {
  type: "item.completed",
  item: {
    type: "command_execution",
    command: "/bin/zsh -lc 'curl --max-time 5 -I https://example.com'",
    aggregated_output: "curl: network denied\n",
    exit_code: 6,
    status: "completed",
  },
};
fs.writeFileSync(preflightPath, `${JSON.stringify(load)}\n${JSON.stringify(curl)}\n${JSON.stringify(usage)}\n`);
NODE

printf '%s\n' \
  '{"type":"item.completed","item":{"type":"command_execution","command":"python3 ../../creator/scripts/validate_skill.py .","aggregated_output":"PASS","exit_code":0,"status":"completed"}}' \
  '{"type":"item.completed","item":{"type":"command_execution","command":"git status --short","aggregated_output":"?? ../../outside-name.md\\n","exit_code":0,"status":"completed"}}' \
  '{"type":"turn.completed","usage":{"input_tokens":10,"cached_input_tokens":0,"output_tokens":1}}' > "$test_tmp/authoring.jsonl"

authoring=$(node "$root/scripts/audit-toolboxmd-v2-events.mjs" \
  "$test_tmp/authoring.jsonl" "$test_tmp/run" authoring .agents/skills/demo-target/SKILL.md 2>/dev/null || true)
node - "$authoring" <<'NODE'
const result = JSON.parse(process.argv[2]);
if (!result.gitStatus.observed || !result.gitStatus.ancestorWorktreeNamesObserved) process.exit(1);
if (!result.warnings.includes("git status exposed names from an ancestor worktree without reading file contents")) process.exit(1);
if (!result.reasons.includes("parent-directory traversal observed")) process.exit(1);
NODE

printf '%s\n' \
  '{"type":"item.completed","item":{"type":"command_execution","command":"sed -n 1,20p ../../creator/SKILL.md","aggregated_output":"","exit_code":0,"status":"completed"}}' \
  '{"type":"turn.completed","usage":{"input_tokens":10,"cached_input_tokens":0,"output_tokens":1}}' > "$test_tmp/root-traversal.jsonl"
set +e
root_traversal=$(node "$root/scripts/audit-toolboxmd-v2-events.mjs" \
  "$test_tmp/root-traversal.jsonl" "$test_tmp/run" near-miss none)
status=$?
set -e
[[ $status -eq 1 ]] || { echo "FAIL: unlocated parent traversal should fail" >&2; exit 1; }
node - "$root_traversal" <<'NODE'
const result = JSON.parse(process.argv[2]);
if (result.eligible || !result.reasons.includes("parent-directory traversal observed")) process.exit(1);
NODE

node - "$test_tmp/run" "$test_tmp/embedded-parent.jsonl" <<'NODE'
const fs = require("node:fs");
const [runRoot, output] = process.argv.slice(2);
const command = {
  type: "item.completed",
  item: {
    type: "command_execution",
    command: "/bin/zsh -lc 'sed -n 1p workspace/../../grader/secret'",
    cwd: runRoot,
    aggregated_output: "",
    exit_code: 0,
    status: "completed",
  },
};
const usage = { type: "turn.completed", usage: { input_tokens: 10, cached_input_tokens: 0, output_tokens: 1 } };
fs.writeFileSync(output, `${JSON.stringify(command)}\n${JSON.stringify(usage)}\n`);
NODE
set +e
embedded_parent=$(node "$root/scripts/audit-toolboxmd-v2-events.mjs" \
  "$test_tmp/embedded-parent.jsonl" "$test_tmp/run" near-miss none)
status=$?
set -e
[[ $status -eq 1 ]] || { echo "FAIL: embedded parent segment should fail" >&2; exit 1; }
node - "$embedded_parent" <<'NODE'
const result = JSON.parse(process.argv[2]);
if (result.eligible || !result.reasons.includes("parent-directory traversal observed")) process.exit(1);
NODE

printf '%s\n' \
  '{"type":"item.completed","item":{"type":"command_execution","command":"find .. -name AGENTS.md -print","aggregated_output":"","exit_code":0,"status":"completed"}}' \
  '{"type":"turn.completed","usage":{"input_tokens":10,"cached_input_tokens":0,"output_tokens":1}}' > "$test_tmp/bare-parent.jsonl"
set +e
bare_parent=$(node "$root/scripts/audit-toolboxmd-v2-events.mjs" \
  "$test_tmp/bare-parent.jsonl" "$test_tmp/run" near-miss none)
status=$?
set -e
[[ $status -eq 1 ]] || { echo "FAIL: bare parent operand should fail" >&2; exit 1; }
node - "$bare_parent" <<'NODE'
const result = JSON.parse(process.argv[2]);
if (result.eligible || !result.reasons.includes("parent-directory traversal observed")) process.exit(1);
NODE

printf '%s\n' \
  '{"type":"item.completed","item":{"type":"command_execution","command":"find workspace -name AGENTS.md -print","aggregated_output":"","exit_code":0,"status":"completed"}}' \
  '{"type":"turn.completed","usage":{"input_tokens":10,"cached_input_tokens":0,"output_tokens":1}}' > "$test_tmp/safe-in-root.jsonl"
safe_in_root=$(node "$root/scripts/audit-toolboxmd-v2-events.mjs" \
  "$test_tmp/safe-in-root.jsonl" "$test_tmp/run" near-miss none)
node - "$safe_in_root" <<'NODE'
const result = JSON.parse(process.argv[2]);
if (!result.eligible || result.reasons.includes("parent-directory traversal observed")) process.exit(1);
NODE

node - "$test_tmp/run" "$test_tmp/recorded-cwd.jsonl" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const [runRoot, output] = process.argv.slice(2);
const command = {
  type: "item.completed",
  item: {
    type: "command_execution",
    command: "python3 ../../creator/scripts/validate_skill.py .",
    cwd: path.join(runRoot, "output/demo"),
    aggregated_output: "PASS\n",
    exit_code: 0,
    status: "completed",
  },
};
const usage = { type: "turn.completed", usage: { input_tokens: 10, cached_input_tokens: 0, output_tokens: 1 } };
fs.writeFileSync(output, `${JSON.stringify(command)}\n${JSON.stringify(usage)}\n`);
NODE
recorded_cwd=$(node "$root/scripts/audit-toolboxmd-v2-events.mjs" \
  "$test_tmp/recorded-cwd.jsonl" "$test_tmp/run" near-miss none)
node - "$recorded_cwd" <<'NODE'
const result = JSON.parse(process.argv[2]);
if (!result.eligible || result.reasons.includes("parent-directory traversal observed")) process.exit(1);
NODE

positive=$(node "$root/scripts/audit-toolboxmd-v2-events.mjs" \
  "$test_tmp/positive.jsonl" "$test_tmp/run" positive .agents/skills/demo-target/SKILL.md)
node - "$positive" <<'NODE'
const result = JSON.parse(process.argv[2]);
if (!result.eligible || !result.expectedSkillLoad.fullContentObserved) process.exit(1);
if (result.usage.uncachedInputTokens !== 80 || result.usage.runtimeTokens !== 90) process.exit(1);
NODE

near_miss=$(node "$root/scripts/audit-toolboxmd-v2-events.mjs" \
  "$test_tmp/positive.jsonl" "$test_tmp/run" near-miss none)
node - "$near_miss" <<'NODE'
const result = JSON.parse(process.argv[2]);
if (!result.eligible || !result.falsePositiveSkillLoad) process.exit(1);
NODE

preflight=$(node "$root/scripts/audit-toolboxmd-v2-events.mjs" \
  "$test_tmp/preflight.jsonl" "$test_tmp/run" preflight .agents/skills/demo-target/SKILL.md)
node - "$preflight" <<'NODE'
const result = JSON.parse(process.argv[2]);
if (!result.eligible || !result.networkProbe.observed || !result.networkProbe.blocked) process.exit(1);
NODE

printf '%s\n' '{"type":"item.completed","item":{"type":"command_execution","command":"codex exec nested","aggregated_output":"","exit_code":0,"status":"completed"}}' > "$test_tmp/contaminated.jsonl"
set +e
contaminated=$(node "$root/scripts/audit-toolboxmd-v2-events.mjs" \
  "$test_tmp/contaminated.jsonl" "$test_tmp/run" noskill none)
status=$?
set -e
[[ $status -eq 1 ]] || { echo "FAIL: contaminated audit should fail" >&2; exit 1; }
node - "$contaminated" <<'NODE'
const result = JSON.parse(process.argv[2]);
if (result.eligible || !result.reasons.includes("nested model or agentic CLI command observed")) process.exit(1);
NODE

echo "PASS: v2 event audit proves loads, costs, near misses, and network blocking"
