#!/usr/bin/env bash
# A change under docs/, case-studies/, skills/ or examples/ since the base must
# also change CHANGELOG.md. Usage: check-changelog-updated.sh [base-ref]
# Default base: the merge base of HEAD with origin/$GITHUB_BASE_REF (CI) or
# origin/main. Compares the base with the working tree, so uncommitted and untracked
# files count.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

target="${1:-origin/${GITHUB_BASE_REF:-main}}"
if ! base="$(git merge-base "$target" HEAD 2>/dev/null)"; then
  echo "FAIL: no merge base with $target" >&2
  echo "Fix: git fetch origin (in CI, check out with fetch-depth: 0)" >&2
  exit 1
fi

changed="$(git diff --name-only "$base" --; git ls-files --others --exclude-standard)"
reader="$(printf '%s\n' "$changed" | grep -E '^(docs|case-studies|skills|examples)/' || true)"
if [ -n "$reader" ] && ! printf '%s\n' "$changed" | grep -qx 'CHANGELOG.md'; then
  echo "FAIL: reader-visible files changed since ${base:0:7} without a CHANGELOG.md change:" >&2
  printf '%s\n' "$reader" | sed 's/^/  /' >&2
  echo "Fix: add a line under '## [Unreleased]' in CHANGELOG.md" >&2
  exit 1
fi
