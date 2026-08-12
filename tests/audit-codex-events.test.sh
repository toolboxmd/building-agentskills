#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_tmp="$(mktemp -d "${TMPDIR:-/tmp}/toolboxmd-event-audit.XXXXXX")"
trap 'rm -rf "$test_tmp"' EXIT
mkdir -p "$test_tmp/run"

cat > "$test_tmp/clean.jsonl" <<'EOF'
{"type":"item.completed","item":{"type":"command_execution","command":"/bin/zsh -lc \"sed -n '1p' creator/SKILL.md\"","exit_code":0}}
{"type":"item.completed","item":{"type":"command_execution","command":"python3 script.py --input ../../visible-inputs/source.csv","exit_code":0}}
{"type":"item.completed","item":{"type":"command_execution","command":"python3 -c \"assert '/Users/|file://'\"","exit_code":0}}
{"type":"turn.completed","usage":{"input_tokens":100,"cached_input_tokens":20,"output_tokens":10}}
EOF
clean=$(node "$root/scripts/audit-codex-events.mjs" "$test_tmp/clean.jsonl" "$test_tmp/run")
node - "$clean" <<'NODE'
const result = JSON.parse(process.argv[2]);
if (!result.eligible || result.reasons.length !== 0) process.exit(1);
if (result.usage.inputTokens !== 100 || result.usage.outputTokens !== 10) process.exit(1);
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
  node - "$output" <<'NODE'
const result = JSON.parse(process.argv[2]);
if (result.eligible || result.reasons.length === 0) process.exit(1);
NODE
done

echo "PASS: Codex event audit catches contamination signals"
