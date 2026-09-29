#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dir="$root/case-studies/evidence/2026-09-30-loader-trigger-benchmark"

# The loader case study's tables come from summary.md, which must regenerate
# byte for byte from the committed records, and the scorer must still reject the
# instrument defects its self-test pins (refused reads, reads after the edit,
# no-edit runs, OpenCode error parts).
python3 "$dir/trigger_test.py" --scorer-test
if ! python3 "$dir/trigger_test.py" --summary "$dir/records.jsonl" | cmp -s - "$dir/summary.md"; then
  echo "FAIL: summary.md does not match trigger_test.py --summary records.jsonl" >&2
  exit 1
fi
echo "OK: loader benchmark summary regenerates from records"
