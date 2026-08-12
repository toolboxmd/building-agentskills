#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_tmp="$(mktemp -d "${TMPDIR:-/tmp}/toolboxmd-run-boundary.XXXXXX")"
trap 'rm -rf "$test_tmp"' EXIT

mkdir -p "$test_tmp/run/input"
printf 'protected\n' > "$test_tmp/run/input/source.txt"
node "$root/scripts/hash-tree.mjs" "$test_tmp/run" > "$test_tmp/input-manifest.json"

mkdir -p "$test_tmp/run/output/skill" "$test_tmp/run/.tmp"
printf 'result\n' > "$test_tmp/run/output/skill/SKILL.md"
printf 'scratch\n' > "$test_tmp/run/.tmp/scratch.txt"
node "$root/scripts/verify-run-boundary.mjs" \
  "$test_tmp/input-manifest.json" "$test_tmp/run" output/skill >/dev/null

printf 'changed\n' > "$test_tmp/run/input/source.txt"
if node "$root/scripts/verify-run-boundary.mjs" \
  "$test_tmp/input-manifest.json" "$test_tmp/run" output/skill >/dev/null 2>&1; then
  echo "FAIL: changed protected input should fail" >&2
  exit 1
fi

printf 'protected\n' > "$test_tmp/run/input/source.txt"
printf 'escape\n' > "$test_tmp/run/escape.txt"
if node "$root/scripts/verify-run-boundary.mjs" \
  "$test_tmp/input-manifest.json" "$test_tmp/run" output/skill >/dev/null 2>&1; then
  echo "FAIL: new file outside allowed prefix should fail" >&2
  exit 1
fi

echo "PASS: run boundary verifier protects inputs and output scope"
