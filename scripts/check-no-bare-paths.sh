#!/usr/bin/env bash
# Check for bare backtick-wrapped path chips (`docs/X.md`) that should be Markdown links.
#
# Default scope: docs/, case-studies/, examples/, README.md (excluding docs/superpowers/specs/).
# Argument mode: takes one or more paths and greps only those.
#
# A chip is flagged unless:
#   - It appears inside Markdown link syntax: [...`<chip>`...](...) or [...](.../`<chip>`...).
#   - Its payload matches the allowlist of known-topical filenames.
#
# Out of scope (NOT flagged):
#   - Non-.md filename chips (.sh, .py, .json, etc.) — implicitly Pattern C topical.
#   - GitHub-form #L<n> anchors appended to chips — known regex gap; rely on review.
#   - Reference-style links and multi-line links — known false-positive shapes; add to allowlist if encountered.
#
# Exit codes:
#   0 — no violations.
#   1 — one or more violations; emit file:line:violation lines on stdout.

set -euo pipefail

# Allowlist: backtick-payload exact-match strings that are always topical references, never navigational.
ALLOWLIST=(
  "SKILL.md"
  "plugin.json"
  "hooks.json"
  "marketplace.json"
  ".claude-plugin/plugin.json"
  "index.md"
  "GEMINI.md"
  "CLAUDE.md"
  "AGENTS.md"
  "LICENSE"
)

# Allowlist prefixes: any chip whose payload starts with one of these is a topical
# example path inside a wiki/test/config tree, not a navigational link.
ALLOWLIST_PREFIXES=(
  "raw/"
  "tests/fixtures/"
  ".claude/commands/"
  ".claude/skills/"
)

# Determine scan paths.
if [[ $# -gt 0 ]]; then
  scan_paths=("$@")
else
  scan_paths=("docs" "case-studies" "examples" "README.md")
fi

# Build grep exclusion args (only relevant for the default tree scan).
grep_exclude_args=(--exclude-dir=superpowers)

# The chip regex: backtick-wrapped path ending in .md, optionally followed by :<line> or :<start>-<end>.
# Captures both `docs/X.md` and `docs/X.md:48` and `docs/X.md:30-65`.
chip_regex='`[A-Za-z0-9._/-]+\.md(:[0-9]+(-[0-9]+)?)?`'

violations_found=0

while IFS= read -r match; do
  [[ -z "$match" ]] && continue

  # match is like: docs/file.md:42:...the matched line content...
  file=$(echo "$match" | cut -d: -f1)
  lineno=$(echo "$match" | cut -d: -f2)
  line_content=$(echo "$match" | cut -d: -f3-)

  # Extract the chip payload (without surrounding backticks).
  chip=$(echo "$line_content" | grep -oE "$chip_regex" | head -1 | sed 's/^`//; s/`$//')

  # Strip optional :<line> or :<line>-<line> suffix to get the bare filename for allowlist comparison.
  chip_payload=$(echo "$chip" | sed -E 's/:[0-9]+(-[0-9]+)?$//')

  # Check allowlist (exact-match against payload).
  is_allowlisted=0
  for allowed in "${ALLOWLIST[@]}"; do
    if [[ "$chip_payload" == "$allowed" ]]; then
      is_allowlisted=1
      break
    fi
  done
  if [[ $is_allowlisted -eq 1 ]]; then
    continue
  fi

  # Check prefix allowlist (chip payload begins with a topical-tree prefix).
  for prefix in "${ALLOWLIST_PREFIXES[@]}"; do
    if [[ "$chip_payload" == "$prefix"* ]]; then
      is_allowlisted=1
      break
    fi
  done
  if [[ $is_allowlisted -eq 1 ]]; then
    continue
  fi

  # Check if the chip appears inside Markdown link syntax on the same line.
  # Heuristic: the chip's backticks fall inside a [...](...)  block.
  # Two valid forms:
  #   [...`chip`...](...)    — chip in link text
  #   [...](.../`chip`...)   — chip in link target (rare but valid)
  # Implementation: a line that contains both `]` and `(` adjacent to the chip is treated as a link.
  if echo "$line_content" | grep -qE '\[[^]]*`[A-Za-z0-9._/-]+\.md(:[0-9]+(-[0-9]+)?)?`[^]]*\]\([^)]*\)'; then
    continue
  fi
  if echo "$line_content" | grep -qE '\[[^]]+\]\([^)]*`[A-Za-z0-9._/-]+\.md(:[0-9]+(-[0-9]+)?)?`[^)]*\)'; then
    continue
  fi

  # Not allowlisted, not inside a link — violation.
  echo "${file}:${lineno}: bare chip \`${chip}\` outside link syntax: ${line_content}"
  violations_found=1
done < <(grep -rnE "$chip_regex" "${grep_exclude_args[@]}" "${scan_paths[@]}" 2>/dev/null || true)

if [[ $violations_found -eq 1 ]]; then
  exit 1
fi

exit 0
