#!/usr/bin/env bash
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mint="$root/node_modules/.bin/mint"

if [ ! -x "$mint" ]; then
  echo "FAIL: $mint missing; run npm ci" >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# run_mint <dir>: exit status of `mint broken-links` in <dir>; output shown only on failure.
run_mint() {
  local log="$work/mint.log"
  if (cd "$1" && "$mint" broken-links) >"$log" 2>&1; then
    return 0
  fi
  cat "$log" >&2
  return 1
}

# Check the working-tree content of tracked files only. Untracked drafts never
# enter the check, and wiki/ is excluded because karpathy-wiki validates it.
tree="$work/tree"
mkdir "$tree"
(
  cd "$root"
  git ls-files -z | while IFS= read -r -d '' f; do
    case "$f" in wiki/*) continue ;; esac
    [ -e "$f" ] && printf '%s\0' "$f"
  done | tar --null -T - -cf - | tar -xf - -C "$tree"
)
if ! run_mint "$tree"; then
  echo "FAIL: mint broken-links found a broken link or parse error in tracked files" >&2
  exit 1
fi
echo "PASS: tracked docs have no broken links"

# Self-test: the check must pass a clean fixture and fail a broken link and a parse error.
fixture="$work/fixture"
mkdir "$fixture"
printf '%s\n' '{"$schema":"https://mintlify.com/docs.json","theme":"mint","name":"fixture","colors":{"primary":"#000000"},"navigation":{"pages":["index"]}}' >"$fixture/docs.json"

printf -- '---\ntitle: Fixture\n---\n\nPlain text.\n' >"$fixture/index.md"
if run_mint "$fixture"; then
  echo "PASS: clean fixture passes"
else
  echo "FAIL: clean fixture flagged" >&2; exit 1
fi

printf -- '---\ntitle: Fixture\n---\n\nSee [missing](/docs/does-not-exist).\n' >"$fixture/index.md"
if ! run_mint "$fixture" 2>/dev/null; then
  echo "PASS: broken-link fixture fails"
else
  echo "FAIL: broken-link fixture not flagged" >&2; exit 1
fi

printf -- '---\ntitle: Fixture\n---\n\n<div>\n' >"$fixture/index.md"
if ! run_mint "$fixture" 2>/dev/null; then
  echo "PASS: parse-error fixture fails"
else
  echo "FAIL: parse-error fixture not flagged" >&2; exit 1
fi

echo "OK: check-docs-links"
