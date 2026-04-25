#!/usr/bin/env bash
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$root/scripts/check-llms-coverage.ts"

if [ ! -f "$script" ]; then
  echo "EXPECTED-MISSING-SCRIPT: scripts/check-llms-coverage.ts" >&2
  exit 1
fi

cd "$root"
backup="$(mktemp)"
cp public/llms.txt "$backup"
trap 'mv "$backup" public/llms.txt' EXIT

missing_slug="docs/05-authoring/frontmatter"
grep -v "$missing_slug" public/llms.txt > "$backup.modified"
mv "$backup.modified" public/llms.txt

out="$(npm run --silent check:llms-coverage 2>&1)"
rc=$?

if [ "$rc" -eq 0 ]; then
  echo "FAIL: coverage script exited 0 against corrupted llms.txt" >&2
  exit 1
fi
if ! printf '%s' "$out" | grep -q "$missing_slug"; then
  echo "FAIL: coverage script did not name missing slug $missing_slug" >&2
  exit 1
fi
echo "OK: check-llms-coverage"
