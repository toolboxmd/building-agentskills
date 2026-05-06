#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$here/.." && pwd)"
cd "$repo_root"

# Scope: published doc surface only. Excludes docs/superpowers/ (unpublished plans and specs).
violations=$(grep -rn '/Users/' docs/ case-studies/ examples/ README.md \
  --exclude-dir=superpowers \
  2>/dev/null || true)

if [[ -n "$violations" ]]; then
  echo "FAIL: absolute /Users/ paths found in published docs:"
  echo "$violations"
  exit 1
fi

echo "PASS: no absolute paths in published docs"
