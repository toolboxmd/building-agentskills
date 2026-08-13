#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runner="$root/scripts/run-isolated-codex-v2.sh"

[[ -f "$runner" ]] || { echo "FAIL: missing scripts/run-isolated-codex-v2.sh" >&2; exit 1; }

required_literals=(
  'PYTHONDONTWRITEBYTECODE=1'
  'PYTHONPYCACHEPREFIX="$run_root/.tmp/pycache"'
  '--ephemeral'
  '--ignore-user-config'
  '--ignore-rules'
  '--sandbox workspace-write'
  '--model gpt-5.6-sol'
  'model_reasoning_effort='"'"'"medium"'"'"''
  'features.apps=false'
  'features.plugins=false'
  'features.multi_agent=false'
  'features.memories=false'
  'skills.bundled.enabled=false'
  'web_search='"'"'"disabled"'"'"''
  'pythonBytecodeIsolation: true'
)

for literal in "${required_literals[@]}"; do
  grep -Fq -- "$literal" "$runner" || { echo "FAIL: v2 runner missing $literal" >&2; exit 1; }
done

echo "PASS: v2 runner freezes Python bytecode outside protected inputs"
