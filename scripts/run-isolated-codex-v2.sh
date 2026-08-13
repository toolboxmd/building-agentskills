#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 <run-root> <prompt-file> <evidence-directory> <skill-deny-list>" >&2
  exit 2
fi

: "${CODEX_HOME:?Set CODEX_HOME to a task-specific Codex home containing auth.json}"

run_root="$(cd "$1" && pwd)"
prompt_file="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
evidence_dir="$3"
deny_file="$(cd "$(dirname "$4")" && pwd)/$(basename "$4")"

if [[ ! -f "$prompt_file" ]]; then
  echo "FAIL: prompt file not found: $prompt_file" >&2
  exit 1
fi
if [[ ! -f "$deny_file" ]]; then
  echo "FAIL: skill deny-list not found: $deny_file" >&2
  exit 1
fi

mkdir -p "$evidence_dir"
evidence_dir="$(cd "$evidence_dir" && pwd)"
mkdir -p "$run_root/.tmp/pycache"

skill_config=$(node - "$deny_file" <<'NODE'
const fs = require("node:fs");
const paths = fs.readFileSync(process.argv[2], "utf8")
  .split(/\r?\n/)
  .map(line => line.trim())
  .filter(Boolean);
if (paths.length === 0) {
  console.error("FAIL: skill deny-list is empty");
  process.exit(1);
}
process.stdout.write(`[${paths.map(path => `{path=${JSON.stringify(path)},enabled=false}`).join(",")}]`);
NODE
)

started_epoch=$(date +%s)
codex_version=$(codex --version)

set +e
PYTHONDONTWRITEBYTECODE=1 \
PYTHONPYCACHEPREFIX="$run_root/.tmp/pycache" \
TMPDIR="$run_root/.tmp" \
codex exec \
  --ephemeral \
  --ignore-user-config \
  --ignore-rules \
  --skip-git-repo-check \
  --sandbox workspace-write \
  --model gpt-5.6-sol \
  --config model_reasoning_effort='"medium"' \
  --config "skills.config=$skill_config" \
  --config project_doc_max_bytes=0 \
  --config features.apps=false \
  --config features.plugins=false \
  --config features.multi_agent=false \
  --config features.memories=false \
  --config skills.bundled.enabled=false \
  --config web_search='"disabled"' \
  --config mcp_servers={} \
  --config plugins={} \
  --config apps._default.enabled=false \
  --json \
  --color never \
  --output-last-message "$evidence_dir/final-message.txt" \
  --cd "$run_root" \
  - < "$prompt_file" > "$evidence_dir/events.jsonl" 2> "$evidence_dir/stderr.txt"
exit_status=$?
set -e

finished_epoch=$(date +%s)
duration_seconds=$((finished_epoch - started_epoch))

node - "$evidence_dir/run-metadata.json" "$exit_status" "$duration_seconds" "$codex_version" "$run_root" "$prompt_file" "$deny_file" <<'NODE'
const fs = require("node:fs");
const [output, exitStatus, durationSeconds, codexVersion, runRoot, promptFile, denyFile] = process.argv.slice(2);
const metadata = {
  schemaVersion: 2,
  runnerId: "toolboxmd-benchmark-v2",
  exitStatus: Number(exitStatus),
  durationSeconds: Number(durationSeconds),
  codexVersion,
  model: "gpt-5.6-sol",
  modelReasoningEffort: "medium",
  sandbox: "workspace-write",
  expectedNetworkAccess: false,
  ephemeral: true,
  ignoreUserConfig: true,
  ignoreRules: true,
  pythonBytecodeIsolation: true,
  pythonBytecodeWritesDisabled: true,
  pythonCachePrefix: `${runRoot}/.tmp/pycache`,
  runRoot,
  promptFile,
  denyFile,
};
fs.writeFileSync(output, `${JSON.stringify(metadata, null, 2)}\n`);
NODE

exit "$exit_status"
