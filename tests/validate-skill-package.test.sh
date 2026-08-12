#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
validator="$root/scripts/validate-skill-package.sh"
test_tmp="$(mktemp -d "${TMPDIR:-/tmp}/toolboxmd-skill-validator.XXXXXX")"
trap 'rm -rf "$test_tmp"' EXIT

run_expect_pass() {
  local skill_dir="$1"
  local output
  if ! output=$("$validator" "$skill_dir" 2>&1); then
    echo "FAIL: expected valid package: $skill_dir" >&2
    echo "$output" >&2
    exit 1
  fi
  if [[ "$output" != *"PASS: valid skill package"* ]]; then
    echo "FAIL: validator did not emit stable success output" >&2
    echo "$output" >&2
    exit 1
  fi
}

run_expect_fail() {
  local skill_dir="$1"
  local expected="$2"
  local output
  if output=$("$validator" "$skill_dir" 2>&1); then
    echo "FAIL: expected invalid package: $skill_dir" >&2
    exit 1
  fi
  if [[ "$output" != *"$expected"* ]]; then
    echo "FAIL: missing expected failure '$expected'" >&2
    echo "$output" >&2
    exit 1
  fi
}

mkdir -p "$test_tmp/valid/references"
cat > "$test_tmp/valid/SKILL.md" <<'EOF'
---
name: valid
description: Use when a valid fixture is needed.
---

# Valid

Read [the guide](references/guide.md).
EOF
cat > "$test_tmp/valid/references/guide.md" <<'EOF'
# Guide
EOF
run_expect_pass "$test_tmp/valid"

mkdir -p "$test_tmp/wrong-directory"
cat > "$test_tmp/wrong-directory/SKILL.md" <<'EOF'
---
name: another-name
description: Use when testing a directory mismatch.
---
EOF
run_expect_fail "$test_tmp/wrong-directory" "must match skill name"

mkdir -p "$test_tmp/missing-description"
cat > "$test_tmp/missing-description/SKILL.md" <<'EOF'
---
name: missing-description
---
EOF
run_expect_fail "$test_tmp/missing-description" "Missing required field"

long_description=$(printf 'x%.0s' {1..1025})
mkdir -p "$test_tmp/overlong"
cat > "$test_tmp/overlong/SKILL.md" <<EOF
---
name: overlong
description: $long_description
---
EOF
run_expect_fail "$test_tmp/overlong" "exceeds 1024 character limit"

mkdir -p "$test_tmp/broken-reference"
cat > "$test_tmp/broken-reference/SKILL.md" <<'EOF'
---
name: broken-reference
description: Use when testing a broken relative reference.
---

Read [the missing guide](references/missing.md).
EOF
run_expect_fail "$test_tmp/broken-reference" "broken relative reference"

echo "PASS: skill-package validator fixtures verified"
