#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
validator="$root/benchmarks/toolboxmd-creating-skills/v1/results/2026-08-12/candidate/toolboxmd-creating-skills/scripts/validate_skill.py"
test_tmp="$(mktemp -d "${TMPDIR:-/tmp}/toolboxmd-creator-validator.XXXXXX")"
trap 'rm -rf "$test_tmp"' EXIT

make_valid() {
  local directory="$1"
  local name="$2"
  mkdir -p "$directory/references" "$directory/agents"
  cat > "$directory/SKILL.md" <<EOF
---
name: $name
description: Create a fixture skill when validator behavior needs testing.
---

# Fixture

Read [the reference](references/guide.md).
EOF
  printf '# Guide\n' > "$directory/references/guide.md"
  cat > "$directory/agents/openai.yaml" <<EOF
interface:
  display_name: "Fixture Skill"
  short_description: "Create a portable fixture skill"
  default_prompt: "Use \$$name to create the requested fixture skill."
EOF
}

expect_pass() {
  local directory="$1"
  local output
  output=$(python3 -B "$validator" "$directory")
  [[ "$output" == "PASS: portable skill package validation succeeded" ]]
}

expect_fail() {
  local directory="$1"
  local expected="$2"
  local output
  set +e
  output=$(python3 -B "$validator" "$directory" 2>&1)
  local exit_code=$?
  set -e
  if [[ $exit_code -ne 1 || "$output" != *"$expected"* ]]; then
    echo "FAIL: expected validation error containing '$expected'" >&2
    echo "$output" >&2
    exit 1
  fi
}

make_valid "$test_tmp/valid-fixture" "valid-fixture"
expect_pass "$test_tmp/valid-fixture"

make_valid "$test_tmp/broken-link" "broken-link"
printf '\nRead [missing](references/missing.md).\n' >> "$test_tmp/broken-link/SKILL.md"
expect_fail "$test_tmp/broken-link" "broken relative link"

make_valid "$test_tmp/local-path" "local-path"
printf '\nLocal source: /Users/example/private.txt\n' >> "$test_tmp/local-path/SKILL.md"
expect_fail "$test_tmp/local-path" "possible hardcoded absolute path"

make_valid "$test_tmp/bad-sidecar" "bad-sidecar"
cat > "$test_tmp/bad-sidecar/agents/openai.yaml" <<'EOF'
interface:
  display_name: Fixture Skill
  short_description: "Too short"
  default_prompt: "Use this fixture."
EOF
expect_fail "$test_tmp/bad-sidecar" "must be double-quoted"
expect_fail "$test_tmp/bad-sidecar" "short_description must be 25-64 characters"
expect_fail "$test_tmp/bad-sidecar" "default_prompt must mention"

echo "PASS: ToolboxMD creator validator behavior verified"
