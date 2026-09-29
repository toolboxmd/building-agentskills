#!/usr/bin/env bash
# Version anchors must agree: package.json, .claude-plugin/plugin.json, a
# CHANGELOG.md heading, and any v* tag on HEAD. Usage: check-version-sync.sh [repo-root]
set -euo pipefail
cd "${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

read_version() { node -p "require('./$1').version"; }
pkg="$(read_version package.json)"
plugin="$(read_version .claude-plugin/plugin.json)"
status=0

if [ "$pkg" != "$plugin" ]; then
  echo "FAIL: package.json says $pkg but .claude-plugin/plugin.json says $plugin" >&2
  echo "Fix: bash scripts/bump-version.sh $pkg" >&2
  status=1
fi

if ! grep -Fq "## [$pkg]" CHANGELOG.md; then
  echo "FAIL: CHANGELOG.md has no '## [$pkg]' entry for the current version" >&2
  echo "Fix: move the [Unreleased] notes under '## [$pkg] - $(date +%F)' in CHANGELOG.md" >&2
  status=1
fi

while IFS= read -r tag; do
  [ -n "$tag" ] || continue
  if [ "$tag" != "v$pkg" ]; then
    echo "FAIL: tag $tag points at HEAD but package.json says $pkg" >&2
    echo "Fix: git tag -d $tag && git push origin :refs/tags/$tag, then tag the commit whose version is ${tag#v}" >&2
    status=1
  fi
done < <(git tag --points-at HEAD --list 'v[0-9]*' 2>/dev/null)

exit "$status"
