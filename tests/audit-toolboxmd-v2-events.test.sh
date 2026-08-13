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

printf '%s\n' '{"type":"turn.completed","usage":{"input_tokens":10,"cached_input_tokens":0,"output_tokens":1}}' > "$test_tmp/zero-command.jsonl"
zero_command=$(node "$root/scripts/audit-toolboxmd-v2-events.mjs" \
  "$test_tmp/zero-command.jsonl" "$test_tmp/run" near-miss none)
node - "$zero_command" <<'NODE'
const result = JSON.parse(process.argv[2]);
if (result.schemaVersion !== 3 || !result.eligible || result.commandCount !== 0) process.exit(1);
if (result.commandExecutionEventCount !== 0) process.exit(1);
if (result.isolationEvidence.required || result.isolationEvidence.trusted || result.isolationEvidence.status !== "not_required") process.exit(1);
NODE

printf '%s\n' \
  '{"type":"item.started","item":{"type":"command_execution","command":"cat workspace/input.md","aggregated_output":"","exit_code":null,"status":"in_progress"}}' \
  '{"type":"turn.completed","usage":{"input_tokens":10,"cached_input_tokens":0,"output_tokens":1}}' > "$test_tmp/started-command.jsonl"
set +e
started_command=$(node "$root/scripts/audit-toolboxmd-v2-events.mjs" \
  "$test_tmp/started-command.jsonl" "$test_tmp/run" near-miss none)
status=$?
set -e
[[ $status -eq 1 ]] || { echo "FAIL: started command event without isolation evidence should fail" >&2; exit 1; }
node - "$started_command" <<'NODE'
const result = JSON.parse(process.argv[2]);
const reason = "command execution lacks recorded trusted filesystem, environment, and network isolation evidence";
if (result.eligible || !result.reasons.includes(reason)) process.exit(1);
if (result.commandCount !== 0 || result.commandExecutionEventCount !== 1) process.exit(1);
if (!result.isolationEvidence.required || result.isolationEvidence.trusted) process.exit(1);
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
set +e
safe_in_root=$(node "$root/scripts/audit-toolboxmd-v2-events.mjs" \
  "$test_tmp/safe-in-root.jsonl" "$test_tmp/run" near-miss none)
status=$?
set -e
[[ $status -eq 1 ]] || { echo "FAIL: command-bearing stream without isolation proof should fail" >&2; exit 1; }
node - "$safe_in_root" <<'NODE'
const result = JSON.parse(process.argv[2]);
const reason = "command execution lacks recorded trusted filesystem, environment, and network isolation evidence";
if (result.eligible || !result.reasons.includes(reason) || result.reasons.includes("parent-directory traversal observed")) process.exit(1);
if (!result.isolationEvidence.required || result.isolationEvidence.trusted || result.isolationEvidence.status !== "not_recorded") process.exit(1);
NODE

git_run="$test_tmp/ancestor-repo/run"
mkdir -p "$test_tmp/ancestor-repo/.git" "$git_run/output"
node - "$test_tmp/git-commands" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const output = process.argv[2];
fs.mkdirSync(output, { recursive: true });
const commands = [
  ["status-empty", "git status --short"],
  ["status-scoped", "git status --short -- output"],
  ["ls-files", "git ls-files --error-unmatch output/SKILL.md"],
  ["diff-scoped", "git diff --stat -- output"],
  ["shell-wrapper", "/bin/zsh -lc 'git status --short'"],
  ["command-substitution", "printf '%s\\n' \"$(git status --short)\""],
  ["backtick-substitution", "printf '%s\\n' `git status --short`"],
  ["process-substitution", "cat <(git status --short)"],
  ["env-options", "env -i git status --short"],
  ["nice-options", "nice -n 5 git status --short"],
  ["nested-prefixes", "env -i nice -n 5 command git status --short"],
  ["heredoc-wrapper-tail", `/bin/zsh -lc "python3 - <<'PY'
print('git status')
PY
git status --short"`],
];
const safeCommands = [
  ["safe-non-git", "find output -type f -print"],
  ["safe-echo", "printf '%s\\n' 'git status'; echo 'git diff -- output'; echo git status"],
  ["safe-substitution-text", "printf '%s\\n' '$(git status)' '`git diff`' '<(git ls-files)'; echo \"$(printf '%s' 'git status')\"; echo \"<(git diff)\"; echo $((git + 1))"],
  ["safe-prefix-operands", "env -i echo git status; nice -n 5 echo git diff; command -v git"],
  ["safe-heredoc-text", `python3 - <<'PY'
print('git status')
PY`],
];
const usage = { type: "turn.completed", usage: { input_tokens: 10, cached_input_tokens: 0, output_tokens: 1 } };
for (const [name, command] of [...commands, ...safeCommands]) {
  const event = {
    type: "item.completed",
    item: { type: "command_execution", command, aggregated_output: "", exit_code: 0, status: "completed" },
  };
  fs.writeFileSync(path.join(output, `${name}.jsonl`), `${JSON.stringify(event)}\n${JSON.stringify(usage)}\n`);
}
NODE
for git_name in status-empty status-scoped ls-files diff-scoped shell-wrapper command-substitution backtick-substitution process-substitution env-options nice-options nested-prefixes heredoc-wrapper-tail; do
  set +e
  git_result=$(node "$root/scripts/audit-toolboxmd-v2-events.mjs" \
    "$test_tmp/git-commands/$git_name.jsonl" "$git_run" near-miss none)
  status=$?
  set -e
  [[ $status -eq 1 ]] || { echo "FAIL: $git_name should reject Git without read-isolation proof" >&2; exit 1; }
  node - "$git_result" <<'NODE'
const result = JSON.parse(process.argv[2]);
const reason = "Git command executed without proof of read isolation from repository and configuration metadata";
if (result.eligible || !result.reasons.includes(reason)) process.exit(1);
if (!result.gitExecution.observed || result.gitExecution.readIsolationProven !== false) process.exit(1);
if (result.gitExecution.commandCount !== 1) process.exit(1);
NODE
done
for safe_name in safe-non-git safe-echo safe-substitution-text safe-prefix-operands safe-heredoc-text; do
  set +e
  safe_git_text=$(node "$root/scripts/audit-toolboxmd-v2-events.mjs" \
    "$test_tmp/git-commands/$safe_name.jsonl" "$git_run" near-miss none)
  status=$?
  set -e
  [[ $status -eq 1 ]] || { echo "FAIL: $safe_name lacks trusted command isolation proof" >&2; exit 1; }
  node - "$safe_git_text" <<'NODE'
const result = JSON.parse(process.argv[2]);
const reason = "command execution lacks recorded trusted filesystem, environment, and network isolation evidence";
if (result.eligible || !result.reasons.includes(reason)) process.exit(1);
if (result.gitExecution.observed || result.gitExecution.readIsolationProven !== null) process.exit(1);
NODE
done
own_git_run="$test_tmp/ancestor-repo/own-repo"
mkdir -p "$own_git_run/.git"
set +e
own_git=$(node "$root/scripts/audit-toolboxmd-v2-events.mjs" \
  "$test_tmp/git-commands/status-empty.jsonl" "$own_git_run" near-miss none)
status=$?
set -e
[[ $status -eq 1 ]] || { echo "FAIL: own repository must not bypass Git read isolation" >&2; exit 1; }
node - "$own_git" <<'NODE'
const result = JSON.parse(process.argv[2]);
if (result.eligible || !result.gitExecution.observed || result.gitExecution.readIsolationProven !== false) process.exit(1);
NODE

gitfile_run="$test_tmp/worktree-gitfile-run"
mkdir -p "$gitfile_run"
printf '%s\n' "gitdir: $test_tmp/external-git-metadata" > "$gitfile_run/.git"
set +e
gitfile_result=$(node "$root/scripts/audit-toolboxmd-v2-events.mjs" \
  "$test_tmp/git-commands/status-empty.jsonl" "$gitfile_run" near-miss none)
status=$?
set -e
[[ $status -eq 1 ]] || { echo "FAIL: worktree gitfile should reject outside Git metadata" >&2; exit 1; }
node - "$gitfile_result" <<'NODE'
const result = JSON.parse(process.argv[2]);
const reason = "Git command executed without proof of read isolation from repository and configuration metadata";
if (result.eligible || !result.reasons.includes(reason)) process.exit(1);
if (!result.gitExecution.observed || result.gitExecution.readIsolationProven !== false) process.exit(1);
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
set +e
recorded_cwd=$(node "$root/scripts/audit-toolboxmd-v2-events.mjs" \
  "$test_tmp/recorded-cwd.jsonl" "$test_tmp/run" near-miss none)
status=$?
set -e
[[ $status -eq 1 ]] || { echo "FAIL: recorded cwd does not replace isolation proof" >&2; exit 1; }
node - "$recorded_cwd" <<'NODE'
const result = JSON.parse(process.argv[2]);
const reason = "command execution lacks recorded trusted filesystem, environment, and network isolation evidence";
if (result.eligible || !result.reasons.includes(reason) || result.reasons.includes("parent-directory traversal observed")) process.exit(1);
NODE

mkdir -p "$test_tmp/absolute-paths"
node - "$test_tmp/run" "$test_tmp/absolute-paths" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const [runRoot, output] = process.argv.slice(2);
const commands = [
  ["safe-wrapper", "/bin/zsh -lc 'sed -n 1p workspace/input.md 2>/dev/null'"],
  ["safe-in-root", `/bin/zsh -lc 'sed -n 1p "${path.join(runRoot, "workspace/input.md")}"'`],
  ["safe-inline-in-root", `python3 -c 'open("${path.join(runRoot, "workspace/input.md")}").read()'`],
  ["safe-inline-regex", "python3 -c 'import re; re.compile(r\"/Users/|/home/\")'"],
  ["safe-executable-after-semicolon", "/bin/zsh -lc 'printf ready; /usr/bin/python3 -V'"],
  ["outside-etc", "/bin/zsh -lc 'sed -n 1p /etc/passwd'"],
  ["outside-workspace", "/bin/zsh -lc 'cat /workspace/sibling/grader.json'"],
  ["outside-tmp", "/bin/zsh -lc 'cat /tmp/benchmark-secret'"],
  ["outside-windows", "/bin/zsh -lc 'cat C:\\\\bench\\\\grader.json'"],
  ["outside-assignment", "/bin/zsh -lc 'INPUT=/etc/passwd; sed -n 1p \"$INPUT\"'"],
  ["outside-executable-loop", "/bin/zsh -lc 'for candidate in python3 /usr/bin/python3; do command -v \"$candidate\"; done'"],
  ["outside-data-loop", "/bin/zsh -lc 'for f in /etc/passwd; do cat \"$f\"; done'"],
  ["outside-after-semicolon", "/bin/zsh -lc 'printf ready; /usr/bin/python3 /tmp/secret.py'"],
  ["outside-heredoc", "/bin/zsh -lc \"python3 - <<'PY'\\nopen('/etc/passwd').read()\\nPY\""],
  ["outside-inline-python", "python3 -c 'print(open(\"/etc/passwd\").read())'"],
  ["outside-inline-print-conservative", "python3 -c 'print(\"/etc/passwd\")'"],
  ["outside-inline-python-wrapper", "/bin/zsh -lc \"python3 -c 'open(\\\"/etc/passwd\\\").read()'\""],
  ["outside-inline-python-prefix", "command env -i python3 -c 'open(\"/etc/passwd\").read()'"],
  ["outside-inline-python-option", "python3 -W ignore -c 'open(\"/etc/passwd\").read()'"],
  ["outside-inline-python-windows", "python3 -c 'open(r\"C:\\\\bench\\\\grader.json\").read()'"],
  ["outside-inline-pathlib", "python3 -c 'from pathlib import Path; Path(\"/etc/passwd\").read_text()'"],
  ["outside-inline-node", "node --eval 'require(\"fs\").readFileSync(\"/etc/passwd\", \"utf8\")'"],
  ["outside-inline-ruby", "ruby -e 'File.read(\"/etc/passwd\")'"],
  ["outside-inline-perl", "perl -e 'open(\"/etc/passwd\")'"],
  ["outside-inline-php", "php -r 'file_get_contents(\"/etc/passwd\");'"],
  ["url-not-path", "/bin/zsh -lc 'printf %s https://example.com/reference'"],
  ["regex-not-path", "/bin/zsh -lc \"rg '/Users/|/home/' workspace\""],
  ["heredoc-regex-not-path", "/bin/zsh -lc \"python3 - <<'PY'\\nimport re\\nre.compile(r'/Users/|/home/')\\nPY\""],
  ["env-expanded-path", "/bin/zsh -lc 'cat \"$CODEX_HOME/auth.json\"'"],
  ["interpreter-network", "python3 -c 'import urllib.request; urllib.request.urlopen(\"https://example.com\")'"],
];
const usage = { type: "turn.completed", usage: { input_tokens: 10, cached_input_tokens: 0, output_tokens: 1 } };
for (const [name, command] of commands) {
  const event = {
    type: "item.completed",
    item: { type: "command_execution", command, cwd: runRoot, aggregated_output: "", exit_code: 0, status: "completed" },
  };
  fs.writeFileSync(path.join(output, `${name}.jsonl`), `${JSON.stringify(event)}\n${JSON.stringify(usage)}\n`);
}
NODE
for safe_name in safe-wrapper safe-in-root safe-inline-in-root safe-inline-regex safe-executable-after-semicolon url-not-path regex-not-path heredoc-regex-not-path env-expanded-path interpreter-network; do
  set +e
  safe_absolute=$(node "$root/scripts/audit-toolboxmd-v2-events.mjs" \
    "$test_tmp/absolute-paths/$safe_name.jsonl" "$test_tmp/run" near-miss none)
  status=$?
  set -e
  [[ $status -eq 1 ]] || { echo "FAIL: $safe_name lacks trusted command isolation proof" >&2; exit 1; }
  node - "$safe_absolute" <<'NODE'
const result = JSON.parse(process.argv[2]);
const reason = "command execution lacks recorded trusted filesystem, environment, and network isolation evidence";
if (result.eligible || !result.reasons.includes(reason)) process.exit(1);
if (result.reasons.includes("absolute filesystem path outside run root observed")) process.exit(1);
NODE
done
for outside_name in outside-etc outside-workspace outside-tmp outside-windows outside-assignment outside-executable-loop outside-data-loop outside-after-semicolon outside-heredoc outside-inline-python outside-inline-print-conservative outside-inline-python-wrapper outside-inline-python-prefix outside-inline-python-option outside-inline-python-windows outside-inline-pathlib outside-inline-node outside-inline-ruby outside-inline-perl outside-inline-php; do
  set +e
  outside_absolute=$(node "$root/scripts/audit-toolboxmd-v2-events.mjs" \
    "$test_tmp/absolute-paths/$outside_name.jsonl" "$test_tmp/run" near-miss none)
  status=$?
  set -e
  [[ $status -eq 1 ]] || { echo "FAIL: $outside_name absolute path should fail" >&2; exit 1; }
  node - "$outside_absolute" <<'NODE'
const result = JSON.parse(process.argv[2]);
if (result.eligible || !result.reasons.includes("absolute filesystem path outside run root observed")) process.exit(1);
NODE
done

set +e
positive=$(node "$root/scripts/audit-toolboxmd-v2-events.mjs" \
  "$test_tmp/positive.jsonl" "$test_tmp/run" positive .agents/skills/demo-target/SKILL.md)
status=$?
set -e
[[ $status -eq 1 ]] || { echo "FAIL: positive command stream lacks isolation evidence" >&2; exit 1; }
node - "$positive" <<'NODE'
const result = JSON.parse(process.argv[2]);
const reason = "command execution lacks recorded trusted filesystem, environment, and network isolation evidence";
if (result.eligible || !result.reasons.includes(reason) || !result.expectedSkillLoad.fullContentObserved) process.exit(1);
if (result.usage.uncachedInputTokens !== 80 || result.usage.runtimeTokens !== 90) process.exit(1);
NODE

set +e
near_miss=$(node "$root/scripts/audit-toolboxmd-v2-events.mjs" \
  "$test_tmp/positive.jsonl" "$test_tmp/run" near-miss none)
status=$?
set -e
[[ $status -eq 1 ]] || { echo "FAIL: command-bearing near miss lacks isolation evidence" >&2; exit 1; }
node - "$near_miss" <<'NODE'
const result = JSON.parse(process.argv[2]);
if (result.eligible || !result.falsePositiveSkillLoad) process.exit(1);
NODE

set +e
preflight=$(node "$root/scripts/audit-toolboxmd-v2-events.mjs" \
  "$test_tmp/preflight.jsonl" "$test_tmp/run" preflight .agents/skills/demo-target/SKILL.md)
status=$?
set -e
[[ $status -eq 1 ]] || { echo "FAIL: preflight commands lack isolation evidence" >&2; exit 1; }
node - "$preflight" <<'NODE'
const result = JSON.parse(process.argv[2]);
if (result.eligible || !result.networkProbe.observed || !result.networkProbe.blocked) process.exit(1);
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

echo "PASS: v2 event audit applies command isolation evidence and diagnostic trace checks"
