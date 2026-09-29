#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sync="$root/scripts/check-version-sync.sh"
changelog="$root/scripts/check-changelog-updated.sh"

# Gates against the live tree.
bash "$sync" "$root" || { echo "FAIL: version anchors disagree" >&2; exit 1; }
echo "PASS: version anchors agree"
(cd "$root" && bash "$changelog") || { echo "FAIL: reader-visible change without a CHANGELOG.md change" >&2; exit 1; }
echo "PASS: changelog updated for reader-visible changes"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
repo="$work/repo"
mkdir -p "$repo/.claude-plugin" "$repo/docs"
cd "$repo"
git init -q -b main
git config user.email fixture@example.invalid
git config user.name fixture
printf '{"version":"1.2.0"}\n' >package.json
printf '{"version":"1.2.0"}\n' >.claude-plugin/plugin.json
printf '# Changelog\n\n## [Unreleased]\n\n## [1.2.0] - 2026-01-01\n' >CHANGELOG.md
printf 'page\n' >docs/page.md
printf 'code\n' >script.sh
git add -A && git commit -qm base
base="$(git rev-parse HEAD)"

expect_pass() { if "$@" >/dev/null 2>&1; then echo "PASS: $label"; else echo "FAIL: $label" >&2; "$@" || true; exit 1; fi; }
expect_fail() { if ! "$@" >"$work/out" 2>&1; then
    grep -q '^Fix: ' "$work/out" || { echo "FAIL: $label has no Fix line" >&2; cat "$work/out" >&2; exit 1; }
    echo "PASS: $label"
  else echo "FAIL: $label" >&2; exit 1; fi; }

label="agreeing fixture passes"; expect_pass bash "$sync" "$repo"

printf '{"version":"1.3.0"}\n' >.claude-plugin/plugin.json
label="plugin.json mismatch fails"; expect_fail bash "$sync" "$repo"
git checkout -q -- .claude-plugin/plugin.json

printf '{"version":"1.3.0"}\n' >package.json
printf '{"version":"1.3.0"}\n' >.claude-plugin/plugin.json
label="version without a CHANGELOG entry fails"; expect_fail bash "$sync" "$repo"
git checkout -q -- package.json .claude-plugin/plugin.json

git tag v1.2.0
label="matching tag passes"; expect_pass bash "$sync" "$repo"
git tag v1.3.0
label="tag that disagrees with the version fails"; expect_fail bash "$sync" "$repo"
git tag -d v1.2.0 v1.3.0 >/dev/null

printf 'changed\n' >docs/page.md
label="docs change without CHANGELOG fails"; expect_fail bash "$changelog" "$base"
git add -A && git commit -qm docs
label="committed docs change without CHANGELOG fails"; expect_fail bash "$changelog" "$base"
printf -- '- Changed the page.\n' >>CHANGELOG.md
label="docs change with CHANGELOG passes"; expect_pass bash "$changelog" "$base"
git reset -q --hard "$base"

printf 'changed\n' >script.sh
label="non-reader change without CHANGELOG passes"; expect_pass bash "$changelog" "$base"
git checkout -q -- script.sh

label="missing base fails"; expect_fail bash "$changelog" no-such-ref

echo "OK: check-version-and-changelog"
