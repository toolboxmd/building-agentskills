#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_tmp="$(mktemp -d "${TMPDIR:-/tmp}/toolboxmd-event-audit.XXXXXX")"
trap 'rm -rf "$test_tmp"' EXIT
mkdir -p "$test_tmp/run"

cat > "$test_tmp/clean.jsonl" <<'EOF'
{"type":"item.completed","item":{"type":"agent_message","text":"No command was needed."}}
{"type":"turn.completed","usage":{"input_tokens":100,"cached_input_tokens":20,"output_tokens":10}}
EOF
clean=$(node "$root/scripts/audit-codex-events.mjs" "$test_tmp/clean.jsonl" "$test_tmp/run")
node - "$clean" <<'NODE'
const result = JSON.parse(process.argv[2]);
if (!result.eligible || result.reasons.length !== 0) process.exit(1);
if (result.schemaVersion !== 2 || result.commandExecutionEventCount !== 0) process.exit(1);
if (result.isolationEvidence.required || result.isolationEvidence.status !== "not_required") process.exit(1);
if (result.usage.inputTokens !== 100 || result.usage.outputTokens !== 10) process.exit(1);
NODE

printf '%s\n' '{"type":"item.started","item":{"type":"command_execution"}}' > "$test_tmp/unproven-command.jsonl"
set +e
unproven=$(node "$root/scripts/audit-codex-events.mjs" "$test_tmp/unproven-command.jsonl" "$test_tmp/run")
unproven_status=$?
set -e
[[ $unproven_status -ne 0 ]] || { echo "FAIL: an unproven command event should be ineligible" >&2; exit 1; }
node - "$unproven" <<'NODE'
const result = JSON.parse(process.argv[2]);
if (result.eligible || result.commandCount !== 0 || result.commandExecutionEventCount !== 1) process.exit(1);
if (!result.isolationEvidence.required || result.isolationEvidence.status !== "not_recorded" || result.isolationEvidence.trusted) process.exit(1);
if (!result.reasons.includes("command execution lacks recorded trusted filesystem, environment, and network isolation evidence")) process.exit(1);
NODE

for pair in \
  'nested|codex exec --ephemeral test' \
  'network|curl https://example.invalid' \
  'outside|sed -n 1p /Users/example/secret.txt' \
  'parent|sed -n 1p ../sibling/secret.txt'
do
  name=${pair%%|*}
  command=${pair#*|}
  printf '{"type":"item.completed","item":{"type":"command_execution","command":"%s","exit_code":0}}\n' "$command" > "$test_tmp/$name.jsonl"
  set +e
  output=$(node "$root/scripts/audit-codex-events.mjs" "$test_tmp/$name.jsonl" "$test_tmp/run")
  status=$?
  set -e
  if [[ $status -eq 0 ]]; then
    echo "FAIL: $name event should be ineligible" >&2
    exit 1
  fi
  case "$name" in
    nested) expected_reason="nested model or agentic CLI command observed" ;;
    network) expected_reason="network-capable command observed" ;;
    outside) expected_reason="absolute user path outside run root observed" ;;
    parent) expected_reason="parent-directory traversal observed" ;;
  esac
  node - "$output" "$expected_reason" <<'NODE'
const result = JSON.parse(process.argv[2]);
const expectedReason = process.argv[3];
if (result.eligible || !result.reasons.includes(expectedReason)) process.exit(1);
NODE
done

echo "PASS: Codex event audit requires trust-bearing isolation evidence for command streams"
