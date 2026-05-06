#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$here/.." && pwd)"
cd "$repo_root"

# Run the gate against the live tree.
if ! bash scripts/check-no-bare-paths.sh; then
  echo "FAIL: bare backtick path chips found"
  exit 1
fi

# Self-test the gate against fixtures: it must flag bare chips, allow linked chips, and allow allowlisted topical mentions.
fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT

# Fixture 1: bare chip — should be flagged.
echo 'See `docs/03-three-questions.md` for details.' > "$fixture_dir/bare.md"

# Fixture 2: linked chip — should be allowed.
# IMPORTANT: this fixture MUST contain a backtick-wrapped chip *inside* link
# syntax. A plain Markdown link without a backticked path is NOT a valid test
# of the link-detection logic — the script's grep would find zero chips and
# return 0 by absence rather than by correctly recognizing the link context.
# Per the Pattern A rule, the chip lives as link-text inside [..](..).
echo 'See [`docs/03-three-questions.md`](/docs/03-three-questions) for details.' > "$fixture_dir/linked.md"

# Fixture 3: topical mention (allowlisted) — should be allowed.
echo 'Your `SKILL.md` should be under 500 lines.' > "$fixture_dir/topical.md"

# Fixture 4: chip with single-line suffix (e.g. `something.md:366`) — should be flagged.
echo 'See `docs/03-three-questions.md:48` for the audit reference.' > "$fixture_dir/bare-with-line.md"

# Fixture 5: chip with line-range suffix (e.g. `something.md:30-65`) — should be flagged.
echo 'See `docs/03-three-questions.md:30-65` for the architectural decision.' > "$fixture_dir/bare-with-range.md"

# Self-test mode: the script accepts a path argument for fixture-mode testing.
if bash scripts/check-no-bare-paths.sh "$fixture_dir/linked.md"; then
  echo "PASS: linked chip not flagged"
else
  echo "FAIL: linked chip incorrectly flagged"; exit 1
fi

if bash scripts/check-no-bare-paths.sh "$fixture_dir/topical.md"; then
  echo "PASS: topical mention not flagged"
else
  echo "FAIL: topical mention incorrectly flagged"; exit 1
fi

if ! bash scripts/check-no-bare-paths.sh "$fixture_dir/bare.md"; then
  echo "PASS: bare chip flagged"
else
  echo "FAIL: bare chip not flagged"; exit 1
fi

if ! bash scripts/check-no-bare-paths.sh "$fixture_dir/bare-with-line.md"; then
  echo "PASS: bare chip with single-line suffix flagged"
else
  echo "FAIL: bare chip with single-line suffix not flagged (gate missed .md:<line> pattern)"; exit 1
fi

if ! bash scripts/check-no-bare-paths.sh "$fixture_dir/bare-with-range.md"; then
  echo "PASS: bare chip with line-range suffix flagged"
else
  echo "FAIL: bare chip with line-range suffix not flagged (gate missed .md:<start>-<end> pattern)"; exit 1
fi

echo "PASS: all bare-paths gate fixtures verified"
