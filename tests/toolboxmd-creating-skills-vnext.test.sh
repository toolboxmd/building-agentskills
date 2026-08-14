#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
package="$root/skills/toolboxmd-creating-skills"
validator="$package/scripts/validate_skill.py"
freeze="$root/benchmarks/toolboxmd-creating-skills/vnext/manifest.json"
minimal_example="$root/examples/minimal-skill"
test_tmp="$(mktemp -d "${TMPDIR:-/tmp}/toolboxmd-creator-vnext.XXXXXX")"
cleanup() {
  local test_exit=$?
  rm -rf "$test_tmp"
  return "$test_exit"
}
trap cleanup EXIT

retained=(
  "$root/benchmarks/toolboxmd-creating-skills/v1/results/2026-08-12/candidate/toolboxmd-creating-skills"
  "$root/benchmarks/toolboxmd-creating-skills/v2/results/2026-08-13/cases/meeting-followups/toolboxmd/skill"
  "$root/benchmarks/toolboxmd-creating-skills/v2/results/2026-08-13/cases/weekly-status-deck/toolboxmd/skill"
)
for index in "${!retained[@]}"; do
  node "$root/scripts/hash-tree.mjs" "${retained[$index]}" > "$test_tmp/retained-$index-before.json"
done
pending=("$root/wiki/.wiki-pending/"*.md "$root/wiki/.wiki-pending/"*.md.processing)
for index in "${!pending[@]}"; do
  cp "${pending[$index]}" "$test_tmp/pending-$index-before"
done

help_output="$(cd "$test_tmp" && PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --help)"
[[ "$help_output" == *"Exit: 0 valid, 1 invalid, 2 inspection error."* ]]
[[ "$help_output" == *"--script-syntax-checked PATH=SHA256"* ]]
[[ "$help_output" == *"--creation-mode"* ]]
[[ "$help_output" == *"tighten portable 1024-character ceiling"* ]]
! grep -Eq '\|[[:space:]]*None' "$validator"

python39="$(command -v python3.9 || true)"
if [[ -z "$python39" && -x /usr/bin/python3 ]] && /usr/bin/python3 -c 'import sys; raise SystemExit(sys.version_info[:2] != (3, 9))'; then
  python39=/usr/bin/python3
fi
if [[ -n "$python39" ]]; then
  PYTHONDONTWRITEBYTECODE=1 "$python39" -B "$validator" --help > "$test_tmp/python39-help.out"
  grep -Fq "Exit: 0 valid, 1 invalid, 2 inspection error." "$test_tmp/python39-help.out"
fi

human_output="$(cd "$test_tmp" && PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" \
  --creation-mode \
  --warnings-as-errors \
  --max-description-chars 300 \
  --max-skill-lines 150 \
  --max-skill-bytes 10500 \
  --max-files 3 \
  --max-package-bytes 46000 \
  --max-reference-files 0 \
  --max-eval-files 0 \
  --max-script-files 1 \
  "$package")"
[[ "$human_output" == *"COVERAGE: canonical=toolboxmd-portable-core-v2 extensions=none creation_mode=true script_paths=closed-surfaces shell_parsed=false script_syntax=python-ast+exact-digest-attestation official_skills_ref=not_available official_external_attested=false"* ]]
[[ "$human_output" == *"SCRIPT_SYNTAX_CHECKS: accepted_paths=[] execution_verified_by_toolboxmd=false"* ]]
[[ "$human_output" == *"PASS: canonical ToolboxMD package checks succeeded"* ]]

cd "$test_tmp"
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json \
  --creation-mode \
  --warnings-as-errors \
  --max-description-chars 300 \
  --max-skill-lines 150 \
  --max-skill-bytes 10500 \
  --max-files 3 \
  --max-package-bytes 46000 \
  --max-reference-files 0 \
  --max-eval-files 0 \
  --max-script-files 1 \
  "$package" > "$test_tmp/product.json"

PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors \
  --max-description-chars 400 \
  --max-skill-lines 60 \
  --max-skill-bytes 2500 \
  --max-files 1 \
  --max-package-bytes 2500 \
  --max-reference-files 0 \
  --max-eval-files 0 \
  --max-script-files 0 \
  "$minimal_example" > "$test_tmp/minimal-example.json"

set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" "$test_tmp/missing" > "$test_tmp/missing.out" 2>&1
missing_exit=$?
set -e
[[ $missing_exit -eq 2 ]]
grep -Fq "ERROR: not a directory:" "$test_tmp/missing.out"

make_fixture() {
  local directory="$1"
  local command_text="$2"
  mkdir -p "$directory/scripts"
  cat > "$directory/SKILL.md" <<EOF
---
name: "$(basename "$directory")"
description: "Run a deterministic fixture when testing installed script path examples."
---

# Fixture

Run:

\`\`\`bash
$command_text
\`\`\`
EOF
  printf 'print("ok")\n' > "$directory/scripts/run.py"
}

make_body_fixture() {
  local directory="$1"
  local body="$2"
  mkdir -p "$directory/scripts"
  cat > "$directory/SKILL.md" <<EOF
---
name: "$(basename "$directory")"
description: "Run a deterministic fixture when testing closed Markdown and helper-source surfaces."
---

# Fixture

$body
EOF
  printf 'print("ok")\n' > "$directory/scripts/run.py"
}

sha256_file() {
  node -e 'const c=require("node:crypto"),f=require("node:fs");process.stdout.write(c.createHash("sha256").update(f.readFileSync(process.argv[1])).digest("hex"))' "$1"
}

make_fixture "$test_tmp/outside-executable" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
mkdir -p "$test_tmp/outside-executable/bin"
printf 'echo broken )\n' > "$test_tmp/outside-executable/bin/run.sh"
chmod +x "$test_tmp/outside-executable/bin/run.sh"
make_fixture "$test_tmp/outside-shebang" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf '#!/bin/sh\necho broken )\n' > "$test_tmp/outside-shebang/run-helper"
make_fixture "$test_tmp/outside-data" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
mkdir -p "$test_tmp/outside-data/bin"
printf 'echo inert data\n' > "$test_tmp/outside-data/bin/run.sh"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/outside-executable" > "$test_tmp/outside-executable.json"
outside_executable_exit=$?
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/outside-shebang" > "$test_tmp/outside-shebang.json"
outside_shebang_exit=$?
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/outside-data" > "$test_tmp/outside-data.json"
outside_data_exit=$?
set -e


make_body_fixture "$test_tmp/closed-shell-bare" $'```bash\nenv MODE=strict ./scripts/run.py\necho scripts/run.py\nprintf "scripts/run.py"\n# scripts/run.py\ncat <<\'PAYLOAD\'\nscripts/run.py\nPAYLOAD\n>scripts/run.py\n<scripts/run.py\n2>scripts/run.py\necho scripts/"run.py"\necho scripts/\'run.py\'\necho scripts/""run.py\necho "scripts/"run.py\necho \'a"b\' scripts/"run.py"\necho "scripts/>out"\necho "scripts/<in"\necho "scripts/;child"\necho "scripts/,child"\necho "scripts/:child"\necho scripts/<helper>\necho scripts/<child.py>\necho scripts/{run.py}\necho scripts/*.py\necho [helper](scripts/run.py)\n```\n\n~~~Sh\ntrue && ./scripts/run.py\n~~~\n\n```SHELL\n./scripts/run.py\n```'
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/closed-shell-bare" > "$test_tmp/closed-shell-bare.json"
closed_shell_bare_exit=$?
set -e
[[ $closed_shell_bare_exit -eq 1 ]]

make_body_fixture "$test_tmp/closed-shell-safe" $'An unmatched ` in one paragraph must not absorb later prose.\n\nOrdinary prose may name scripts/run.py and [link a helper](scripts/run.py) without presenting executable code.\n\nA multiline span `\nscripts/run.py\n` stays outside the single-line custom check.\n\nUse the directory `scripts/` for helpers. Inline `[scripts/]` and `{scripts/}` stay directory-only. Literal \\`scripts/run.py\\` is escaped prose.\n\n```bash\nPYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"\necho scripts/\necho "scripts/"\necho "helper directory: scripts/";\necho "Use scripts/ for helpers"\necho "scripts/ run.py"\necho scripts/" run.py"\necho \'a"b\' "scripts/";\n# don\'t use scripts/ for generated files\necho scripts/;\necho scripts/&&\necho scripts/|\necho scripts/>out\necho scripts/<in\n```'
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/closed-shell-safe" > "$test_tmp/closed-shell-safe.json"
closed_shell_safe_exit=$?
set -e
if [[ $closed_shell_safe_exit -ne 0 ]]; then
  sed -n '1,200p' "$test_tmp/closed-shell-safe.json" >&2
  exit 1
fi

make_body_fixture "$test_tmp/parent-relative-shell" $'```bash\npython3 ../scripts/run.py\npython3 ../../scripts/run.py\npython3 ./../scripts/run.py\npython3 .././scripts/run.py\npython3 ../.././../scripts/run.py\n```'
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/parent-relative-shell" > "$test_tmp/parent-relative-shell.json"
parent_relative_shell_exit=$?
set -e
[[ $parent_relative_shell_exit -eq 1 ]]

make_body_fixture "$test_tmp/parent-relative-code" $'Run `python3 ../scripts/run.py` and `python3 ./../scripts/run.py`.\n\n```text\npython3 ../../scripts/run.py\npython3 ../.././../scripts/run.py\n```'
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/parent-relative-code" > "$test_tmp/parent-relative-code.json"
parent_relative_code_exit=$?
set -e
[[ $parent_relative_code_exit -eq 1 ]]

make_body_fixture "$test_tmp/windows-relative-shell" $'```bash\npython scripts\\run.py\npython .\\scripts\\run.py\npython ..\\scripts\\run.py\npython ./..\\scripts\\run.py\npython .\\../scripts\\run.py\n```'
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/windows-relative-shell" > "$test_tmp/windows-relative-shell.json"
windows_relative_shell_exit=$?
set -e
[[ $windows_relative_shell_exit -eq 1 ]]

make_body_fixture "$test_tmp/windows-relative-code" $'Run `python scripts\\run.py` and `python ./..\\scripts\\run.py`.\n\n```text\npython ..\\scripts\\run.py\npython .\\../scripts\\run.py\n```'
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/windows-relative-code" > "$test_tmp/windows-relative-code.json"
windows_relative_code_exit=$?
set -e
[[ $windows_relative_code_exit -eq 1 ]]

make_body_fixture "$test_tmp/embedded-relative-shell" $'```bash\npython3 foo/scripts/run.py\npython3 foo/../scripts/run.py\npython3 foo/./../scripts/run.py\npython3 foo/bar/../../scripts/run.py\npython3 foo\\scripts\\run.py\npython3 foo\\..\\scripts\\run.py\npython3 foo\\.\\..\\scripts\\run.py\npython3 foo\\bar\\..\\..\\scripts\\run.py\npython3 foo/bar\\..\\../scripts/run.py\n```'
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/embedded-relative-shell" > "$test_tmp/embedded-relative-shell.json"
embedded_relative_shell_exit=$?
set -e
[[ $embedded_relative_shell_exit -eq 1 ]]

make_body_fixture "$test_tmp/embedded-relative-code" $'Run `python3 foo/../scripts/run.py` and `python3 foo\\..\\scripts\\run.py`.\n\n```text\npython3 foo/bar/../../scripts/run.py\npython3 foo/bar\\..\\../scripts/run.py\n```'
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/embedded-relative-code" > "$test_tmp/embedded-relative-code.json"
embedded_relative_code_exit=$?
set -e
[[ $embedded_relative_code_exit -eq 1 ]]

make_body_fixture "$test_tmp/scripts-component-shell" $'```bash\npython3 Scripts/run.py\npython3 ./SCRIPTS\\run.py\npython3 foo+/Scripts/run.py\npython3 foo+/bar/../ScRiPtS\\run.py\npython3 foo+\\.\\..\\sCrIpTs/run.py\npython3 "foo&/Scripts/run.py"\npython3 "foo,/Scripts/run.py"\npython3 "foo;/Scripts/run.py"\npython3 "foo(/Scripts/run.py"\npython3 "foo[/Scripts/run.py"\npython3 "foo{/Scripts/run.py"\npython3 foo,/Scripts/run.py\npython3 foo,\\SCRIPTS\\run.py\npython3 foo,/bar/../sCrIpTs\\run.py\n```'
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/scripts-component-shell" > "$test_tmp/scripts-component-shell.json"
scripts_component_shell_exit=$?
set -e

make_body_fixture "$test_tmp/scripts-component-code" $'Run `python3 Scripts/run.py` and `python3 foo+/SCRIPTS\\run.py`.\n\n```text\npython3 foo+/bar/../ScRiPtS/run.py\npython3 foo+\\.\\..\\sCrIpTs\\run.py\npython3 "foo&/Scripts/run.py"\npython3 "foo,/Scripts/run.py"\npython3 "foo;/Scripts/run.py"\npython3 "foo(/Scripts/run.py"\npython3 "foo[/Scripts/run.py"\npython3 "foo{/Scripts/run.py"\npython3 foo,/Scripts/run.py\npython3 foo,\\SCRIPTS\\run.py\npython3 foo,/.\\../sCrIpTs\\run.py\n```'
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/scripts-component-code" > "$test_tmp/scripts-component-code.json"
scripts_component_code_exit=$?
set -e

make_body_fixture "$test_tmp/scripts-substring-safe" $'Run `python3 foo+scripts/run.py`, `python3 foo@scripts/run.py`, `python3 foo=scripts/run.py`, and `python3 foo%scripts/run.py`.\n\n```bash\npython3 foo#scripts/run.py\npython3 foo_scripts/run.py\npython3 fooscripts/run.py\npython3 foo,scripts/run.py\npython3 foo,Scripts/run.py\npython3 foo,sCrIpTs\\run.py\npython3 "foo&scripts/run.py"\npython3 "foo,scripts/run.py"\npython3 "foo;scripts/run.py"\npython3 "foo(scripts/run.py"\npython3 "foo[scripts/run.py"\npython3 "foo{scripts/run.py"\n```\n\n```text\npython3 foo+scripts\\run.py\npython3 foo@scripts\\run.py\npython3 foo=scripts\\run.py\npython3 foo%scripts\\run.py\npython3 foo#scripts\\run.py\npython3 foo_scripts\\run.py\npython3 fooscripts\\run.py\npython3 foo,scripts\\run.py\npython3 foo,Scripts/run.py\npython3 foo,sCrIpTs\\run.py\npython3 "foo&scripts\\run.py"\npython3 "foo,scripts\\run.py"\npython3 "foo;scripts\\run.py"\npython3 "foo(scripts\\run.py"\npython3 "foo[scripts\\run.py"\npython3 "foo{scripts\\run.py"\n```'
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/scripts-substring-safe" > "$test_tmp/scripts-substring-safe.json"
scripts_substring_safe_exit=$?
set -e

make_body_fixture "$test_tmp/tilde-segment-shell" $'```bash\npython3 foo~/./../scripts/run.py\npython3 ~foo/../scripts/run.py\npython3 foo~bar/../scripts/run.py\npython3 foo~\\.\\..\\scripts\\run.py\npython3 ~foo\\..\\scripts\\run.py\npython3 foo~bar/.\\..\\scripts/run.py\n```'
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/tilde-segment-shell" > "$test_tmp/tilde-segment-shell.json"
tilde_segment_shell_exit=$?
set -e
[[ $tilde_segment_shell_exit -eq 1 ]]

make_body_fixture "$test_tmp/tilde-segment-code" $'Run `python3 foo~/./../scripts/run.py` and `python3 ~foo\\.\\..\\scripts\\run.py`.\n\n```text\npython3 foo~bar/../scripts/run.py\npython3 foo~bar\\..\\scripts/run.py\n```'
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/tilde-segment-code" > "$test_tmp/tilde-segment-code.json"
tilde_segment_code_exit=$?
set -e
[[ $tilde_segment_code_exit -eq 1 ]]

make_body_fixture "$test_tmp/parent-relative-safe" $'[Documented helper](foo/../scripts/run.py) remains a link destination.\n\n```bash\npython3 "<skill-dir>/scripts/run.py"\npython3 "<skill-dir>\\scripts\\run.py"\ncurl https://example.com/scripts/run.py\ncurl "https://example.com/?next=foo/../scripts/run.py"\ncurl "https://example.com/#foo/../scripts/run.py"\ncurl "https://example.com/path;next=foo/../scripts/run.py"\ncurl "//example.com/?next=foo/scripts/run.py"\nprintf "%s\\n" "file:foo/scripts/run.py"\nprintf "%s\\n" ~/project/scripts/run.py ~\\project\\scripts\\run.py\n```'
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/parent-relative-safe" > "$test_tmp/parent-relative-safe.json"

make_body_fixture "$test_tmp/unfenced-helper-contexts" $'Run `env MODE=strict ./scripts/run.py`.\n\nLiteral `[helper](scripts/run.py)` code also fails.\n\n    env MODE=strict ./scripts/run.py\n    [helper](scripts/run.py)\n\n```text\nenv MODE=strict ./scripts/run.py\n[helper](scripts/run.py)\n```\n\n~~~python\nprint("scripts/run.py")\n~~~\n\n```\nenv MODE=strict ./scripts/run.py\n```'
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/unfenced-helper-contexts" > "$test_tmp/unfenced-helper-contexts.json"
unfenced_context_exit=$?
set -e
[[ $unfenced_context_exit -eq 1 ]]

make_body_fixture "$test_tmp/unclosed-shell-fence" $'```bash\nPYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/unclosed-shell-fence" > "$test_tmp/unclosed-shell-fence.json"
unclosed_fence_exit=$?
set -e
[[ $unclosed_fence_exit -eq 1 ]]

make_body_fixture "$test_tmp/container-shell-fences" $'> ```bash\n> env MODE=strict scripts/run.py\n> PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"\n> ```\n\n- ~~~Sh\n  ./scripts/run.py\n  <skill-dir>/scripts/run.py\n  ~~~\n\n- > ```shell\n  > scripts/run.py\n  > ```\n\n>     scripts/run.py'
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/container-shell-fences" > "$test_tmp/container-shell-fences.json"
container_fence_exit=$?
set -e
[[ $container_fence_exit -eq 1 ]]

make_body_fixture "$test_tmp/container-blank-lines" $'```bash\nPYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"\n\nPYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"\n```\n\n> ```bash\n> PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"\n>\n> PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"\n> ```\n\n- ```bash\n  PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"\n\n  PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"\n  ```\n\n> - ```bash\n>   PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"\n>\n>   PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"\n>   ```'
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/container-blank-lines" > "$test_tmp/container-blank-lines.json"

for name in blockquote list; do
  if [[ "$name" == blockquote ]]; then
    body=$'> ```bash\n> PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"\n```'
  else
    body=$'- ```bash\n  PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"\n```'
  fi
  make_body_fixture "$test_tmp/container-missing-closer-$name" "$body"
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/container-missing-closer-$name" > "$test_tmp/container-missing-closer-$name.json"
  container_close_exit=$?
  set -e
  [[ $container_close_exit -eq 1 ]]
done

make_body_fixture "$test_tmp/container-boundary-safe" $'> ```text\n> harmless code\nOrdinary prose scripts/run.py\n\n- ~~~text\n  harmless code\nOrdinary prose scripts/run.py'
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/container-boundary-safe" > "$test_tmp/container-boundary-safe.json"

make_body_fixture "$test_tmp/container-boundary-shell" $'> ```bash\n> <skill-dir>/scripts/run.py\nOrdinary prose scripts/run.py'
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/container-boundary-shell" > "$test_tmp/container-boundary-shell.json"
container_boundary_shell_exit=$?
set -e
[[ $container_boundary_shell_exit -eq 1 ]]

make_fixture "$test_tmp/helper-source-bare" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf 'SIBLING = "scripts/child.py"\n' > "$test_tmp/helper-source-bare/scripts/run.py"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/helper-source-bare" > "$test_tmp/helper-source-bare.json"
helper_source_bare_exit=$?
set -e
[[ $helper_source_bare_exit -eq 1 ]]

make_fixture "$test_tmp/helper-source-parent-relative" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf 'SIBLING = "../../scripts/child.py"\nMIXED = "./../scripts/child.py"\nWINDOWS = "..\\\\scripts\\\\child.py"\nMIXED_WINDOWS = "./..\\\\scripts\\\\child.py"\nEMBEDDED = "foo/../scripts/child.py"\nNESTED = "foo/bar/../../scripts/child.py"\nEMBEDDED_WINDOWS = "foo\\\\..\\\\scripts\\\\child.py"\nEMBEDDED_MIXED = "foo/bar\\\\..\\\\../scripts/child.py"\n' > "$test_tmp/helper-source-parent-relative/scripts/run.py"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/helper-source-parent-relative" > "$test_tmp/helper-source-parent-relative.json"
helper_source_parent_exit=$?
set -e
[[ $helper_source_parent_exit -eq 1 ]]

make_fixture "$test_tmp/helper-source-tilde-segments" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf 'SUFFIX = "foo~/./../scripts/child.py"\nPREFIX = "~foo/../scripts/child.py"\nMIDDLE = "foo~bar/../scripts/child.py"\nWINDOWS = "foo~\\\\.\\\\..\\\\scripts\\\\child.py"\nMIXED = "~foo/.\\\\..\\\\scripts/child.py"\n' > "$test_tmp/helper-source-tilde-segments/scripts/run.py"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/helper-source-tilde-segments" > "$test_tmp/helper-source-tilde-segments.json"
helper_source_tilde_exit=$?
set -e
[[ $helper_source_tilde_exit -eq 1 ]]

make_fixture "$test_tmp/helper-source-script-case" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf 'BARE = "Scripts/child.py"\nNESTED = "foo+/ScRiPtS/child.py"\nWINDOWS = "foo+\\\\SCRIPTS\\\\child.py"\nDOT = "foo+/bar/../sCrIpTs\\\\child.py"\nMIXED = "foo+\\\\.\\\\..\\\\Scripts/child.py"\nAMP = "foo&/Scripts/child.py"\nCOMMA = "foo,/Scripts/child.py"\nSEMI = "foo;/Scripts/child.py"\nPAREN = "foo(/Scripts/child.py"\nBRACKET = "foo[/Scripts/child.py"\nBRACE = "foo{/Scripts/child.py"\n# foo,/Scripts/child.py\n# foo,\\\\SCRIPTS\\\\child.py\n# foo,/bar/../sCrIpTs\\\\child.py\n' > "$test_tmp/helper-source-script-case/scripts/run.py"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/helper-source-script-case" > "$test_tmp/helper-source-script-case.json"
helper_source_script_case_exit=$?
set -e

make_fixture "$test_tmp/helper-source-script-substrings" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf 'PLUS = "foo+scripts/child.py"\nAT = "foo@scripts/child.py"\nEQUALS = "foo=scripts/child.py"\nPERCENT = "foo%%scripts/child.py"\nHASH = "foo#scripts/child.py"\nUNDERSCORE = "foo_scripts/child.py"\nJOINED = "fooscripts/child.py"\nAMP = "foo&scripts/child.py"\nCOMMA = "foo,scripts/child.py"\nSEMI = "foo;scripts/child.py"\nPAREN = "foo(scripts/child.py"\nBRACKET = "foo[scripts/child.py"\nBRACE = "foo{scripts/child.py"\n# foo,scripts/child.py\n# foo,Scripts/child.py\n# foo,sCrIpTs\\\\child.py\n' > "$test_tmp/helper-source-script-substrings/scripts/run.py"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/helper-source-script-substrings" > "$test_tmp/helper-source-script-substrings.json"
helper_source_script_substrings_exit=$?
set -e

make_fixture "$test_tmp/helper-source-safe" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
cat > "$test_tmp/helper-source-safe/scripts/run.py" <<'EOF'
SIBLING = "<skill-dir>/scripts/child.py"
WINDOWS_SIBLING = "<skill-dir>\\scripts\\child.py"
DIRECTORY = "scripts/"
DIRECTORIES = ["scripts/"]
CONFIG = {"root": "scripts/"}
MIXED = ['a"b', "scripts/"]
NOTE = ["helper directory: scripts/"]
HELP = "Use scripts/ for helpers"
HOME = "~/project/scripts/child.py"
WINDOWS_HOME = "~\\project\\scripts\\child.py"
# do not use scripts/ for generated files
EOF
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/helper-source-safe" > "$test_tmp/helper-source-safe.json"

make_fixture "$test_tmp/markdown-helper-source" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf 'Helper source mentions scripts/child.py outside Markdown code.\n' > "$test_tmp/markdown-helper-source/scripts/notes.md"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/markdown-helper-source" > "$test_tmp/markdown-helper-source.json"
markdown_helper_exit=$?
set -e
[[ $markdown_helper_exit -eq 1 ]]

make_fixture "$test_tmp/markdown-helper-links-safe" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf '[Existing helper](../scripts/run.py) and [remote query](https://example.com/?next=foo/scripts/run.py).\n' > "$test_tmp/markdown-helper-links-safe/scripts/notes.md"
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/markdown-helper-links-safe" > "$test_tmp/markdown-helper-links-safe.json"

make_fixture "$test_tmp/executable-source-bare" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf '#!/bin/sh\necho scripts/run.py\n' > "$test_tmp/executable-source-bare/run-helper"
chmod +x "$test_tmp/executable-source-bare/run-helper"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/executable-source-bare" > "$test_tmp/executable-source-bare.json"
executable_source_bare_exit=$?
set -e
[[ $executable_source_bare_exit -eq 1 ]]

make_fixture "$test_tmp/executable-source-embedded" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf '#!/bin/sh\necho foo/../scripts/run.py\necho foo\\\\..\\\\scripts\\\\run.py\necho foo/bar\\\\..\\\\../scripts/run.py\necho foo,/Scripts/run.py\necho foo,\\\\SCRIPTS\\\\run.py\necho foo,/bar/../sCrIpTs\\\\run.py\n' > "$test_tmp/executable-source-embedded/run-helper"
chmod +x "$test_tmp/executable-source-embedded/run-helper"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/executable-source-embedded" > "$test_tmp/executable-source-embedded.json"
executable_source_embedded_exit=$?
set -e
[[ $executable_source_embedded_exit -eq 1 ]]

make_fixture "$test_tmp/executable-source-comma-safe" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf '#!/bin/sh\necho foo,scripts/run.py\necho foo,Scripts/run.py\necho foo,sCrIpTs\\\\run.py\n' > "$test_tmp/executable-source-comma-safe/scripts/comma-safe"
chmod +x "$test_tmp/executable-source-comma-safe/scripts/comma-safe"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/executable-source-comma-safe" > "$test_tmp/executable-source-comma-safe.json"
executable_source_comma_safe_exit=$?
set -e

make_fixture "$test_tmp/generic-config-safe" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf '{"helper":"scripts/run.py"}\n' > "$test_tmp/generic-config-safe/config.json"
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/generic-config-safe" > "$test_tmp/generic-config-safe.json"

make_fixture "$test_tmp/portable-fixture" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/portable-fixture" > "$test_tmp/portable.json"

fake_bin="$test_tmp/fake-bin"
portable_resolved="$(cd "$test_tmp/portable-fixture" && pwd -P)"
node "$root/scripts/hash-tree.mjs" "$test_tmp/portable-fixture" > "$test_tmp/portable-before-official.json"
mkdir -p "$fake_bin"
cat > "$fake_bin/skills-ref" <<'PY'
#!/usr/bin/env python3
import os
from pathlib import Path
import sys
import time

Path(os.environ["SKILLS_REF_LOG"]).write_text("\n".join(sys.argv[1:]) + "\n", encoding="utf-8")
mode = os.environ["SKILLS_REF_MODE"]
if mode == "timeout":
    time.sleep(5)
sys.exit({"pass": 0, "fail": 1, "unexpected": 7}.get(mode, 0))
PY
chmod +x "$fake_bin/skills-ref"
for mode in pass fail unexpected timeout; do
  set +e
  PATH="$fake_bin:$PATH" SKILLS_REF_MODE="$mode" SKILLS_REF_LOG="$test_tmp/skills-ref-$mode.log" \
    PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/portable-fixture" > "$test_tmp/skills-ref-$mode.json"
  official_exit=$?
  set -e
  if [[ "$mode" == pass ]]; then
    [[ $official_exit -eq 0 ]]
    printf 'validate\n%s\n' "$portable_resolved" | cmp - "$test_tmp/skills-ref-$mode.log"
  else
    [[ $official_exit -eq 1 ]]
  fi
done
node "$root/scripts/hash-tree.mjs" "$test_tmp/portable-fixture" > "$test_tmp/portable-after-official.json"
cmp "$test_tmp/portable-before-official.json" "$test_tmp/portable-after-official.json"

make_fixture "$test_tmp/sidecar-fixture" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
mkdir -p "$test_tmp/sidecar-fixture/agents" "$test_tmp/sidecar-fixture/assets"
printf '<svg/>\n' > "$test_tmp/sidecar-fixture/assets/small.svg"
printf 'large\n' > "$test_tmp/sidecar-fixture/assets/large.png"
cat > "$test_tmp/sidecar-fixture/agents/openai.yaml" <<'EOF'
interface: # UI fields
  display_name: "Sidecar # Fixture" # picker label
  short_description: "Validate an explicit-only sidecar" # concise label
  icon_small: "./assets/small.svg" # small icon
  icon_large: "./assets/large.png" # large icon
  brand_color: "#3B82F6" # quoted hash stays content
  default_prompt: "Use $sidecar-fixture to run the fixture." # optional prompt
policy: # invocation policy
  allow_implicit_invocation: false # explicit only
dependencies: # target tools
  tools: # MCP tools
    - type: "mcp" # supported type
      value: "openaiDeveloperDocs" # tool name
      description: "OpenAI Docs # MCP server" # quoted hash stays content
      transport: "streamable_http" # transport
      url: "https://developers.openai.com/mcp#skills" # URL fragment
EOF
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/sidecar-fixture" > "$test_tmp/sidecar.json"

for name in sidecar-directory sidecar-direct-symlink sidecar-ancestor-symlink sidecar-fifo sidecar-ancestor-file sidecar-ancestor-fifo; do
  make_fixture "$test_tmp/$name" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
done
mkdir -p "$test_tmp/sidecar-directory/agents/openai.yaml" "$test_tmp/external-sidecar"
cp "$root/README.md" "$test_tmp/external-sidecar/openai.yaml"
mkdir -p "$test_tmp/sidecar-direct-symlink/agents"
ln -s "$test_tmp/external-sidecar/openai.yaml" "$test_tmp/sidecar-direct-symlink/agents/openai.yaml"
ln -s "$test_tmp/external-sidecar" "$test_tmp/sidecar-ancestor-symlink/agents"
mkdir -p "$test_tmp/sidecar-fifo/agents"
mkfifo "$test_tmp/sidecar-fifo/agents/openai.yaml"
printf 'not a directory\n' > "$test_tmp/sidecar-ancestor-file/agents"
mkfifo "$test_tmp/sidecar-ancestor-fifo/agents"
for name in sidecar-directory sidecar-direct-symlink sidecar-ancestor-symlink sidecar-ancestor-file; do
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/$name" > "$test_tmp/$name.json"
  sidecar_entry_exit=$?
  set -e
  if [[ $sidecar_entry_exit -ne 1 ]]; then
    echo "FAIL: $name exited $sidecar_entry_exit instead of structured validation exit 1" >&2
    exit 1
  fi
done
run_bounded_sidecar() {
  PYTHONDONTWRITEBYTECODE=1 python3 -B - "$validator" "$1" <<'PY'
import subprocess
import sys

try:
    result = subprocess.run(
        [sys.executable, "-B", sys.argv[1], "--json", sys.argv[2]],
        capture_output=True,
        text=True,
        timeout=2,
    )
except subprocess.TimeoutExpired:
    raise SystemExit(124)
sys.stdout.write(result.stdout)
raise SystemExit(result.returncode)
PY
}
for name in sidecar-fifo sidecar-ancestor-fifo; do
  set +e
  run_bounded_sidecar "$test_tmp/$name" > "$test_tmp/$name.json"
  sidecar_fifo_exit=$?
  set -e
  if [[ $sidecar_fifo_exit -ne 1 ]]; then
    echo "FAIL: $name exited $sidecar_fifo_exit instead of bounded validation exit 1" >&2
    exit 1
  fi
done

make_fixture "$test_tmp/invalid-utf8-sidecar" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
mkdir -p "$test_tmp/invalid-utf8-sidecar/agents"
printf '\377\n' > "$test_tmp/invalid-utf8-sidecar/agents/openai.yaml"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/invalid-utf8-sidecar" > "$test_tmp/invalid-utf8-sidecar.json"
invalid_utf8_sidecar_exit=$?
set -e
if [[ $invalid_utf8_sidecar_exit -ne 1 ]]; then
  echo "FAIL: invalid UTF-8 sidecar exited $invalid_utf8_sidecar_exit instead of 1" >&2
  exit 1
fi

for name in policy-only dependencies-only display-only brand-only prompt-only blank-sidecar comment-only-sidecar; do
  make_fixture "$test_tmp/$name" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
  mkdir -p "$test_tmp/$name/agents"
done
cat > "$test_tmp/policy-only/agents/openai.yaml" <<'EOF'
policy:
  allow_implicit_invocation: false
EOF
cat > "$test_tmp/dependencies-only/agents/openai.yaml" <<'EOF'
dependencies:
  tools:
    - type: "mcp"
      value: "openaiDeveloperDocs"
EOF
cat > "$test_tmp/display-only/agents/openai.yaml" <<'EOF'
interface:
  display_name: "Display Only"
EOF
cat > "$test_tmp/brand-only/agents/openai.yaml" <<'EOF'
interface:
  brand_color: "#3B82F6"
EOF
cat > "$test_tmp/prompt-only/agents/openai.yaml" <<'EOF'
interface:
  default_prompt: "Use $prompt-only to run this task."
EOF
: > "$test_tmp/blank-sidecar/agents/openai.yaml"
printf '# no semantic section\n' > "$test_tmp/comment-only-sidecar/agents/openai.yaml"
for name in policy-only dependencies-only display-only brand-only prompt-only blank-sidecar comment-only-sidecar; do
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/$name" > "$test_tmp/$name.json"
  set -e
done

for name in policy-only dependencies-only display-only brand-only prompt-only; do
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --creation-mode --warnings-as-errors "$test_tmp/$name" > "$test_tmp/creation-$name.json"
  creation_partial_exit=$?
  set -e
  [[ $creation_partial_exit -eq 1 ]]
done
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --creation-mode --warnings-as-errors "$test_tmp/sidecar-fixture" > "$test_tmp/creation-full-sidecar.json"
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --creation-mode --warnings-as-errors "$test_tmp/portable-fixture" > "$test_tmp/creation-no-sidecar.json"

make_fixture "$test_tmp/policy-case-fixture" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
mkdir -p "$test_tmp/policy-case-fixture/agents"
cat > "$test_tmp/policy-case-fixture/agents/openai.yaml" <<'EOF'
interface:
  display_name: "Policy Case"
  short_description: "Reject a non-lowercase policy boolean"
policy:
  allow_implicit_invocation: True # YAML bool, outside bounded Codex shape
EOF
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/policy-case-fixture" > "$test_tmp/policy-case.json"
policy_case_exit=$?
set -e
[[ $policy_case_exit -eq 1 ]]

for name in empty-interface empty-interface-value empty-policy empty-dependencies empty-tools duplicate-sidecar duplicate-tools; do
  make_fixture "$test_tmp/$name" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
  mkdir -p "$test_tmp/$name/agents"
done

for name in long-display long-prompt outside-icon token-boundary invalid-sidecar-string; do
  make_fixture "$test_tmp/$name" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
  mkdir -p "$test_tmp/$name/agents"
done
printf 'interface:\n  display_name: "%065d"\n  short_description: "Reject an overlong display name"\n' 0 > "$test_tmp/long-display/agents/openai.yaml"
{
  printf '%s\n' 'interface:' '  display_name: "Long Prompt"' '  short_description: "Reject an overlong default prompt"'
  printf '  default_prompt: "Use $long-prompt %01025d"\n' 0
} > "$test_tmp/long-prompt/agents/openai.yaml"
mkdir -p "$test_tmp/outside-icon/images"
printf '<svg/>\n' > "$test_tmp/outside-icon/images/icon.svg"
cat > "$test_tmp/outside-icon/agents/openai.yaml" <<'EOF'
interface:
  display_name: "Outside Icon"
  short_description: "Reject an icon outside assets"
  icon_small: "./images/icon.svg"
EOF
cat > "$test_tmp/token-boundary/agents/openai.yaml" <<'EOF'
interface:
  display_name: "Token Boundary"
  short_description: "Reject a partial skill-name token"
  default_prompt: "Use $token-boundary-extra for this task."
EOF
cat > "$test_tmp/invalid-sidecar-string/agents/openai.yaml" <<'EOF'
interface:
  display_name: "Invalid\qEscape"
  short_description: "Reject an invalid quoted escape"
EOF
for name in long-display long-prompt outside-icon token-boundary invalid-sidecar-string; do
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/$name" > "$test_tmp/$name.json"
  sidecar_bound_exit=$?
  set -e
  [[ $sidecar_bound_exit -eq 1 ]]
done
printf 'interface:\n' > "$test_tmp/empty-interface/agents/openai.yaml"
printf 'interface:\n  brand_color: ""\n' > "$test_tmp/empty-interface-value/agents/openai.yaml"
printf 'policy:\n' > "$test_tmp/empty-policy/agents/openai.yaml"
printf 'dependencies:\n' > "$test_tmp/empty-dependencies/agents/openai.yaml"
printf 'dependencies:\n  tools:\n' > "$test_tmp/empty-tools/agents/openai.yaml"
cat > "$test_tmp/duplicate-sidecar/agents/openai.yaml" <<'EOF'
interface:
  display_name: "Duplicate Sidecar"
  short_description: "Reject duplicate sidecar policy keys"
policy:
  allow_implicit_invocation: true
  allow_implicit_invocation: false
EOF
cat > "$test_tmp/duplicate-tools/agents/openai.yaml" <<'EOF'
interface:
  display_name: "Duplicate Tools"
  short_description: "Reject duplicate dependency lists"
dependencies:
  tools:
  tools:
EOF
for name in empty-interface empty-interface-value empty-policy empty-dependencies empty-tools duplicate-sidecar duplicate-tools; do
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/$name" > "$test_tmp/$name.json"
  sidecar_edge_exit=$?
  set -e
  [[ $sidecar_edge_exit -eq 1 ]]
done

make_fixture "$test_tmp/minimal-sidecar-fixture" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
mkdir -p "$test_tmp/minimal-sidecar-fixture/agents"
cat > "$test_tmp/minimal-sidecar-fixture/agents/openai.yaml" <<'EOF'
interface:
  display_name: "Minimal Sidecar"
  short_description: "Validate a minimal Codex sidecar"
EOF
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/minimal-sidecar-fixture" > "$test_tmp/minimal-sidecar.json"

for name in whitespace-display whitespace-short; do
  make_fixture "$test_tmp/$name" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
  mkdir -p "$test_tmp/$name/agents"
done
cat > "$test_tmp/whitespace-display/agents/openai.yaml" <<'EOF'
interface:
  display_name: "                         "
  short_description: "Reject a whitespace-only display name"
EOF
cat > "$test_tmp/whitespace-short/agents/openai.yaml" <<'EOF'
interface:
  display_name: "Whitespace Short"
  short_description: "                         "
EOF
for name in whitespace-display whitespace-short; do
  for mode in general creation; do
    set +e
    if [[ $mode == creation ]]; then
      PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --creation-mode "$test_tmp/$name" > "$test_tmp/$mode-$name.json"
    else
      PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/$name" > "$test_tmp/$mode-$name.json"
    fi
    whitespace_sidecar_exit=$?
    set -e
    [[ $whitespace_sidecar_exit -eq 1 ]]
  done
done

make_fixture "$test_tmp/whitespace-dependency" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
mkdir -p "$test_tmp/whitespace-dependency/agents"
cat > "$test_tmp/whitespace-dependency/agents/openai.yaml" <<'EOF'
interface:
  display_name: "Whitespace Dependency"
  short_description: "Reject a blank MCP dependency value"
dependencies:
  tools:
    - type: "mcp"
      value: " "
EOF
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --creation-mode "$test_tmp/whitespace-dependency" > "$test_tmp/whitespace-dependency.json"
whitespace_dependency_exit=$?
set -e
[[ $whitespace_dependency_exit -eq 1 ]]

make_fixture "$test_tmp/bad-prompt-fixture" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
mkdir -p "$test_tmp/bad-prompt-fixture/agents"
cat > "$test_tmp/bad-prompt-fixture/agents/openai.yaml" <<'EOF'
interface:
  display_name: "Bad Prompt"
  short_description: "Reject a stale default prompt value"
  default_prompt: "Run the fixture. Then summarize it."
EOF
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/bad-prompt-fixture" > "$test_tmp/bad-prompt.json"
bad_prompt_exit=$?
set -e
[[ $bad_prompt_exit -eq 1 ]]

make_fixture "$test_tmp/missing-icon-fixture" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
mkdir -p "$test_tmp/missing-icon-fixture/agents"
cat > "$test_tmp/missing-icon-fixture/agents/openai.yaml" <<'EOF'
interface:
  display_name: "Missing Icon"
  short_description: "Reject a missing sidecar icon"
  icon_small: "./assets/missing.svg"
  default_prompt: "Use $missing-icon-fixture to run the fixture."
EOF
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/missing-icon-fixture" > "$test_tmp/missing-icon.json"
missing_icon_exit=$?
set -e
[[ $missing_icon_exit -eq 1 ]]

for name in exact-case-icon file-case-icon directory-case-icon symlink-icon symlink-loop-icon; do
  make_fixture "$test_tmp/$name" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
  mkdir -p "$test_tmp/$name/agents" "$test_tmp/$name/assets/Icons"
  printf '<svg/>\n' > "$test_tmp/$name/assets/Icons/Small.svg"
done
cat > "$test_tmp/exact-case-icon/agents/openai.yaml" <<'EOF'
interface:
  display_name: "Exact Case Icon"
  short_description: "Accept exact icon path component casing"
  icon_small: "./assets/Icons/Small.svg"
EOF
cat > "$test_tmp/file-case-icon/agents/openai.yaml" <<'EOF'
interface:
  display_name: "File Case Icon"
  short_description: "Reject mismatched icon file casing"
  icon_small: "./assets/Icons/small.svg"
EOF
cat > "$test_tmp/directory-case-icon/agents/openai.yaml" <<'EOF'
interface:
  display_name: "Directory Case Icon"
  short_description: "Reject mismatched icon directory casing"
  icon_small: "./assets/icons/Small.svg"
EOF
ln -s "Icons/Small.svg" "$test_tmp/symlink-icon/assets/icon.svg"
cat > "$test_tmp/symlink-icon/agents/openai.yaml" <<'EOF'
interface:
  display_name: "Symlink Icon"
  short_description: "Keep a contained icon symlink valid"
  icon_small: "./assets/icon.svg"
EOF
ln -s "loop.svg" "$test_tmp/symlink-loop-icon/assets/loop.svg"
cat > "$test_tmp/symlink-loop-icon/agents/openai.yaml" <<'EOF'
interface:
  display_name: "Symlink Loop Icon"
  short_description: "Keep an icon loop as a package symlink issue"
  icon_small: "./assets/loop.svg"
EOF
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/exact-case-icon" > "$test_tmp/exact-case-icon.json"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/symlink-icon" > "$test_tmp/symlink-icon.json"
symlink_icon_exit=$?
set -e
[[ $symlink_icon_exit -eq 1 ]]
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/symlink-loop-icon" > "$test_tmp/symlink-loop-icon.json"
symlink_loop_icon_exit=$?
set -e
[[ $symlink_loop_icon_exit -eq 1 ]]
if [[ -n "$python39" ]]; then
  set +e
  PYTHONDONTWRITEBYTECODE=1 "$python39" -B "$validator" --json "$test_tmp/symlink-loop-icon" > "$test_tmp/symlink-loop-icon-python39.json"
  symlink_loop_python39_exit=$?
  set -e
  [[ $symlink_loop_python39_exit -eq 1 ]]
else
  cp "$test_tmp/symlink-loop-icon.json" "$test_tmp/symlink-loop-icon-python39.json"
fi
for name in file-case-icon directory-case-icon; do
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/$name" > "$test_tmp/$name.json"
  icon_case_exit=$?
  set -e
  [[ $icon_case_exit -eq 1 ]]
done

make_fixture "$test_tmp/titled-link-fixture" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
mkdir -p "$test_tmp/titled-link-fixture/references"
printf '# Guide\n' > "$test_tmp/titled-link-fixture/references/guide.md"
printf '\n[Guide](references/guide.md "Read the guide")\n' >> "$test_tmp/titled-link-fixture/SKILL.md"
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/titled-link-fixture" > "$test_tmp/titled-link.json"

make_fixture "$test_tmp/reference-link-fixture" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
mkdir -p "$test_tmp/reference-link-fixture/references"
printf '# Guide\n' > "$test_tmp/reference-link-fixture/references/guide.md"
cat >> "$test_tmp/reference-link-fixture/SKILL.md" <<'EOF'

[Guide][guide]

   [guide]: <references/guide.md> "Read the guide"
EOF
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/reference-link-fixture" > "$test_tmp/reference-link.json"

make_fixture "$test_tmp/reference-whitespace-fixture" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
mkdir -p "$test_tmp/reference-whitespace-fixture/references"
printf '# Guide\n' > "$test_tmp/reference-whitespace-fixture/references/guide.md"
cat >> "$test_tmp/reference-whitespace-fixture/SKILL.md" <<'EOF'

[Spaces][GUIDE link]
[Tabs][tab label]

   [guide  link]: <references/guide.md> "Collapsed spaces"
EOF
printf '   [tab\t\tlabel]: <references/guide.md> "Collapsed tabs"\n' >> "$test_tmp/reference-whitespace-fixture/SKILL.md"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/reference-whitespace-fixture" > "$test_tmp/reference-whitespace.json"
reference_whitespace_exit=$?
set -e

for name in exact-case-links case-mismatch-links; do
  make_fixture "$test_tmp/$name" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
  mkdir -p "$test_tmp/$name/references" "$test_tmp/$name/Examples"
  printf '# Guide\n' > "$test_tmp/$name/references/Guide.md"
done
printf '\n[Guide](references/Guide.md), [examples](Examples/), and [anchor](#fixture).\n' >> "$test_tmp/exact-case-links/SKILL.md"
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/exact-case-links" > "$test_tmp/exact-case-links.json"
printf '\n[Guide](References/Guide.md) and [examples](examples/).\n' >> "$test_tmp/case-mismatch-links/SKILL.md"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/case-mismatch-links" > "$test_tmp/case-mismatch-links.json"
case_mismatch_links_exit=$?
set -e

make_fixture "$test_tmp/symlink-loop-link" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
ln -s loop "$test_tmp/symlink-loop-link/loop"
printf '\n[Loop](loop/guide.md).\n' >> "$test_tmp/symlink-loop-link/SKILL.md"
link_python="${python39:-$(command -v python3)}"
set +e
PYTHONDONTWRITEBYTECODE=1 "$link_python" -B "$validator" --json "$test_tmp/symlink-loop-link" > "$test_tmp/symlink-loop-link.json" 2> "$test_tmp/symlink-loop-link.stderr"
symlink_loop_exit=$?
set -e
if [[ $symlink_loop_exit -ne 1 || ! -s "$test_tmp/symlink-loop-link.json" || -s "$test_tmp/symlink-loop-link.stderr" ]]; then
  printf 'FAIL: symlink-loop link did not remain a structured package failure\n' >&2
  cat "$test_tmp/symlink-loop-link.stderr" >&2
  exit 1
fi

for name in malformed-http-destination malformed-file-destination uri-destination-controls; do
  make_fixture "$test_tmp/$name" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
done
printf '\n[Malformed HTTP](http://[)\n' >> "$test_tmp/malformed-http-destination/SKILL.md"
printf '\n[Malformed file](file://[)\n' >> "$test_tmp/malformed-file-destination/SKILL.md"
printf '\n[Remote](https://example.com/docs) and [local](scripts/run.py).\n' >> "$test_tmp/uri-destination-controls/SKILL.md"
for name in malformed-http-destination malformed-file-destination; do
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/$name" > "$test_tmp/$name.json" 2> "$test_tmp/$name.stderr"
  malformed_uri_exit=$?
  set -e
  if [[ $malformed_uri_exit -ne 1 || -s "$test_tmp/$name.stderr" || ! -s "$test_tmp/$name.json" ]]; then
    printf 'FAIL: malformed URI %s did not produce stable JSON validation exit 1\n' "$name" >&2
    cat "$test_tmp/$name.stderr" >&2
    exit 1
  fi
done
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/uri-destination-controls" > "$test_tmp/uri-destination-controls.json"

make_fixture "$test_tmp/missing-reference-fixture" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf '\n [unused]: missing.md "Missing guide"\n' >> "$test_tmp/missing-reference-fixture/SKILL.md"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/missing-reference-fixture" > "$test_tmp/missing-reference.json"
missing_reference_exit=$?
set -e
[[ $missing_reference_exit -eq 1 ]]

make_fixture "$test_tmp/escaping-reference-fixture" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf '\n[escape]: <../outside.md> (Escape)\n' >> "$test_tmp/escaping-reference-fixture/SKILL.md"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/escaping-reference-fixture" > "$test_tmp/escaping-reference.json"
escaping_reference_exit=$?
set -e
[[ $escaping_reference_exit -eq 1 ]]

make_fixture "$test_tmp/encoded-absolute-link" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf '\n[Encoded escape](%%2Fetc/passwd)\n' >> "$test_tmp/encoded-absolute-link/SKILL.md"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/encoded-absolute-link" > "$test_tmp/encoded-absolute-link.json"
encoded_absolute_exit=$?
set -e
[[ $encoded_absolute_exit -eq 1 ]]

make_fixture "$test_tmp/indented-code-reference" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf '\n    [code-only]: missing.md "Indented code, not a definition"\n' >> "$test_tmp/indented-code-reference/SKILL.md"
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/indented-code-reference" > "$test_tmp/indented-code-reference.json"

for reserved in claude-helper anthropic-helper; do
  make_fixture "$test_tmp/$reserved" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/$reserved" > "$test_tmp/$reserved.json"
  reserved_exit=$?
  set -e
  [[ $reserved_exit -eq 1 ]]
done

for name in list-description quoted-description; do
  mkdir -p "$test_tmp/$name"
done
cat > "$test_tmp/list-description/SKILL.md" <<'EOF'
---
name: "list-description"
description: [one, two]
---

# Collection description
EOF
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/list-description" > "$test_tmp/list-description.json"
list_description_exit=$?
set -e
[[ $list_description_exit -eq 1 ]]
cat > "$test_tmp/quoted-description/SKILL.md" <<'EOF'
---
name: "quoted-description"
description: "[one, two]"
---

# Quoted description
EOF
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/quoted-description" > "$test_tmp/quoted-description.json"

for name in angle-less-than-description angle-greater-than-description angle-safe-description; do
  mkdir -p "$test_tmp/$name"
done
cat > "$test_tmp/angle-less-than-description/SKILL.md" <<'EOF'
---
name: "angle-less-than-description"
description: "Use when processing <tag input."
---

# Less-than description
EOF
cat > "$test_tmp/angle-greater-than-description/SKILL.md" <<'EOF'
---
name: "angle-greater-than-description"
description: "Use when processing tag> input."
---

# Greater-than description
EOF
cat > "$test_tmp/angle-safe-description/SKILL.md" <<'EOF'
---
name: "angle-safe-description"
description: "Use when processing ordinary tagged input."
---

# Safe description
EOF
python_bin="$(python3 -c 'import os, sys; print(os.path.realpath(sys.executable))')"
[[ "$python_bin" == /* && -x "$python_bin" ]]
mkdir -p "$test_tmp/no-skills-ref-bin"
cat > "$test_tmp/no-skills-ref-bin/python3" <<'EOF'
#!/usr/bin/env bash
exit 97
EOF
chmod +x "$test_tmp/no-skills-ref-bin/python3"
[[ "$(PATH="$test_tmp/no-skills-ref-bin:$PATH" command -v python3)" == "$test_tmp/no-skills-ref-bin/python3" ]]
for name in angle-less-than-description angle-greater-than-description; do
  set +e
  PATH="$test_tmp/no-skills-ref-bin" PYTHONDONTWRITEBYTECODE=1 "$python_bin" -B "$validator" --json "$test_tmp/$name" > "$test_tmp/$name.json"
  angle_exit=$?
  set -e
  [[ $angle_exit -eq 1 ]]
done
PATH="$test_tmp/no-skills-ref-bin" PYTHONDONTWRITEBYTECODE=1 "$python_bin" -B "$validator" --json "$test_tmp/angle-safe-description" > "$test_tmp/angle-safe-description.json"

for name in surrogate-high-description surrogate-low-description surrogate-pair-metadata-value surrogate-pair-metadata-key; do
  mkdir -p "$test_tmp/$name"
done
cat > "$test_tmp/surrogate-high-description/SKILL.md" <<'EOF'
---
name: "surrogate-high-description"
description: "Reject a lone high surrogate \ud800 escape."
---

# High surrogate
EOF
cat > "$test_tmp/surrogate-low-description/SKILL.md" <<'EOF'
---
name: "surrogate-low-description"
description: "Reject a lone low surrogate \udc00 escape."
---

# Low surrogate
EOF
cat > "$test_tmp/surrogate-pair-metadata-value/SKILL.md" <<'EOF'
---
name: "surrogate-pair-metadata-value"
description: "Reject surrogate escapes in portable metadata values."
metadata:
  "emoji": "\ud83d\ude00"
---

# Surrogate pair metadata value
EOF
cat > "$test_tmp/surrogate-pair-metadata-key/SKILL.md" <<'EOF'
---
name: "surrogate-pair-metadata-key"
description: "Reject surrogate escapes in portable metadata keys."
metadata:
  "\ud83d\ude00": "emoji"
---

# Surrogate pair metadata key
EOF
make_fixture "$test_tmp/surrogate-pair-sidecar" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
mkdir -p "$test_tmp/surrogate-pair-sidecar/agents"
cat > "$test_tmp/surrogate-pair-sidecar/agents/openai.yaml" <<'EOF'
interface:
  display_name: "Surrogate \ud83d\ude00"
  short_description: "Reject escaped surrogate pairs here."
EOF
surrogate_exits=()
for name in surrogate-high-description surrogate-low-description surrogate-pair-metadata-value surrogate-pair-metadata-key surrogate-pair-sidecar; do
  set +e
  PATH="$test_tmp/no-skills-ref-bin" PYTHONDONTWRITEBYTECODE=1 "$python_bin" -B "$validator" --json "$test_tmp/$name" > "$test_tmp/$name.json"
  surrogate_exits+=("$?")
  set -e
done
if [[ "${surrogate_exits[*]}" != "1 1 1 1 1" ]]; then
  printf 'FAIL: YAML-invalid surrogate escapes passed: %s\n' "${surrogate_exits[*]}" >&2
  exit 1
fi

mkdir -p "$test_tmp/unicode-safe/agents"
cat > "$test_tmp/unicode-safe/SKILL.md" <<'EOF'
---
name: "unicode-safe"
description: "Create a portable skill with literal Unicode 😀 content."
metadata:
  "emoji": "😀"
  "literal_escape": "\\ud800"
---

# Unicode-safe skill
EOF
cat > "$test_tmp/unicode-safe/agents/openai.yaml" <<'EOF'
interface:
  display_name: "Unicode 😀"
  short_description: "Create a Unicode-safe skill package."
EOF
PATH="$test_tmp/no-skills-ref-bin" PYTHONDONTWRITEBYTECODE=1 "$python_bin" -B "$validator" --creation-mode --warnings-as-errors --json "$test_tmp/unicode-safe" > "$test_tmp/unicode-safe.json"

for name in nonprintable-description nonprintable-metadata-key nonprintable-metadata-value nonprintable-hermes nonprintable-sidecar; do
  mkdir -p "$test_tmp/$name"
done
{
  printf '%s\n' '---' 'name: "nonprintable-description"'
  printf 'description: "Reject literal DEL \177 in canonical text."\n'
  printf '%s\n' '---' '' '# Nonprintable description'
} > "$test_tmp/nonprintable-description/SKILL.md"
cat > "$test_tmp/nonprintable-metadata-key/SKILL.md" <<'EOF'
---
name: "nonprintable-metadata-key"
description: "Reject a nonprintable portable metadata key."
metadata:
  "\u0080": "bad key"
---

# Nonprintable metadata key
EOF
cat > "$test_tmp/nonprintable-metadata-value/SKILL.md" <<'EOF'
---
name: "nonprintable-metadata-value"
description: "Reject a nonprintable portable metadata value."
metadata:
  "owner": "\u009f"
---

# Nonprintable metadata value
EOF
cat > "$test_tmp/nonprintable-hermes/SKILL.md" <<'EOF'
---
name: "nonprintable-hermes"
description: "Reject a nonprintable Hermes configuration value."
metadata:
  hermes:
    config:
      - key: "wiki.enabled"
        description: "\u000b"
---

# Nonprintable Hermes value
EOF
cat > "$test_tmp/nonprintable-sidecar/SKILL.md" <<'EOF'
---
name: "nonprintable-sidecar"
description: "Reject a nonprintable OpenAI sidecar value."
---

# Nonprintable sidecar value
EOF
mkdir -p "$test_tmp/nonprintable-sidecar/agents"
cat > "$test_tmp/nonprintable-sidecar/agents/openai.yaml" <<'EOF'
interface:
  display_name: "\uffff"
  short_description: "Reject a nonprintable sidecar value."
EOF
nonprintable_exits=()
for name in nonprintable-description nonprintable-metadata-key nonprintable-metadata-value nonprintable-sidecar; do
  set +e
  PATH="$test_tmp/no-skills-ref-bin" PYTHONDONTWRITEBYTECODE=1 "$python_bin" -B "$validator" --json "$test_tmp/$name" > "$test_tmp/$name.json"
  nonprintable_exits+=("$?")
  set -e
done
set +e
PATH="$test_tmp/no-skills-ref-bin" PYTHONDONTWRITEBYTECODE=1 "$python_bin" -B "$validator" --allow-hermes-metadata --json "$test_tmp/nonprintable-hermes" > "$test_tmp/nonprintable-hermes.json"
nonprintable_exits+=("$?")
set -e
if [[ "${nonprintable_exits[*]}" != "1 1 1 1 1" ]]; then
  printf 'FAIL: YAML-nonprintable canonical strings passed: %s\n' "${nonprintable_exits[*]}" >&2
  exit 1
fi

mkdir -p "$test_tmp/yaml-printable-controls"
cat > "$test_tmp/yaml-printable-controls/SKILL.md" <<'EOF'
---
name: "yaml-printable-controls"
description: "Preserve printable YAML scalar controls and Unicode."
metadata:
  "tab_and_breaks": "\t\n\r"
  "nel_nbsp": "\u0085\u00a0"
  "bmp_astral": "Ω😀"
---

# YAML printable controls
EOF
PATH="$test_tmp/no-skills-ref-bin" PYTHONDONTWRITEBYTECODE=1 "$python_bin" -B "$validator" --json --warnings-as-errors "$test_tmp/yaml-printable-controls" > "$test_tmp/yaml-printable-controls.json"

nel=$(printf '\302\205')
line_separator=$(printf '\342\200\250')
paragraph_separator=$(printf '\342\200\251')
mkdir -p "$test_tmp/yaml-printable-literals/agents"
printf -- '---\nname: "yaml-printable-literals"\ndescription: "Preserve literal %s %s %s YAML printable text."\nmetadata:\n  "controls": "%s%s%s"\n---\n\n# YAML printable literals\n' "$nel" "$line_separator" "$paragraph_separator" "$nel" "$line_separator" "$paragraph_separator" > "$test_tmp/yaml-printable-literals/SKILL.md"
printf 'interface:\n  display_name: "Literal %s %s %s"\n  short_description: "Preserve literal YAML printable Unicode."\n' "$nel" "$line_separator" "$paragraph_separator" > "$test_tmp/yaml-printable-literals/agents/openai.yaml"
PATH="$test_tmp/no-skills-ref-bin" PYTHONDONTWRITEBYTECODE=1 "$python_bin" -B "$validator" --creation-mode --max-skill-lines 10 --json --warnings-as-errors "$test_tmp/yaml-printable-literals" > "$test_tmp/yaml-printable-literals.json"

mkdir -p "$test_tmp/yaml-physical-lines/agents"
printf '%s\r\n' '---' 'name: "yaml-physical-lines"' 'description: "Preserve CRLF physical lines in canonical frontmatter."' '---' '' '# YAML physical lines' > "$test_tmp/yaml-physical-lines/SKILL.md"
printf '%s\r' 'interface:' '  display_name: "Physical lines"' '  short_description: "Preserve CR physical lines in a sidecar."' > "$test_tmp/yaml-physical-lines/agents/openai.yaml"
PATH="$test_tmp/no-skills-ref-bin" PYTHONDONTWRITEBYTECODE=1 "$python_bin" -B "$validator" --creation-mode --json --warnings-as-errors "$test_tmp/yaml-physical-lines" > "$test_tmp/yaml-physical-lines.json"

mkdir -p "$test_tmp/unquoted-date-description" "$test_tmp/quoted-name" "$test_tmp/portable-metadata-sequence" "$test_tmp/portable-hermes-sequence" "$test_tmp/hermes-config-sequence" "$test_tmp/hermes-child-sequence" "$test_tmp/unquoted-portable-metadata" "$test_tmp/quoted-portable-metadata-keys"
cat > "$test_tmp/unquoted-date-description/SKILL.md" <<'EOF'
---
name: "unquoted-date-description"
description: 2026-08-13
---

# Unquoted date
EOF
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/unquoted-date-description" > "$test_tmp/unquoted-date-description.json"
unquoted_date_exit=$?
set -e
cat > "$test_tmp/quoted-name/SKILL.md" <<'EOF'
---
name: "quoted-name"
description: "Accept a quoted name in the canonical generated subset."
---

# Quoted name
EOF
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/quoted-name" > "$test_tmp/quoted-name.json"

name_forms=(ordinary-name true null 123 2026-08-14)
unquoted_name_exits=()
quoted_name_exits=()
for skill_name in "${name_forms[@]}"; do
  mkdir -p "$test_tmp/name-forms/$skill_name"
  printf -- '---\nname: %s\ndescription: "Reject every unquoted name in the canonical generated subset."\n---\n\n# Name form\n' "$skill_name" > "$test_tmp/name-forms/$skill_name/SKILL.md"
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/name-forms/$skill_name" > "$test_tmp/unquoted-name-$skill_name.json"
  unquoted_name_exits+=("$?")
  set -e
  printf -- '---\nname: "%s"\ndescription: "Accept JSON-double-quoted names before applying slug and directory checks."\n---\n\n# Name form\n' "$skill_name" > "$test_tmp/name-forms/$skill_name/SKILL.md"
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/name-forms/$skill_name" > "$test_tmp/quoted-name-$skill_name.json"
  quoted_name_exits+=("$?")
  set -e
done
if [[ "${unquoted_name_exits[*]}" != "1 1 1 1 1" || "${quoted_name_exits[*]}" != "0 0 0 0 0" || $outside_executable_exit -ne 1 || $outside_shebang_exit -ne 1 || $outside_data_exit -ne 0 ]]; then
  printf 'FAIL: canonical name/location RED unquoted=%s quoted=%s outside=%s/%s data=%s\n' "${unquoted_name_exits[*]}" "${quoted_name_exits[*]}" "$outside_executable_exit" "$outside_shebang_exit" "$outside_data_exit" >&2
  exit 1
fi
cat > "$test_tmp/portable-metadata-sequence/SKILL.md" <<'EOF'
---
name: "portable-metadata-sequence"
description: "Reject a sequence where portable metadata requires a mapping."
metadata:
  - owner: "toolboxmd"
---

# Portable metadata sequence
EOF
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/portable-metadata-sequence" > "$test_tmp/portable-metadata-sequence.json"
portable_metadata_sequence_exit=$?
set -e
cat > "$test_tmp/portable-hermes-sequence/SKILL.md" <<'EOF'
---
name: "portable-hermes-sequence"
description: "Reject a sequence marker at the Hermes metadata level."
metadata:
  - hermes:
    config:
      - key: "wiki.path"
        description: "Path to the main wiki"
---

# Portable Hermes sequence
EOF
cat > "$test_tmp/hermes-config-sequence/SKILL.md" <<'EOF'
---
name: "hermes-config-sequence"
description: "Reject a sequence marker before the Hermes config mapping."
metadata:
  hermes:
    - config:
      - key: "wiki.path"
        description: "Path to the main wiki"
---

# Hermes config sequence
EOF
cat > "$test_tmp/hermes-child-sequence/SKILL.md" <<'EOF'
---
name: "hermes-child-sequence"
description: "Reject a sequence marker on a Hermes child field."
metadata:
  hermes:
    config:
      - key: "wiki.path"
        - description: "Path to the main wiki"
---

# Hermes child sequence
EOF
cat > "$test_tmp/unquoted-portable-metadata/SKILL.md" <<'EOF'
---
name: "unquoted-portable-metadata"
description: "Reject an unquoted portable metadata value."
metadata:
  "owner": toolboxmd
---

# Unquoted portable metadata
EOF
metadata_key_cases=(ordinary owner boolean true date 2026-08-13 numeric 123)
for ((index = 0; index < ${#metadata_key_cases[@]}; index += 2)); do
  label="${metadata_key_cases[$index]}"
  raw="${metadata_key_cases[$((index + 1))]}"
  mkdir -p "$test_tmp/unquoted-$label-metadata-key"
  printf -- '---\nname: "unquoted-%s-metadata-key"\ndescription: "Reject an unquoted portable metadata key."\nmetadata:\n  %s: "value"\n---\n\n# Unquoted metadata key\n' "$label" "$raw" > "$test_tmp/unquoted-$label-metadata-key/SKILL.md"
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/unquoted-$label-metadata-key" > "$test_tmp/unquoted-$label-metadata-key.json"
  set -e
done
cat > "$test_tmp/quoted-portable-metadata-keys/SKILL.md" <<'EOF'
---
name: "quoted-portable-metadata-keys"
description: "Accept JSON-double-quoted portable metadata keys."
metadata:
  "owner": "toolboxmd"
  "true": "boolean-looking"
  "2026-08-13": "date-looking"
  "123": "numeric-looking"
---

# Quoted portable metadata keys
EOF
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/quoted-portable-metadata-keys" > "$test_tmp/quoted-portable-metadata-keys.json"
for variant in empty comment-only; do
  mkdir -p "$test_tmp/$variant-metadata"
done
cat > "$test_tmp/empty-metadata/SKILL.md" <<'EOF'
---
name: "empty-metadata"
description: "Reject a bare metadata field."
metadata:
---

# Empty metadata
EOF
cat > "$test_tmp/comment-only-metadata/SKILL.md" <<'EOF'
---
name: "comment-only-metadata"
description: "Reject metadata containing only comments."
metadata:
  # no semantic entries

---

# Comment-only metadata
EOF
for variant in empty comment-only; do
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/$variant-metadata" > "$test_tmp/$variant-metadata.json"
  set -e
done
make_fixture "$test_tmp/metadata-omitted" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/metadata-omitted" > "$test_tmp/metadata-omitted.json"
for name in portable-hermes-sequence hermes-config-sequence hermes-child-sequence; do
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --allow-hermes-metadata "$test_tmp/$name" > "$test_tmp/$name.json"
  metadata_sequence_exit=$?
  set -e
  [[ $metadata_sequence_exit -eq 1 ]]
done
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/unquoted-portable-metadata" > "$test_tmp/unquoted-portable-metadata.json"
unquoted_portable_metadata_exit=$?
set -e
[[ $unquoted_portable_metadata_exit -eq 1 ]]

mkdir -p "$test_tmp/doubled-quote-budget"
{
  printf '%s\n' '---' 'name: "doubled-quote-budget"'
  printf "description: '%s''%s'\n" "$(printf '%0600d' 0)" "$(printf '%0600d' 0)"
  printf '%s\n' '---' '' '# Doubled quote budget'
} > "$test_tmp/doubled-quote-budget/SKILL.md"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/doubled-quote-budget" > "$test_tmp/doubled-quote-budget.json"
doubled_quote_exit=$?
set -e
[[ $doubled_quote_exit -eq 1 ]]

scalar_cases=(ordinary 'ordinary prose' date 2026-08-13 hex 0x2A octal 0o52 boolean true null null numeric 123.5 nan .nan positive-inf +.INF negative-nan -.NaN)
for ((index = 0; index < ${#scalar_cases[@]}; index += 2)); do
  label="${scalar_cases[$index]}"
  raw="${scalar_cases[$((index + 1))]}"
  for prefix in unquoted quoted; do
    mkdir -p "$test_tmp/$prefix-$label-description"
  done
  printf -- '---\nname: "unquoted-%s-description"\ndescription: %s\n---\n\n# Unquoted scalar\n' "$label" "$raw" > "$test_tmp/unquoted-$label-description/SKILL.md"
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/unquoted-$label-description" > "$test_tmp/unquoted-$label-description.json"
  scalar_exit=$?
  set -e
  [[ $scalar_exit -eq 1 ]]
  printf -- '---\nname: "quoted-%s-description"\ndescription: "%s"\n---\n\n# Quoted scalar\n' "$label" "$raw" > "$test_tmp/quoted-$label-description/SKILL.md"
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/quoted-$label-description" > "$test_tmp/quoted-$label-description.json"
done

for name in invalid-double-escape nested-scalar explicit-tag malformed-quote invalid-fold-indicator reserved-indicator; do
  mkdir -p "$test_tmp/$name"
done
printf '%s\n' '---' 'name: "invalid-double-escape"' 'description: "Bad\qescape"' '---' '' '# Invalid escape' > "$test_tmp/invalid-double-escape/SKILL.md"
printf '%s\n' '---' 'name: "nested-scalar"' 'description: nested: value' '---' '' '# Nested scalar' > "$test_tmp/nested-scalar/SKILL.md"
printf '%s\n' '---' 'name: "explicit-tag"' 'description: !!seq [one]' '---' '' '# Explicit tag' > "$test_tmp/explicit-tag/SKILL.md"
printf '%s\n' '---' 'name: "malformed-quote"' 'description: "unterminated' '---' '' '# Malformed quote' > "$test_tmp/malformed-quote/SKILL.md"
printf '%s\n' '---' 'name: "invalid-fold-indicator"' 'description: >0' '---' '' '# Invalid fold indicator' > "$test_tmp/invalid-fold-indicator/SKILL.md"
printf '%s\n' '---' 'name: "reserved-indicator"' 'description: @bad' '---' '' '# Reserved indicator' > "$test_tmp/reserved-indicator/SKILL.md"
for name in invalid-double-escape nested-scalar explicit-tag malformed-quote invalid-fold-indicator reserved-indicator; do
  set +e
  PYTHONDWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/$name" > "$test_tmp/$name.json"
  canonical_scalar_exit=$?
  set -e
  [[ $canonical_scalar_exit -eq 1 ]]
done

comment_cases=(collection '[one, two]' boolean true null null numeric 123.5)
for ((index = 0; index < ${#comment_cases[@]}; index += 2)); do
  label="${comment_cases[$index]}"
  raw="${comment_cases[$((index + 1))]}"
  mkdir -p "$test_tmp/commented-$label-description"
  printf -- '---\nname: "commented-%s-description"\ndescription: %s # type comment\n---\n\n# Commented scalar\n' "$label" "$raw" > "$test_tmp/commented-$label-description/SKILL.md"
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/commented-$label-description" > "$test_tmp/commented-$label-description.json"
  commented_exit=$?
  set -e
  [[ $commented_exit -eq 1 ]]
done

mkdir -p "$test_tmp/quoted-hash-description" "$test_tmp/block-description"
cat > "$test_tmp/quoted-hash-description/SKILL.md" <<'EOF'
---
name: "quoted-hash-description"
description: "[one, two] # literal"
compatibility: "true # literal" # actual comment
---

# Quoted hashes
EOF
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/quoted-hash-description" > "$test_tmp/quoted-hash-description.json"
cat > "$test_tmp/block-description/SKILL.md" <<'EOF'
---
name: "block-description"
description: | # block header comment
  Validate a block scalar without treating its hashes # as YAML comments.
---

# Block description
EOF
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/block-description" > "$test_tmp/block-description.json"
block_description_exit=$?
set -e
[[ $block_description_exit -eq 1 ]]

for style in literal folded; do
  mkdir -p "$test_tmp/metadata-block-$style"
done
cat > "$test_tmp/metadata-block-literal/SKILL.md" <<'EOF'
---
name: "metadata-block-literal"
description: "Reject scalar metadata."
metadata: | # metadata must be a mapping
  author: toolboxmd
---

# Metadata block
EOF
cat > "$test_tmp/metadata-block-folded/SKILL.md" <<'EOF'
---
name: "metadata-block-folded"
description: "Reject folded scalar metadata."
metadata: >-
  author: toolboxmd
---

# Metadata block
EOF
for style in literal folded; do
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/metadata-block-$style" > "$test_tmp/metadata-block-$style.json"
  metadata_block_exit=$?
  set -e
  [[ $metadata_block_exit -eq 1 ]]
done

mkdir -p "$test_tmp/indented-budget" "$test_tmp/tabbed-block" "$test_tmp/under-indented-block"
{
  printf '%s\n' '---' 'name: "indented-budget"' 'description: |-' '  a'
  printf '  %40s%s\n' '' 'b'
  printf '%s\n' '---' '' '# Indented budget'
} > "$test_tmp/indented-budget/SKILL.md"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --max-description-chars 40 "$test_tmp/indented-budget" > "$test_tmp/indented-budget.json"
indented_budget_exit=$?
set -e
[[ $indented_budget_exit -eq 1 ]]

for size in 1024 1025; do
  directory="$test_tmp/description-$size"
  mkdir -p "$directory"
  node - "$directory" "$size" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const [directory, rawSize] = process.argv.slice(2);
const name = path.basename(directory);
const description = "x".repeat(Number(rawSize));
fs.writeFileSync(path.join(directory, "SKILL.md"), `---\nname: "${name}"\ndescription: "${description}"\n---\n\n# Description boundary\n`);
NODE
done
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --max-description-chars 2000 "$test_tmp/description-1024" > "$test_tmp/description-1024-raised.json"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --max-description-chars 2000 "$test_tmp/description-1025" > "$test_tmp/description-1025-raised.json"
description_1025_exit=$?
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --max-description-chars 1000 "$test_tmp/description-1024" > "$test_tmp/description-1024-lowered.json"
description_1024_lowered_exit=$?
set -e
if [[ $description_1025_exit -ne 1 ]]; then
  echo "FAIL: raised package budget bypassed the portable description ceiling" >&2
  exit 1
fi
[[ $description_1024_lowered_exit -eq 1 ]]

printf '%s\n' '---' 'name: "tabbed-block"' 'description: |-' $'\tTabbed indentation is invalid.' '---' '' '# Tabbed block' > "$test_tmp/tabbed-block/SKILL.md"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/tabbed-block" > "$test_tmp/tabbed-block.json"
tabbed_block_exit=$?
set -e
[[ $tabbed_block_exit -eq 1 ]]
cat > "$test_tmp/under-indented-block/SKILL.md" <<'EOF'
---
name: "under-indented-block"
description: |2-
  first
 second
---

# Under-indented block
EOF
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/under-indented-block" > "$test_tmp/under-indented-block.json"
under_indented_exit=$?
set -e
[[ $under_indented_exit -eq 1 ]]

mkdir -p "$test_tmp/hermes-metadata" "$test_tmp/hermes-mapping" "$test_tmp/hermes-bad-list-start" "$test_tmp/hermes-empty-key" "$test_tmp/hermes-whitespace-key" "$test_tmp/unsupported-metadata" "$test_tmp/non-string-metadata"
cat > "$test_tmp/hermes-metadata/SKILL.md" <<'EOF'
---
name: "hermes-metadata"
description: "Validate documented Hermes configuration metadata."
metadata:
  "author": "toolboxmd"
  hermes:
    config:
      - key: "wiki.path"
        description: "Path to the main wiki"
        default: "~/wiki"
      - key: "wiki.mode"
        description: "Wiki mode"
        default: "project"
        prompt: "Choose a wiki mode"
---

# Hermes metadata
EOF
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/hermes-metadata" > "$test_tmp/hermes-default.json"
hermes_default_exit=$?
set -e
[[ $hermes_default_exit -eq 1 ]]
hermes_skills_ref_log="$test_tmp/hermes-skills-ref.log"
hermes_skills_ref_before="$(sha256_file "$fake_bin/skills-ref")"
node "$root/scripts/hash-tree.mjs" "$test_tmp/hermes-metadata" > "$test_tmp/hermes-before-official.json"
PATH="$fake_bin:$PATH" SKILLS_REF_MODE=fail SKILLS_REF_LOG="$hermes_skills_ref_log" \
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --allow-hermes-metadata "$test_tmp/hermes-metadata" > "$test_tmp/hermes-metadata.json"
PATH="$fake_bin:$PATH" SKILLS_REF_MODE=fail SKILLS_REF_LOG="$hermes_skills_ref_log" \
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --allow-hermes-metadata "$test_tmp/hermes-metadata" > "$test_tmp/hermes-metadata.out"
[[ ! -e "$hermes_skills_ref_log" ]]
[[ "$(sha256_file "$fake_bin/skills-ref")" == "$hermes_skills_ref_before" ]]
node "$root/scripts/hash-tree.mjs" "$test_tmp/hermes-metadata" > "$test_tmp/hermes-after-official.json"
cmp "$test_tmp/hermes-before-official.json" "$test_tmp/hermes-after-official.json"
grep -Fq "official_skills_ref=skipped_extension" "$test_tmp/hermes-metadata.out"
cat > "$test_tmp/hermes-mapping/SKILL.md" <<'EOF'
---
name: "hermes-mapping"
description: "Reject a mapping where Hermes requires a config sequence."
metadata:
  hermes:
    config:
        key: "wiki.path"
        description: "Path to the main wiki"
---

# Hermes mapping
EOF
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --allow-hermes-metadata "$test_tmp/hermes-mapping" > "$test_tmp/hermes-mapping.json"
hermes_mapping_exit=$?
set -e
cat > "$test_tmp/hermes-bad-list-start/SKILL.md" <<'EOF'
---
name: "hermes-bad-list-start"
description: "Reject a Hermes config item that does not start with key."
metadata:
  hermes:
    config:
      - description: "Path to the main wiki"
        key: "wiki.path"
---

# Hermes bad list start
EOF
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --allow-hermes-metadata "$test_tmp/hermes-bad-list-start" > "$test_tmp/hermes-bad-list-start.json"
hermes_bad_list_start_exit=$?
set -e
for name in hermes-empty-key hermes-whitespace-key; do
  key='""'
  if [[ $name == hermes-whitespace-key ]]; then
    key='"   "'
  fi
  cat > "$test_tmp/$name/SKILL.md" <<EOF
---
name: "$name"
description: "Reject a Hermes configuration entry with no usable key text."
metadata:
  hermes:
    config:
      - key: $key
        description: "Path to the main wiki"
---

# Hermes empty key
EOF
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --allow-hermes-metadata "$test_tmp/$name" > "$test_tmp/$name.json"
  hermes_key_exit=$?
  set -e
done
cat > "$test_tmp/unsupported-metadata/SKILL.md" <<'EOF'
---
name: "unsupported-metadata"
description: "Reject an unsupported nested metadata extension."
metadata:
  "other":
    config:
      - key: "path"
        description: "A path"
---

# Unsupported metadata
EOF
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/unsupported-metadata" > "$test_tmp/unsupported-metadata.json"
unsupported_metadata_exit=$?
set -e
[[ $unsupported_metadata_exit -eq 1 ]]
cat > "$test_tmp/non-string-metadata/SKILL.md" <<'EOF'
---
name: "non-string-metadata"
description: "Reject a non-string Hermes configuration value."
metadata:
  hermes:
    config:
      - key: "wiki.enabled"
        description: "Enable the wiki"
        default: false # must remain typed
---

# Non-string metadata
EOF
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --allow-hermes-metadata "$test_tmp/non-string-metadata" > "$test_tmp/non-string-metadata.json"
non_string_metadata_exit=$?
set -e
[[ $non_string_metadata_exit -eq 1 ]]

make_fixture "$test_tmp/code-links-fixture" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
cat >> "$test_tmp/code-links-fixture/SKILL.md" <<'EOF'

`[Inline example](inline-missing.md)`

```markdown
[Fenced example](fenced-missing.md)

[fenced]: fenced-definition-missing.md
```

> ~~~markdown
> [Blockquote fenced example](blockquote-fenced-missing.md)
> ~~~

- ```markdown
  harmless code

  [List fenced example](list-fenced-missing.md)
  ```

`[inline]: inline-definition-missing.md`

[Real link](real-missing.md)
EOF
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/code-links-fixture" > "$test_tmp/code-links.json"
code_links_exit=$?
set -e
[[ $code_links_exit -eq 1 ]]

make_fixture "$test_tmp/escaped-backtick-link" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
cat >> "$test_tmp/escaped-backtick-link/SKILL.md" <<'EOF'

\`[Active missing link](escaped-backtick-missing.md)\`
EOF
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/escaped-backtick-link" > "$test_tmp/escaped-backtick-link.json"
escaped_backtick_exit=$?
set -e

make_fixture "$test_tmp/backtick-code-controls" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
cat >> "$test_tmp/backtick-code-controls/SKILL.md" <<'EOF'

`[Single-backtick code](single-code-missing.md)`

``[Multi-backtick code](multi-code-missing.md)``

\\`[Even-backslash code](even-code-missing.md)`
EOF
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/backtick-code-controls" > "$test_tmp/backtick-code-controls.json"

make_fixture "$test_tmp/escaped-link-parity-active" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
cat >> "$test_tmp/escaped-link-parity-active/SKILL.md" <<'EOF'

[Zero inline](zero-missing.md)

\\[Two inline](two-missing.md)

\\\\[Four inline](four-missing.md)

[Zero reference][zero-reference]

\\[Two reference][two-reference]

\\\\[Four reference][four-reference]
EOF
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/escaped-link-parity-active" > "$test_tmp/escaped-link-parity-active.json"
escaped_link_parity_exit=$?
set -e

make_fixture "$test_tmp/escaped-link-parity-safe" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
cat >> "$test_tmp/escaped-link-parity-safe/SKILL.md" <<'EOF'

\[One escaped inline](one-missing.md)

\\\[Three escaped inline](three-missing.md)

\[One escaped reference][one-reference]

\\\[Three escaped reference][three-reference]
EOF
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/escaped-link-parity-safe" > "$test_tmp/escaped-link-parity-safe.json"

make_fixture "$test_tmp/markdown-boundaries" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
cat >> "$test_tmp/markdown-boundaries/SKILL.md" <<'EOF'

    [Indented code](indented-missing.md)

\[Escaped text](escaped-missing.md)

\[Escaped reference][escaped-missing]

[Remote](//example.com/skills)
EOF
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/markdown-boundaries" > "$test_tmp/markdown-boundaries.json"

make_fixture "$test_tmp/complex-markdown" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf '\n[Balanced](references/guide(v2).md)\n[Unknown][missing-label]\n' >> "$test_tmp/complex-markdown/SKILL.md"
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/complex-markdown" > "$test_tmp/complex-markdown.json"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/complex-markdown" > "$test_tmp/complex-markdown-strict.json"
complex_markdown_exit=$?
set -e
[[ $complex_markdown_exit -eq 1 ]]

make_fixture "$test_tmp/nested-image-link" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
mkdir -p "$test_tmp/nested-image-link/assets"
printf 'image\n' > "$test_tmp/nested-image-link/assets/icon.png"
printf '\n[![Icon](assets/icon.png)](outer-missing.md)\n' >> "$test_tmp/nested-image-link/SKILL.md"
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/nested-image-link" > "$test_tmp/nested-image-link.json"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/nested-image-link" > "$test_tmp/nested-image-link-strict.json"
nested_image_exit=$?
set -e
[[ $nested_image_exit -eq 1 ]]

for name in workspace-path root-path; do
  make_fixture "$test_tmp/$name" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
done
printf '\nRead /workspace/alice/project/input.md before continuing.\n' >> "$test_tmp/workspace-path/SKILL.md"
printf '\nRead /root/project/input.md before continuing.\n' >> "$test_tmp/root-path/SKILL.md"
for name in workspace-path root-path; do
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/$name" > "$test_tmp/$name.json"
  local_path_exit=$?
  set -e
  [[ $local_path_exit -eq 1 ]]
done

make_fixture "$test_tmp/node-helper-path" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
cat > "$test_tmp/node-helper-path/scripts/run.js" <<'EOF'
const input = "/workspace/alice/input.json";
console.log(input);
EOF
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/node-helper-path" > "$test_tmp/node-helper-path.json"
node_helper_exit=$?
set -e
[[ $node_helper_exit -eq 1 ]]

make_fixture "$test_tmp/unchecked-shell" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf '#!/usr/bin/env bash\nif then\n' > "$test_tmp/unchecked-shell/scripts/bad.sh"
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/unchecked-shell" > "$test_tmp/unchecked-shell.json"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/unchecked-shell" > "$test_tmp/unchecked-shell-strict.json"
unchecked_shell_exit=$?
set -e
[[ $unchecked_shell_exit -eq 1 ]]

make_fixture "$test_tmp/attested-helpers" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf '#!/usr/bin/env bash\nset -eu\nprintf "ok\\n"\n' > "$test_tmp/attested-helpers/scripts/check.sh"
printf 'console.log("ok");\n' > "$test_tmp/attested-helpers/scripts/check.js"
printf 'puts "ok"\n' > "$test_tmp/attested-helpers/scripts/check.rb"
shell_sha="$(sha256_file "$test_tmp/attested-helpers/scripts/check.sh")"
node_sha="$(sha256_file "$test_tmp/attested-helpers/scripts/check.js")"
ruby_sha="$(sha256_file "$test_tmp/attested-helpers/scripts/check.rb")"
python_sha="$(sha256_file "$test_tmp/attested-helpers/scripts/run.py")"
node "$root/scripts/hash-tree.mjs" "$test_tmp/attested-helpers" > "$test_tmp/attested-before.json"

set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/attested-helpers" > "$test_tmp/attestation-missing.json"
attestation_missing_exit=$?
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors \
  --script-syntax-checked "scripts/check.sh=$shell_sha" \
  "$test_tmp/attested-helpers" > "$test_tmp/attestation-partial.json"
attestation_partial_exit=$?
set -e
[[ $attestation_missing_exit -eq 1 && $attestation_partial_exit -eq 1 ]]

PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors \
  --script-syntax-checked "scripts/check.sh=$shell_sha" \
  --script-syntax-checked "scripts/check.js=$node_sha" \
  --script-syntax-checked "scripts/check.rb=$ruby_sha" \
  "$test_tmp/attested-helpers" > "$test_tmp/attestation-valid.json"
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --warnings-as-errors \
  --script-syntax-checked "scripts/check.sh=$shell_sha" \
  --script-syntax-checked "scripts/check.js=$node_sha" \
  --script-syntax-checked "scripts/check.rb=$ruby_sha" \
  "$test_tmp/attested-helpers" > "$test_tmp/attestation-valid-human.out"

bad_attestation() {
  local name="$1"
  shift
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$@" \
    "$test_tmp/attested-helpers" > "$test_tmp/$name.json"
  local status=$?
  set -e
  [[ $status -eq 1 ]]
}
bad_attestation attestation-malformed --script-syntax-checked "scripts/check.sh"
bad_attestation attestation-stale --script-syntax-checked "scripts/check.sh=$(printf '0%.0s' {1..64})"
bad_attestation attestation-parent --script-syntax-checked "../outside.sh=$shell_sha"
bad_attestation attestation-absolute --script-syntax-checked "/tmp/outside.sh=$shell_sha"
bad_attestation attestation-missing-path --script-syntax-checked "scripts/missing.sh=$shell_sha"
bad_attestation attestation-python --script-syntax-checked "scripts/run.py=$python_sha"
bad_attestation attestation-duplicate \
  --script-syntax-checked "scripts/check.sh=$shell_sha" \
  --script-syntax-checked "scripts/check.sh=$shell_sha"

grep -Fq 'accepted_paths=["scripts/check.js", "scripts/check.rb", "scripts/check.sh"] execution_verified_by_toolboxmd=false' "$test_tmp/attestation-valid-human.out"
node "$root/scripts/hash-tree.mjs" "$test_tmp/attested-helpers" > "$test_tmp/attested-after.json"
cmp "$test_tmp/attested-before.json" "$test_tmp/attested-after.json"

make_fixture "$test_tmp/system-shebang" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf '#!/usr/bin/env python3\nprint("ok")\n' > "$test_tmp/system-shebang/scripts/run.py"
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/system-shebang" > "$test_tmp/system-shebang.json"
for root_name in workspace root; do
  make_fixture "$test_tmp/$root_name-shebang" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
  printf '#!/%s/alice/.venv/bin/python\nprint("ok")\n' "$root_name" > "$test_tmp/$root_name-shebang/scripts/run.py"
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/$root_name-shebang" > "$test_tmp/$root_name-shebang.json"
  shebang_exit=$?
  set -e
  [[ $shebang_exit -eq 1 ]]
done

make_fixture "$test_tmp/binary-asset" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
mkdir -p "$test_tmp/binary-asset/assets"
printf '\377\376/workspace/alice/input.json\000' > "$test_tmp/binary-asset/assets/logo.png"
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/binary-asset" > "$test_tmp/binary-asset.json"

make_fixture "$test_tmp/invalid-extensionless-script" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf '\377\376#!/workspace/alice/python\000' > "$test_tmp/invalid-extensionless-script/scripts/run"
chmod +x "$test_tmp/invalid-extensionless-script/scripts/run"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/invalid-extensionless-script" > "$test_tmp/invalid-extensionless-script.json"
invalid_script_exit=$?
set -e
[[ $invalid_script_exit -eq 1 ]]

make_fixture "$test_tmp/invalid-python-bytes" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf '\377\n' > "$test_tmp/invalid-python-bytes/scripts/run.py"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/invalid-python-bytes" > "$test_tmp/invalid-python-bytes.json"
invalid_python_exit=$?
set -e
if [[ $invalid_python_exit -ne 1 ]]; then
  printf 'FAIL: invalid UTF-8 Python helper returned exit %s instead of validation exit 1\n' "$invalid_python_exit" >&2
  exit 1
fi

make_fixture "$test_tmp/valid-python-ast" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/valid-python-ast" > "$test_tmp/valid-python-ast.json"

make_fixture "$test_tmp/invalid-shebang-bytes" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf '#!/bin/sh\n\377\n' > "$test_tmp/invalid-shebang-bytes/shebang-helper"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/invalid-shebang-bytes" > "$test_tmp/invalid-shebang-bytes.json"
invalid_shebang_exit=$?
set -e
[[ $invalid_shebang_exit -eq 1 ]]

make_fixture "$test_tmp/svg-local-path" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
mkdir -p "$test_tmp/svg-local-path/assets"
printf '<svg><text>/workspace/alice/logo.svg</text></svg>\n' > "$test_tmp/svg-local-path/assets/logo.svg"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/svg-local-path" > "$test_tmp/svg-local-path.json"
svg_path_exit=$?
set -e
[[ $svg_path_exit -eq 1 ]]

make_fixture "$test_tmp/file-uri-path" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf '\nOpen file:///workspace/alice/input.json.\n' >> "$test_tmp/file-uri-path/SKILL.md"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/file-uri-path" > "$test_tmp/file-uri-path.json"
file_uri_exit=$?
set -e
[[ $file_uri_exit -eq 1 ]]

make_fixture "$test_tmp/file-uri-local-authority" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf '\n[Local home](file://localhost/home/alice/input.json) and file://LOCALHOST/Users/Alice/work/file.txt.\n' >> "$test_tmp/file-uri-local-authority/SKILL.md"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/file-uri-local-authority" > "$test_tmp/file-uri-local-authority.json"
file_uri_local_authority_exit=$?
set -e
[[ $file_uri_local_authority_exit -eq 1 ]]

make_fixture "$test_tmp/file-uri-loopback-authority" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf '\n[Loopback home](file://127.0.0.1/home/alice/input.json) and [loopback drive](file://127.0.0.1/C:/USERS/Alice/work/file.txt).\n' >> "$test_tmp/file-uri-loopback-authority/SKILL.md"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/file-uri-loopback-authority" > "$test_tmp/file-uri-loopback-authority.json"
file_uri_loopback_exit=$?
set -e

make_fixture "$test_tmp/file-uri-ipv6-loopback" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf '\n[IPv6 loopback](file://[::1]/home/alice/input.json).\n' >> "$test_tmp/file-uri-ipv6-loopback/SKILL.md"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/file-uri-ipv6-loopback" > "$test_tmp/file-uri-ipv6-loopback.json"
file_uri_ipv6_loopback_exit=$?
set -e

make_fixture "$test_tmp/file-uri-ipv6-safe" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf '\n[Remote IPv6](file://[2001:db8::1]/home/alice/input.json), [other IPv6](file://[::2]/root/input.json), and [zone IPv6](file://[fe80::1%%25en0]/workspace/input.json).\n' >> "$test_tmp/file-uri-ipv6-safe/SKILL.md"
printf '[Outer query](https://example.com/?next=file://[::1]/home/alice/input.json), [outer fragment](https://example.com/#file://[::1]/root/input.json), and [anchor](#file://[::1]/workspace/input.json) remain nonlocal.\n' >> "$test_tmp/file-uri-ipv6-safe/SKILL.md"
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/file-uri-ipv6-safe" > "$test_tmp/file-uri-ipv6-safe.json"

make_fixture "$test_tmp/file-uri-remote-authority" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf '\n[Remote home](file://example.com/home/alice/input.json), file://files.example.com/Users/Alice/work/file.txt, and file://localhost/Home/alice/input.json.\n' >> "$test_tmp/file-uri-remote-authority/SKILL.md"
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/file-uri-remote-authority" > "$test_tmp/file-uri-remote-authority.json"

for name in file-uri-uppercase-empty-authority file-uri-mixed-localhost; do
  make_fixture "$test_tmp/$name" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
done
printf '\n[Local home](FILE:///home/alice/input.json).\n' >> "$test_tmp/file-uri-uppercase-empty-authority/SKILL.md"
printf '\n[Local root](FiLe://LOCALHOST/root/alice/input.json).\n' >> "$test_tmp/file-uri-mixed-localhost/SKILL.md"
for name in file-uri-uppercase-empty-authority file-uri-mixed-localhost; do
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/$name" > "$test_tmp/$name.json"
  file_uri_case_exit=$?
  set -e
  if [[ $file_uri_case_exit -ne 1 ]]; then
    printf 'FAIL: case-insensitive local file URI %s returned exit %s\n' "$name" "$file_uri_case_exit" >&2
    exit 1
  fi
done

make_fixture "$test_tmp/file-uri-case-safe" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf '\n[Remote](FILE://example.com/home/alice/input.json) and [wrong-case root](FiLe:///Home/alice/input.json).\n' >> "$test_tmp/file-uri-case-safe/SKILL.md"
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/file-uri-case-safe" > "$test_tmp/file-uri-case-safe.json"

for name in file-uri-single-posix file-uri-single-encoded-posix file-uri-single-windows file-uri-single-mixed-windows file-uri-single-safe; do
  make_fixture "$test_tmp/$name" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
done
printf '%s\n' '' '[Local home](file:/home/alice/input.json).' >> "$test_tmp/file-uri-single-posix/SKILL.md"
printf '%s\n' '' '[Local root](FiLe:/%72oot/project/input.json).' >> "$test_tmp/file-uri-single-encoded-posix/SKILL.md"
printf '%s\n' '' '[Local drive](FILE:/C:/USERS/Alice/work/input.json).' >> "$test_tmp/file-uri-single-windows/SKILL.md"
printf '%s\n' '' '[Local mixed drive](file:/c:%5CUsers%2FAlice/work/input.json).' >> "$test_tmp/file-uri-single-mixed-windows/SKILL.md"
printf '%s\n' '' '[Remote file](file://example.com/home/alice/input.json), [wrong-case root](file:/Home/alice/input.json), [remote query](https://example.com/?next=file:/home/alice/input.json), [remote fragment](https://example.com/#file:/workspace/alice/input.json), and [anchor](#file:/root/alice/input.json) remain nonlocal.' >> "$test_tmp/file-uri-single-safe/SKILL.md"
for name in file-uri-single-posix file-uri-single-encoded-posix file-uri-single-windows file-uri-single-mixed-windows; do
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/$name" > "$test_tmp/$name.json"
  file_uri_single_exit=$?
  set -e
  [[ $file_uri_single_exit -eq 1 ]]
done
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/file-uri-single-safe" > "$test_tmp/file-uri-single-safe.json"

for name in encoded-file-uri-local encoded-file-uri-localhost encoded-file-uri-safe; do
  make_fixture "$test_tmp/$name" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
done
printf '%s\n' '' '[Encoded home](file:///h%6fme/alice/input.json).' >> "$test_tmp/encoded-file-uri-local/SKILL.md"
printf '%s\n' '' '[Encoded root](FiLe://LOCALHOST/%72oot/project/input.json) and FILE://localhost/%55sers/Alice/work/file.txt.' >> "$test_tmp/encoded-file-uri-localhost/SKILL.md"
printf '%s\n' '' '[Remote file](file://example.com/h%6fme/alice/input.json), [wrong-case root](FiLe://localhost/%48ome/alice/input.json), [remote query](https://example.com/?next=file:///h%6fme/alice/input.json), [remote fragment](https://example.com/#file:///h%6fme/alice/input.json), [anchor](#file:///h%6fme/alice/input.json), [malformed](file:///h%ZZome/alice/input.json), and [malformed prefix](file:///%/Users/alice/input.json).' >> "$test_tmp/encoded-file-uri-safe/SKILL.md"
printf '%s\n' 'Embedded profile:///h%6fme/a, not-FILE:///home/a, https://example.com/?next=file:///h%6fme/a, https://example.com/#file:///h%6fme/a, and #file:///h%6fme/a are not local file URI tokens.' >> "$test_tmp/encoded-file-uri-safe/SKILL.md"
printf '%s\n' 'Remote file://[2001:db8::1]/home/a and file://files.example./workspace/a authorities are not local.' >> "$test_tmp/encoded-file-uri-safe/SKILL.md"
printf '%s\n' 'Combined https://example.com/?next=file://[2001:db8::1]/home/a, https://example.com/#file://files.example./workspace/a, #file://[2001:db8::1]/root/a, https://example.com/?next=file:///%/Users/a, and #file:///%/workspace/a remain nonlocal.' >> "$test_tmp/encoded-file-uri-safe/SKILL.md"
printf '%s\n' 'Nested https://example.com/?next=(file:///%68ome/alice/input) and #(file:///%72oot/alice/input) remain remote or anchor text.' >> "$test_tmp/encoded-file-uri-safe/SKILL.md"
for name in encoded-file-uri-local encoded-file-uri-localhost; do
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/$name" > "$test_tmp/$name.json"
  encoded_file_uri_exit=$?
  set -e
  if [[ $encoded_file_uri_exit -ne 1 ]]; then
    printf 'FAIL: encoded local file URI %s returned exit %s\n' "$name" "$encoded_file_uri_exit" >&2
    exit 1
  fi
done
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/encoded-file-uri-safe" > "$test_tmp/encoded-file-uri-safe.json"

for name in file-uri-windows-empty file-uri-windows-localhost file-uri-windows-mixed-forward-backslash file-uri-windows-mixed-backslash-forward file-uri-windows-mixed-localhost-one file-uri-windows-mixed-localhost-two file-uri-windows-safe; do
  make_fixture "$test_tmp/$name" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
done
printf '%s\n' '' '[Local drive](file:///C:/Users/Alice/work/input.json).' >> "$test_tmp/file-uri-windows-empty/SKILL.md"
printf '%s\n' '' '[Local drive](FiLe://LOCALHOST/c:/USERS/Alice/work/input.json).' >> "$test_tmp/file-uri-windows-localhost/SKILL.md"
printf '%s\n' '' '[Local drive](file:///C:/Users%5CAlice/work/input.json).' >> "$test_tmp/file-uri-windows-mixed-forward-backslash/SKILL.md"
printf '%s\n' '' '[Local drive](file:///C:%5CUsers/Alice/work/input.json).' >> "$test_tmp/file-uri-windows-mixed-backslash-forward/SKILL.md"
printf '%s\n' '' '[Local drive](FiLe://LOCALHOST/c:%2FUSERS%5CAlice/work/input.json).' >> "$test_tmp/file-uri-windows-mixed-localhost-one/SKILL.md"
printf '%s\n' '' '[Local drive](file://localhost/C:%5Cusers%2FAlice/work/input.json).' >> "$test_tmp/file-uri-windows-mixed-localhost-two/SKILL.md"
printf '%s\n' '' '[Remote drive](file://example.com/C:/Users/Alice/work/input.json) and [wrong POSIX case](file:///Home/alice/input.json).' >> "$test_tmp/file-uri-windows-safe/SKILL.md"
for name in file-uri-windows-empty file-uri-windows-localhost file-uri-windows-mixed-forward-backslash file-uri-windows-mixed-backslash-forward file-uri-windows-mixed-localhost-one file-uri-windows-mixed-localhost-two; do
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/$name" > "$test_tmp/$name.json"
  file_uri_windows_exit=$?
  set -e
  [[ $file_uri_windows_exit -eq 1 ]]
done
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/file-uri-windows-safe" > "$test_tmp/file-uri-windows-safe.json"

for name in windows-forward windows-escaped windows-lowercase-backslash windows-uppercase-forward windows-mixed-backslash-forward windows-mixed-forward-backslash; do
  make_fixture "$test_tmp/$name" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
done
printf '\nRead C:/Users/Alice/project/input.json.\n' >> "$test_tmp/windows-forward/SKILL.md"
printf '%s\n' '' 'Read C:\\Users\\Alice\\project\\input.json.' >> "$test_tmp/windows-escaped/SKILL.md"
printf '%s\n' '' 'Read c:\users\alice\project\input.json.' >> "$test_tmp/windows-lowercase-backslash/SKILL.md"
printf '\nRead C:/USERS/Alice/project/input.json.\n' >> "$test_tmp/windows-uppercase-forward/SKILL.md"
printf '%s\n' '' 'Read C:\Users/Alice\project/input.json.' >> "$test_tmp/windows-mixed-backslash-forward/SKILL.md"
printf '%s\n' '' 'Read c:/uSeRs\Alice/project\input.json.' >> "$test_tmp/windows-mixed-forward-backslash/SKILL.md"
for name in windows-forward windows-escaped windows-lowercase-backslash windows-uppercase-forward windows-mixed-backslash-forward windows-mixed-forward-backslash; do
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/$name" > "$test_tmp/$name.json"
  windows_path_exit=$?
  set -e
done

make_fixture "$test_tmp/web-root-link" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
printf '\n[App route](/workspace/app) and [remote docs](https://example.com/root/docs).\n' >> "$test_tmp/web-root-link/SKILL.md"
set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/web-root-link" > "$test_tmp/web-root-link.json"
web_root_exit=$?
set -e
[[ $web_root_exit -eq 1 ]]

make_fixture "$test_tmp/remote-windows-links" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
cat >> "$test_tmp/remote-windows-links/SKILL.md" <<'EOF'

[HTTP query](http://example.com/?next=C:/USERS/Alice/work/file.txt)
[HTTPS query](https://example.com/?next=C:/USERS/Alice/work/file.txt)
[HTTP fragment](http://example.com/#C:/USERS/Alice/work/file.txt)
[HTTPS fragment](https://example.com/#C:/USERS/Alice/work/file.txt)
[Local anchor](#C:/USERS/Alice/work/file.txt)
EOF
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json --warnings-as-errors "$test_tmp/remote-windows-links" > "$test_tmp/remote-windows-links.json"

for name in file-link windows-drive-link; do
  make_fixture "$test_tmp/$name" 'PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/run.py"'
done
printf '\n[Local file](file:///Users/Alice/work/file.txt)\n' >> "$test_tmp/file-link/SKILL.md"
printf '\n[Local drive](C:/USERS/Alice/work/file.txt)\n' >> "$test_tmp/windows-drive-link/SKILL.md"
for name in file-link windows-drive-link; do
  set +e
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$test_tmp/$name" > "$test_tmp/$name.json"
  local_link_exit=$?
  set -e
  [[ $local_link_exit -eq 1 ]]
done

set +e
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$root/benchmarks/toolboxmd-creating-skills/v2/results/2026-08-13/cases/meeting-followups/toolboxmd/skill" > "$test_tmp/meeting.json"
meeting_exit=$?
PYTHONDONTWRITEBYTECODE=1 python3 -B "$validator" --json "$root/benchmarks/toolboxmd-creating-skills/v2/results/2026-08-13/cases/weekly-status-deck/toolboxmd/skill" > "$test_tmp/deck.json"
deck_exit=$?
set -e
[[ $meeting_exit -eq 1 && $deck_exit -eq 1 ]]

node - "$root" "$freeze" "$test_tmp" <<'NODE'
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const [root, freezePath, temporary] = process.argv.slice(2);
const freeze = JSON.parse(fs.readFileSync(freezePath));
const product = JSON.parse(fs.readFileSync(path.join(temporary, "product.json")));
const minimalExample = JSON.parse(fs.readFileSync(path.join(temporary, "minimal-example.json")));
const closedShellBare = JSON.parse(fs.readFileSync(path.join(temporary, "closed-shell-bare.json")));
const closedShellSafe = JSON.parse(fs.readFileSync(path.join(temporary, "closed-shell-safe.json")));
const parentRelativeShell = JSON.parse(fs.readFileSync(path.join(temporary, "parent-relative-shell.json")));
const parentRelativeCode = JSON.parse(fs.readFileSync(path.join(temporary, "parent-relative-code.json")));
const windowsRelativeShell = JSON.parse(fs.readFileSync(path.join(temporary, "windows-relative-shell.json")));
const windowsRelativeCode = JSON.parse(fs.readFileSync(path.join(temporary, "windows-relative-code.json")));
const embeddedRelativeShell = JSON.parse(fs.readFileSync(path.join(temporary, "embedded-relative-shell.json")));
const embeddedRelativeCode = JSON.parse(fs.readFileSync(path.join(temporary, "embedded-relative-code.json")));
const scriptsComponentShell = JSON.parse(fs.readFileSync(path.join(temporary, "scripts-component-shell.json")));
const scriptsComponentCode = JSON.parse(fs.readFileSync(path.join(temporary, "scripts-component-code.json")));
const scriptsSubstringSafe = JSON.parse(fs.readFileSync(path.join(temporary, "scripts-substring-safe.json")));
const tildeSegmentShell = JSON.parse(fs.readFileSync(path.join(temporary, "tilde-segment-shell.json")));
const tildeSegmentCode = JSON.parse(fs.readFileSync(path.join(temporary, "tilde-segment-code.json")));
const parentRelativeSafe = JSON.parse(fs.readFileSync(path.join(temporary, "parent-relative-safe.json")));
const unfencedHelperContexts = JSON.parse(fs.readFileSync(path.join(temporary, "unfenced-helper-contexts.json")));
const unclosedShellFence = JSON.parse(fs.readFileSync(path.join(temporary, "unclosed-shell-fence.json")));
const containerShellFences = JSON.parse(fs.readFileSync(path.join(temporary, "container-shell-fences.json")));
const containerBlankLines = JSON.parse(fs.readFileSync(path.join(temporary, "container-blank-lines.json")));
const containerMissingClosers = ["blockquote", "list"].map(name => JSON.parse(fs.readFileSync(path.join(temporary, `container-missing-closer-${name}.json`))));
const containerBoundarySafe = JSON.parse(fs.readFileSync(path.join(temporary, "container-boundary-safe.json")));
const containerBoundaryShell = JSON.parse(fs.readFileSync(path.join(temporary, "container-boundary-shell.json")));
const helperSourceBare = JSON.parse(fs.readFileSync(path.join(temporary, "helper-source-bare.json")));
const helperSourceParent = JSON.parse(fs.readFileSync(path.join(temporary, "helper-source-parent-relative.json")));
const helperSourceTilde = JSON.parse(fs.readFileSync(path.join(temporary, "helper-source-tilde-segments.json")));
const helperSourceScriptCase = JSON.parse(fs.readFileSync(path.join(temporary, "helper-source-script-case.json")));
const helperSourceScriptSubstrings = JSON.parse(fs.readFileSync(path.join(temporary, "helper-source-script-substrings.json")));
const helperSourceSafe = JSON.parse(fs.readFileSync(path.join(temporary, "helper-source-safe.json")));
const markdownHelperSource = JSON.parse(fs.readFileSync(path.join(temporary, "markdown-helper-source.json")));
const markdownHelperLinksSafe = JSON.parse(fs.readFileSync(path.join(temporary, "markdown-helper-links-safe.json")));
const executableSourceBare = JSON.parse(fs.readFileSync(path.join(temporary, "executable-source-bare.json")));
const executableSourceEmbedded = JSON.parse(fs.readFileSync(path.join(temporary, "executable-source-embedded.json")));
const executableSourceCommaSafe = JSON.parse(fs.readFileSync(path.join(temporary, "executable-source-comma-safe.json")));
const genericConfigSafe = JSON.parse(fs.readFileSync(path.join(temporary, "generic-config-safe.json")));
const portable = JSON.parse(fs.readFileSync(path.join(temporary, "portable.json")));
const official = ["pass", "fail", "unexpected", "timeout"].map(mode => JSON.parse(fs.readFileSync(path.join(temporary, `skills-ref-${mode}.json`))));
const sidecar = JSON.parse(fs.readFileSync(path.join(temporary, "sidecar.json")));
const nonregularSidecars = ["sidecar-directory", "sidecar-fifo", "sidecar-ancestor-file", "sidecar-ancestor-fifo"].map(name => JSON.parse(fs.readFileSync(path.join(temporary, `${name}.json`))));
const symlinkSidecars = ["sidecar-direct-symlink", "sidecar-ancestor-symlink"].map(name => JSON.parse(fs.readFileSync(path.join(temporary, `${name}.json`))));
const invalidUtf8Sidecar = JSON.parse(fs.readFileSync(path.join(temporary, "invalid-utf8-sidecar.json")));
const supportedPartialSidecars = ["policy-only", "dependencies-only", "display-only", "brand-only", "prompt-only"].map(name => JSON.parse(fs.readFileSync(path.join(temporary, `${name}.json`))));
const creationPartialSidecars = ["policy-only", "dependencies-only", "display-only", "brand-only", "prompt-only"].map(name => JSON.parse(fs.readFileSync(path.join(temporary, `creation-${name}.json`))));
const creationFullSidecar = JSON.parse(fs.readFileSync(path.join(temporary, "creation-full-sidecar.json")));
const creationNoSidecar = JSON.parse(fs.readFileSync(path.join(temporary, "creation-no-sidecar.json")));
const blankSidecars = ["blank-sidecar", "comment-only-sidecar"].map(name => JSON.parse(fs.readFileSync(path.join(temporary, `${name}.json`))));
const policyCase = JSON.parse(fs.readFileSync(path.join(temporary, "policy-case.json")));
const sidecarEdges = ["empty-interface", "empty-interface-value", "empty-policy", "empty-dependencies", "empty-tools", "duplicate-sidecar", "duplicate-tools", "long-display", "long-prompt", "outside-icon", "token-boundary", "invalid-sidecar-string"].map(name => JSON.parse(fs.readFileSync(path.join(temporary, `${name}.json`))));
const minimalSidecar = JSON.parse(fs.readFileSync(path.join(temporary, "minimal-sidecar.json")));
const whitespaceSidecars = ["display", "short"].flatMap(field =>
  ["general", "creation"].map(mode => JSON.parse(fs.readFileSync(path.join(temporary, `${mode}-whitespace-${field}.json`))))
);
const whitespaceDependency = JSON.parse(fs.readFileSync(path.join(temporary, "whitespace-dependency.json")));
const badPrompt = JSON.parse(fs.readFileSync(path.join(temporary, "bad-prompt.json")));
const missingIcon = JSON.parse(fs.readFileSync(path.join(temporary, "missing-icon.json")));
const exactCaseIcon = JSON.parse(fs.readFileSync(path.join(temporary, "exact-case-icon.json")));
const iconCaseMismatches = ["file-case-icon", "directory-case-icon"].map(name => JSON.parse(fs.readFileSync(path.join(temporary, `${name}.json`))));
const symlinkIcon = JSON.parse(fs.readFileSync(path.join(temporary, "symlink-icon.json")));
const symlinkLoopIcons = ["symlink-loop-icon", "symlink-loop-icon-python39"].map(name => JSON.parse(fs.readFileSync(path.join(temporary, `${name}.json`))));
const titledLink = JSON.parse(fs.readFileSync(path.join(temporary, "titled-link.json")));
const referenceLink = JSON.parse(fs.readFileSync(path.join(temporary, "reference-link.json")));
const referenceWhitespace = JSON.parse(fs.readFileSync(path.join(temporary, "reference-whitespace.json")));
const exactCaseLinks = JSON.parse(fs.readFileSync(path.join(temporary, "exact-case-links.json")));
const caseMismatchLinks = JSON.parse(fs.readFileSync(path.join(temporary, "case-mismatch-links.json")));
const symlinkLoopLink = JSON.parse(fs.readFileSync(path.join(temporary, "symlink-loop-link.json")));
const malformedUris = ["http", "file"].map(scheme => JSON.parse(fs.readFileSync(path.join(temporary, `malformed-${scheme}-destination.json`))));
const uriDestinationControls = JSON.parse(fs.readFileSync(path.join(temporary, "uri-destination-controls.json")));
const missingReference = JSON.parse(fs.readFileSync(path.join(temporary, "missing-reference.json")));
const escapingReference = JSON.parse(fs.readFileSync(path.join(temporary, "escaping-reference.json")));
const encodedAbsoluteLink = JSON.parse(fs.readFileSync(path.join(temporary, "encoded-absolute-link.json")));
const indentedCodeReference = JSON.parse(fs.readFileSync(path.join(temporary, "indented-code-reference.json")));
const escapedBacktickLink = JSON.parse(fs.readFileSync(path.join(temporary, "escaped-backtick-link.json")));
const backtickCodeControls = JSON.parse(fs.readFileSync(path.join(temporary, "backtick-code-controls.json")));
const escapedLinkParityActive = JSON.parse(fs.readFileSync(path.join(temporary, "escaped-link-parity-active.json")));
const escapedLinkParitySafe = JSON.parse(fs.readFileSync(path.join(temporary, "escaped-link-parity-safe.json")));
const reserved = ["claude-helper", "anthropic-helper"].map(name => JSON.parse(fs.readFileSync(path.join(temporary, `${name}.json`))));
const listDescription = JSON.parse(fs.readFileSync(path.join(temporary, "list-description.json")));
const quotedDescription = JSON.parse(fs.readFileSync(path.join(temporary, "quoted-description.json")));
const angleDescriptions = ["angle-less-than-description", "angle-greater-than-description"].map(name => JSON.parse(fs.readFileSync(path.join(temporary, `${name}.json`))));
const angleSafeDescription = JSON.parse(fs.readFileSync(path.join(temporary, "angle-safe-description.json")));
const surrogateHigh = JSON.parse(fs.readFileSync(path.join(temporary, "surrogate-high-description.json")));
const surrogateLow = JSON.parse(fs.readFileSync(path.join(temporary, "surrogate-low-description.json")));
const surrogateMetadataValue = JSON.parse(fs.readFileSync(path.join(temporary, "surrogate-pair-metadata-value.json")));
const surrogateMetadataKey = JSON.parse(fs.readFileSync(path.join(temporary, "surrogate-pair-metadata-key.json")));
const surrogateSidecar = JSON.parse(fs.readFileSync(path.join(temporary, "surrogate-pair-sidecar.json")));
const unicodeSafe = JSON.parse(fs.readFileSync(path.join(temporary, "unicode-safe.json")));
const nonprintableDescription = JSON.parse(fs.readFileSync(path.join(temporary, "nonprintable-description.json")));
const nonprintableMetadataKey = JSON.parse(fs.readFileSync(path.join(temporary, "nonprintable-metadata-key.json")));
const nonprintableMetadataValue = JSON.parse(fs.readFileSync(path.join(temporary, "nonprintable-metadata-value.json")));
const nonprintableHermes = JSON.parse(fs.readFileSync(path.join(temporary, "nonprintable-hermes.json")));
const nonprintableSidecar = JSON.parse(fs.readFileSync(path.join(temporary, "nonprintable-sidecar.json")));
const yamlPrintableControls = JSON.parse(fs.readFileSync(path.join(temporary, "yaml-printable-controls.json")));
const yamlPrintableLiterals = JSON.parse(fs.readFileSync(path.join(temporary, "yaml-printable-literals.json")));
const yamlPhysicalLines = JSON.parse(fs.readFileSync(path.join(temporary, "yaml-physical-lines.json")));
const unquotedDateDescription = JSON.parse(fs.readFileSync(path.join(temporary, "unquoted-date-description.json")));
const quotedName = JSON.parse(fs.readFileSync(path.join(temporary, "quoted-name.json")));
const nameForms = ["ordinary-name", "true", "null", "123", "2026-08-14"];
const unquotedNames = nameForms.map(name => JSON.parse(fs.readFileSync(path.join(temporary, `unquoted-name-${name}.json`))));
const quotedNames = nameForms.map(name => JSON.parse(fs.readFileSync(path.join(temporary, `quoted-name-${name}.json`))));
const outsideExecutable = JSON.parse(fs.readFileSync(path.join(temporary, "outside-executable.json")));
const outsideShebang = JSON.parse(fs.readFileSync(path.join(temporary, "outside-shebang.json")));
const outsideData = JSON.parse(fs.readFileSync(path.join(temporary, "outside-data.json")));
const portableMetadataSequence = JSON.parse(fs.readFileSync(path.join(temporary, "portable-metadata-sequence.json")));
const metadataSequenceLevels = ["portable-hermes-sequence", "hermes-config-sequence", "hermes-child-sequence"].map(name => JSON.parse(fs.readFileSync(path.join(temporary, `${name}.json`))));
const unquotedPortableMetadata = JSON.parse(fs.readFileSync(path.join(temporary, "unquoted-portable-metadata.json")));
const metadataKeyFailures = ["ordinary", "boolean", "date", "numeric"].map(name => JSON.parse(fs.readFileSync(path.join(temporary, `unquoted-${name}-metadata-key.json`))));
const quotedPortableMetadataKeys = JSON.parse(fs.readFileSync(path.join(temporary, "quoted-portable-metadata-keys.json")));
const emptyMetadata = ["empty", "comment-only"].map(name => JSON.parse(fs.readFileSync(path.join(temporary, `${name}-metadata.json`))));
const metadataOmitted = JSON.parse(fs.readFileSync(path.join(temporary, "metadata-omitted.json")));
const scalarKinds = ["ordinary", "date", "hex", "octal", "boolean", "null", "numeric", "nan", "positive-inf", "negative-nan"];
const unquotedScalars = scalarKinds.map(name => JSON.parse(fs.readFileSync(path.join(temporary, `unquoted-${name}-description.json`))));
const quotedScalars = scalarKinds.map(name => JSON.parse(fs.readFileSync(path.join(temporary, `quoted-${name}-description.json`))));
const commentKinds = ["collection", "boolean", "null", "numeric"];
const commentedScalars = commentKinds.map(name => JSON.parse(fs.readFileSync(path.join(temporary, `commented-${name}-description.json`))));
const quotedHash = JSON.parse(fs.readFileSync(path.join(temporary, "quoted-hash-description.json")));
const blockDescription = JSON.parse(fs.readFileSync(path.join(temporary, "block-description.json")));
const description1024Raised = JSON.parse(fs.readFileSync(path.join(temporary, "description-1024-raised.json")));
const description1025Raised = JSON.parse(fs.readFileSync(path.join(temporary, "description-1025-raised.json")));
const description1024Lowered = JSON.parse(fs.readFileSync(path.join(temporary, "description-1024-lowered.json")));
const doubledQuote = JSON.parse(fs.readFileSync(path.join(temporary, "doubled-quote-budget.json")));
const hermesMetadata = JSON.parse(fs.readFileSync(path.join(temporary, "hermes-metadata.json")));
const hermesEmptyKeys = ["hermes-empty-key", "hermes-whitespace-key"].map(name => JSON.parse(fs.readFileSync(path.join(temporary, `${name}.json`))));
const hermesDefault = JSON.parse(fs.readFileSync(path.join(temporary, "hermes-default.json")));
const hermesInvalidSequences = ["hermes-mapping", "hermes-bad-list-start"].map(name => JSON.parse(fs.readFileSync(path.join(temporary, `${name}.json`))));
const unsupportedMetadata = JSON.parse(fs.readFileSync(path.join(temporary, "unsupported-metadata.json")));
const nonStringMetadata = JSON.parse(fs.readFileSync(path.join(temporary, "non-string-metadata.json")));
const codeLinks = JSON.parse(fs.readFileSync(path.join(temporary, "code-links.json")));
const markdownBoundaries = JSON.parse(fs.readFileSync(path.join(temporary, "markdown-boundaries.json")));
const complexMarkdown = JSON.parse(fs.readFileSync(path.join(temporary, "complex-markdown.json")));
const complexMarkdownStrict = JSON.parse(fs.readFileSync(path.join(temporary, "complex-markdown-strict.json")));
const nestedImage = JSON.parse(fs.readFileSync(path.join(temporary, "nested-image-link.json")));
const nestedImageStrict = JSON.parse(fs.readFileSync(path.join(temporary, "nested-image-link-strict.json")));
const localPaths = ["workspace-path", "root-path"].map(name => JSON.parse(fs.readFileSync(path.join(temporary, `${name}.json`))));
const nodeHelper = JSON.parse(fs.readFileSync(path.join(temporary, "node-helper-path.json")));
const uncheckedShell = JSON.parse(fs.readFileSync(path.join(temporary, "unchecked-shell.json")));
const uncheckedShellStrict = JSON.parse(fs.readFileSync(path.join(temporary, "unchecked-shell-strict.json")));
const attestationMissing = JSON.parse(fs.readFileSync(path.join(temporary, "attestation-missing.json")));
const attestationPartial = JSON.parse(fs.readFileSync(path.join(temporary, "attestation-partial.json")));
const attestationValid = JSON.parse(fs.readFileSync(path.join(temporary, "attestation-valid.json")));
const invalidAttestations = ["malformed", "stale", "parent", "absolute", "missing-path", "python", "duplicate"].map(name => JSON.parse(fs.readFileSync(path.join(temporary, `attestation-${name}.json`))));
const binaryAsset = JSON.parse(fs.readFileSync(path.join(temporary, "binary-asset.json")));
const systemShebang = JSON.parse(fs.readFileSync(path.join(temporary, "system-shebang.json")));
const localShebangs = ["workspace", "root"].map(name => JSON.parse(fs.readFileSync(path.join(temporary, `${name}-shebang.json`))));
const invalidScript = JSON.parse(fs.readFileSync(path.join(temporary, "invalid-extensionless-script.json")));
const invalidPython = JSON.parse(fs.readFileSync(path.join(temporary, "invalid-python-bytes.json")));
const validPython = JSON.parse(fs.readFileSync(path.join(temporary, "valid-python-ast.json")));
const invalidShebang = JSON.parse(fs.readFileSync(path.join(temporary, "invalid-shebang-bytes.json")));
const svgPath = JSON.parse(fs.readFileSync(path.join(temporary, "svg-local-path.json")));
const fileUri = JSON.parse(fs.readFileSync(path.join(temporary, "file-uri-path.json")));
const fileUriLocalAuthority = JSON.parse(fs.readFileSync(path.join(temporary, "file-uri-local-authority.json")));
const fileUriLoopbackAuthority = JSON.parse(fs.readFileSync(path.join(temporary, "file-uri-loopback-authority.json")));
const fileUriIpv6Loopback = JSON.parse(fs.readFileSync(path.join(temporary, "file-uri-ipv6-loopback.json")));
const fileUriIpv6Safe = JSON.parse(fs.readFileSync(path.join(temporary, "file-uri-ipv6-safe.json")));
const fileUriRemoteAuthority = JSON.parse(fs.readFileSync(path.join(temporary, "file-uri-remote-authority.json")));
const fileUriCaseLocal = ["file-uri-uppercase-empty-authority", "file-uri-mixed-localhost"].map(name => JSON.parse(fs.readFileSync(path.join(temporary, `${name}.json`))));
const fileUriCaseSafe = JSON.parse(fs.readFileSync(path.join(temporary, "file-uri-case-safe.json")));
const fileUriSingleLocal = ["file-uri-single-posix", "file-uri-single-encoded-posix", "file-uri-single-windows", "file-uri-single-mixed-windows"].map(name => JSON.parse(fs.readFileSync(path.join(temporary, `${name}.json`))));
const fileUriSingleSafe = JSON.parse(fs.readFileSync(path.join(temporary, "file-uri-single-safe.json")));
const encodedFileUriLocal = ["encoded-file-uri-local", "encoded-file-uri-localhost"].map(name => JSON.parse(fs.readFileSync(path.join(temporary, `${name}.json`))));
const encodedFileUriSafe = JSON.parse(fs.readFileSync(path.join(temporary, "encoded-file-uri-safe.json")));
const fileUriWindowsLocal = ["file-uri-windows-empty", "file-uri-windows-localhost", "file-uri-windows-mixed-forward-backslash", "file-uri-windows-mixed-backslash-forward", "file-uri-windows-mixed-localhost-one", "file-uri-windows-mixed-localhost-two"].map(name => JSON.parse(fs.readFileSync(path.join(temporary, `${name}.json`))));
const fileUriWindowsSafe = JSON.parse(fs.readFileSync(path.join(temporary, "file-uri-windows-safe.json")));
const windowsPaths = ["windows-forward", "windows-escaped", "windows-lowercase-backslash", "windows-uppercase-forward", "windows-mixed-backslash-forward", "windows-mixed-forward-backslash"].map(name => JSON.parse(fs.readFileSync(path.join(temporary, `${name}.json`))));
const webRootLink = JSON.parse(fs.readFileSync(path.join(temporary, "web-root-link.json")));
const remoteWindowsLinks = JSON.parse(fs.readFileSync(path.join(temporary, "remote-windows-links.json")));
const localWindowsLinks = ["file-link", "windows-drive-link"].map(name => JSON.parse(fs.readFileSync(path.join(temporary, `${name}.json`))));
const meeting = JSON.parse(fs.readFileSync(path.join(temporary, "meeting.json")));
const deck = JSON.parse(fs.readFileSync(path.join(temporary, "deck.json")));

function assert(condition, message) {
  if (!condition) {
    console.error(`FAIL: ${message}`);
    process.exit(1);
  }
}

function fileSha(relative) {
  return crypto.createHash("sha256").update(fs.readFileSync(path.join(root, relative))).digest("hex");
}

assert(freeze.claimBoundary.newModelSessions === 0, "freeze must record zero model sessions");
assert(freeze.claimBoundary.superiorityClaimAllowed === false, "freeze must forbid a superiority claim");
assert(freeze.claimBoundary.promotionClaimAllowed === false, "freeze must forbid a promotion claim");
assert(freeze.creatorBudgets.packageBytesMaximum === 46000, "reviewed package cap changed");
assert(freeze.budgetRevision.deterministicExecutableDeltaBytes === 2256, "executable review delta changed");
assert(freeze.budgetRevision.laterDeterministicExecutableDeltaBytes === 460, "later executable review delta changed");
assert(freeze.budgetRevision.holisticReviewExecutableDeltaBytes === 7353, "holistic review delta changed");
assert(freeze.budgetRevision.latestExactHeadReviewExecutableDeltaBytes === 27, "latest executable review delta changed");
assert(freeze.budgetRevision.sequenceAndCommandReviewExecutableDeltaBytes === 353, "sequence and command review delta changed");
assert(freeze.budgetRevision.quoteOnlyCanonicalExecutableDeltaBytes === -312, "quote-only canonical executable delta changed");
assert(freeze.budgetRevision.portableMetadataKeyExecutableDeltaBytes === 273, "portable metadata key executable delta changed");
assert(freeze.budgetRevision.emptyMetadataExecutableDeltaBytes === 142, "empty metadata executable delta changed");
assert(freeze.budgetRevision.directCommandExecutableDeltaBytes === 116, "direct command executable delta changed");
assert(freeze.budgetRevision.previousPackageBytesMaximumBeforeLexicalScanner === 36000, "pre-lexer package cap changed");
assert(freeze.budgetRevision.optionalSidecarAndAssignmentExecutableDeltaBytes === 2766, "optional sidecar and assignment executable delta changed");
assert(freeze.budgetRevision.groupingOperatorExecutableDeltaBytes === 226, "grouping operator executable delta changed");
assert(freeze.budgetRevision.scriptSyntaxAttestationExecutableDeltaBytes === 2673, "script syntax attestation executable delta changed");
assert(freeze.budgetRevision.previousPackageBytesMaximumBeforeSyntaxAttestation === 40000, "pre-attestation package cap changed");
assert(freeze.budgetRevision.shellControlPrefixExecutableDeltaBytes === 959, "shell control-prefix executable delta changed");
assert(freeze.budgetRevision.descriptionAngleBracketExecutableDeltaBytes === 132, "description angle-bracket executable delta changed");
assert(freeze.budgetRevision.closedSurfaceScriptPathExecutableDeltaBytes === 1189, "closed-surface migration executable delta changed");
assert(freeze.budgetRevision.containerFenceLinkMaskingExecutableDeltaBytes === 345, "container fence link-masking executable delta changed");
assert(freeze.budgetRevision.quotedNameAndScriptLocationExecutableDeltaBytes === -197, "quoted-name/location executable delta changed");
assert(freeze.budgetRevision.listContainerBlankLineExecutableDeltaBytes === 128, "list-container blank-line executable delta changed");
assert(freeze.budgetRevision.windowsAndCreationModeExecutableDeltaBytes === 119, "Windows/creation-mode executable delta changed");
assert(freeze.budgetRevision.remoteLinkAndWhitespaceExecutableDeltaBytes === 277, "remote-link/whitespace executable delta changed");
assert(freeze.budgetRevision.parentRelativeAndFileAuthorityExecutableDeltaBytes === 26, "parent-relative/file-authority executable delta changed");
assert(freeze.budgetRevision.unicodeSurrogateExecutableDeltaBytes === -25, "Unicode-surrogate executable delta changed");
assert(freeze.budgetRevision.mixedDotAndPythonUtf8ExecutableDeltaBytes === 17, "mixed-dot/Python-UTF8 executable delta changed");
assert(freeze.budgetRevision.fileUriCaseExecutableDeltaBytes === 4, "file-URI-case executable delta changed");
assert(freeze.budgetRevision.extensionSkipAndSidecarUtf8ExecutableDeltaBytes === 187, "extension-skip/sidecar-UTF8 executable delta changed");
assert(freeze.budgetRevision.previousPackageBytesMaximumBeforeExtensionSkip === 44000, "pre-extension-skip package cap changed");
assert(freeze.budgetRevision.descriptionAndEncodedFileUriExecutableDeltaBytes === 789, "description/file-URI executable delta changed");
assert(freeze.budgetRevision.windowsHelperFileUriAndReferenceExecutableDeltaBytes === 57, "Windows-helper/file-URI/reference executable delta changed");
assert(freeze.budgetRevision.singleSlashFileUriDependencyStaticPrefixAndExclusionsExecutableDeltaBytes === 167, "single-slash/dependency/static-prefix/exclusions executable delta changed");
assert(freeze.budgetRevision.malformedUriExecutableDeltaBytes === 595, "malformed-URI executable delta changed");
assert(freeze.budgetRevision.previousPackageBytesMaximumBeforeMalformedUri === 45000, "pre-malformed-URI package cap changed");
assert(freeze.budgetRevision.caseExactLinkAndHermesKeyExecutableDeltaBytes === 524, "case-exact-link/Hermes-key executable delta changed");
assert(freeze.budgetRevision.iconCaseAndTildeSegmentExecutableDeltaBytes === 98, "icon-case/tilde-segment executable delta changed");
assert(freeze.budgetRevision.scriptComponentBoundaryExecutableDeltaBytes === 162, "script-component-boundary executable delta changed");
assert(freeze.budgetRevision.pathAndReferenceNormalizationExecutableDeltaBytes === 35, "path/reference normalization executable delta changed");
assert(freeze.budgetRevision.yamlPrintableAndEscapedBacktickExecutableDeltaBytes === 6, "YAML-printable/escaped-backtick executable delta changed");
assert(freeze.budgetRevision.escapedLinkParityAndIpv6LoopbackExecutableDeltaBytes === 7, "escaped-link/IPv6-loopback executable delta changed");
assert(freeze.budgetRevision.sidecarEntrySafetyExecutableDeltaBytes === -363, "sidecar-entry-safety executable delta changed");
assert(freeze.budgetRevision.currentExecutableDeltaBytesFromPreRevisionFreeze === 21571, "current executable delta changed");
assert(freeze.budgetRevision.lowerTotalPackageCostClaimAllowed === false, "budget revision must not imply lower package cost");
assert(freeze.source.v1ResultManifest.eligibleCreatorComparisons === 0, "v1 claim boundary changed");
assert(freeze.source.v2ResultManifest.eligibleCreatorComparisons === 0, "v2 claim boundary changed");
for (const source of [freeze.source.v1ResultManifest, freeze.source.v2ResultManifest, freeze.source.diagnosticRecommendations]) {
  assert(fileSha(source.path) === source.sha256, `source changed: ${source.path}`);
}

assert(product.status === "pass" && product.errorCount === 0 && product.warningCount === 0, "product validation failed");
assert(minimalExample.status === "pass" && minimalExample.metrics.fileCount === 1 && minimalExample.metrics.referenceFileCount === 0 && minimalExample.metrics.scriptFileCount === 0, "real minimal example must pass canonical budgets");
assert(product.coverage.canonicalSubset === "toolboxmd-portable-core-v2", "canonical subset version changed");
assert(product.coverage.scriptPaths.shellParsed === false && product.coverage.scriptPaths.markdown.includes("no shell parse"), "closed-surface script-path coverage changed");
assert(product.aggregateSha256 === freeze.package.aggregateSha256, "package aggregate differs from freeze");
assert(product.files.length === freeze.package.files.length, "per-file package count changed");
for (const actual of product.files) {
  const expected = freeze.package.files.find(item => item.path === actual.path);
  assert(expected && expected.bytes === actual.bytes && expected.sha256 === actual.sha256, `package file changed: ${actual.path}`);
}
const bytewise = [...product.files].sort((left, right) => Buffer.compare(Buffer.from(left.path, "utf8"), Buffer.from(right.path, "utf8")));
const independentAggregate = crypto.createHash("sha256").update(bytewise.map(item => `${item.sha256}  ${item.path}\n`).join("")).digest("hex");
assert(independentAggregate === freeze.package.aggregateSha256, "bytewise UTF-8 aggregate does not reproduce");
assert(product.metrics.descriptionCharacters === freeze.package.skillMd.descriptionCharacters, "description metric changed");
assert(product.metrics.skillMdLines === freeze.package.skillMd.lines, "line metric changed");
assert(product.metrics.skillMdBytes === freeze.package.skillMd.bytes, "core byte metric changed");
assert(product.metrics.fileCount === 3 && product.metrics.packageBytes === 45626, "package budget changed");
assert(product.metrics.referenceFileCount === 0 && product.metrics.evalFileCount === 0 && product.metrics.scriptFileCount === 1, "package ownership changed");

assert(portable.status === "pass" && portable.warningCount === 0, "explicit skill-directory fixture must pass");
assert(official.map(result => result.coverage.officialSkillsRef.status).join(",") === "pass,fail,error,timeout", "official validator outcomes changed");
assert(official[0].status === "pass" && official.slice(1).every(result => result.status === "fail"), "official validator exits changed");
assert(official.every(result => result.coverage.officialSkillsRef.externalBehaviorAttested === false), "external validator behavior must remain unattested");
assert(sidecar.status === "pass" && sidecar.errorCount === 0, "official nested sidecar must pass");
assert(nonregularSidecars.every(result => result.status === "fail" && result.issues.length === 1 && result.issues[0].code === "OPENAI_FILE"), "non-regular sidecars must fail once without reading their bytes");
assert(symlinkSidecars.every(result => result.status === "fail" && result.issues.length === 1 && result.issues[0].code === "SYMLINK"), "sidecar and ancestor symlinks must not read external bytes or add sidecar diagnostics");
assert(invalidUtf8Sidecar.status === "fail" && invalidUtf8Sidecar.issues.length === 1 && invalidUtf8Sidecar.issues[0].code === "UTF8", "invalid UTF-8 sidecar must produce one package issue");
assert(policyCase.status === "fail" && sidecarEdges.every(result => result.status === "fail"), "sidecar canonical boundary changed");
assert(minimalSidecar.status === "pass" && minimalSidecar.errorCount === 0, "default_prompt must remain optional");
assert(whitespaceSidecars.every(result => result.status === "fail" && result.issues.some(item => item.code === "OPENAI_SHAPE")), "present sidecar strings must contain non-whitespace text");
assert(whitespaceSidecars.filter(result => result.coverage.creationMode).every(result => result.issues.some(item => item.code === "TOOLBOXMD_GENERATED_SIDECAR")), "creation mode must reject whitespace-only UI fields as missing");
assert(whitespaceDependency.status === "fail" && whitespaceDependency.issues.filter(item => item.code === "OPENAI_SHAPE").length === 1 && !whitespaceDependency.issues.some(item => item.code === "OPENAI_DEPENDENCY"), "whitespace-only MCP dependency values must fail once as malformed sidecar shape");
assert(badPrompt.issues.some(item => item.code === "OPENAI_DEFAULT_PROMPT"), "default_prompt must be validated when present");
assert(missingIcon.issues.some(item => item.code === "OPENAI_ICON"), "declared icon paths must resolve inside the package");
assert(exactCaseIcon.status === "pass", "exact-case icon paths must pass");
assert(symlinkIcon.status === "fail" && symlinkIcon.issues.some(item => item.code === "SYMLINK") && !symlinkIcon.issues.some(item => item.code === "OPENAI_ICON"), "contained icon symlinks must preserve package-level symlink behavior");
assert(symlinkLoopIcons.every(result => result.status === "fail" && result.issues.some(item => item.code === "SYMLINK") && !result.issues.some(item => item.code === "OPENAI_ICON")), "icon symlink loops must remain one structured package-level boundary across supported Python runtimes");
assert(iconCaseMismatches.every(result => result.status === "fail" && result.issues.some(item => item.code === "OPENAI_ICON")), "case-only icon path component mismatches must fail deterministically");
assert(titledLink.status === "pass" && titledLink.errorCount === 0, "valid local link with optional title must pass");
assert(referenceLink.status === "pass" && referenceLink.errorCount === 0, "valid reference definition must pass");
assert(referenceWhitespace.status === "pass" && referenceWhitespace.warningCount === 0, "reference labels must collapse internal ASCII whitespace before case-insensitive matching");
assert(exactCaseLinks.status === "pass", "exact-case file, directory, and anchor links must pass");
assert(caseMismatchLinks.status === "fail" && caseMismatchLinks.issues.filter(item => item.code === "BROKEN_LINK").length === 2, "case-only file and directory link mismatches must fail deterministically");
assert(symlinkLoopLink.status === "fail" && symlinkLoopLink.issues.some(item => item.code === "SYMLINK") && symlinkLoopLink.issues.some(item => item.code === "BROKEN_LINK"), "symlink-loop links must remain structured failures without expansion");
assert(malformedUris.every(result => result.status === "fail" && result.errorCount === 1 && result.issues.length === 1 && result.issues[0].code === "URI_SYNTAX"), "malformed HTTP and file destinations must each produce one stable URI issue");
assert(uriDestinationControls.status === "pass" && uriDestinationControls.errorCount === 0, "valid remote and local URI destinations changed");
assert(missingReference.issues.some(item => item.code === "BROKEN_LINK"), "missing reference destination must fail");
assert(escapingReference.issues.some(item => item.code === "LINK_ESCAPE"), "escaping reference destination must fail");
assert(encodedAbsoluteLink.issues.some(item => item.code === "LINK_ESCAPE") && !encodedAbsoluteLink.issues.some(item => item.code === "BROKEN_LINK"), "percent-decoded absolute destinations must retain link-escape diagnostics");
assert(indentedCodeReference.status === "pass", "four-space indented code must not become a reference definition");
assert(escapedBacktickLink.status === "fail" && escapedBacktickLink.issues.filter(item => item.code === "BROKEN_LINK").length === 1, "escaped backtick delimiters must not mask an active missing link");
assert(backtickCodeControls.status === "pass", "real single- and multi-backtick code spans must keep links masked across backslash parity");
assert(escapedLinkParityActive.status === "fail" && escapedLinkParityActive.issues.filter(item => item.code === "BROKEN_LINK").length === 3 && escapedLinkParityActive.issues.filter(item => item.code === "OFFICIAL_VALIDATOR_REQUIRED").length === 3, "zero and even backslashes must keep inline and reference links active");
assert(escapedLinkParitySafe.status === "pass", "one and odd backslashes must keep inline and reference links escaped");
assert(reserved.every(result => result.status === "fail" && result.issues.some(item => item.code === "NAME_RESERVED")), "reserved provider names must fail");
assert(listDescription.status === "fail" && listDescription.issues.some(item => item.code === "FRONTMATTER_STRING"), "unquoted collection description must fail");
assert(quotedDescription.status === "pass", "quoted collection-looking description must remain a string");
assert(angleDescriptions.every(result => result.status === "fail" && result.issues.some(item => item.code === "DESCRIPTION_ANGLE_BRACKET")), "each description angle bracket must fail without skills-ref");
assert(angleDescriptions.every(result => result.coverage.officialSkillsRef.status === "not_available"), "angle-bracket checks must not depend on skills-ref");
assert(angleSafeDescription.status === "pass", "ordinary quoted description text must remain valid");
assert([surrogateHigh, surrogateLow, surrogateMetadataValue].every(result => result.status === "fail" && result.issues.some(item => item.code === "FRONTMATTER_STRING")), "surrogate escapes in canonical scalar values must fail without skills-ref");
assert(surrogateMetadataKey.status === "fail" && surrogateMetadataKey.issues.some(item => item.code === "METADATA_KEY"), "surrogate escapes in portable metadata keys must fail");
assert(surrogateSidecar.status === "fail" && surrogateSidecar.issues.some(item => item.code === "OPENAI_SHAPE"), "surrogate escapes in sidecar strings must fail");
assert([surrogateHigh, surrogateLow, surrogateMetadataValue, surrogateMetadataKey, surrogateSidecar].every(result => result.coverage.officialSkillsRef.status === "not_available"), "surrogate checks must not depend on skills-ref");
assert(unicodeSafe.status === "pass" && unicodeSafe.warningCount === 0, "literal Unicode scalar values must remain valid across canonical surfaces");
assert(nonprintableDescription.issues.some(item => item.code === "FRONTMATTER_STRING"), "literal YAML-nonprintable top-level text must fail canonical string validation");
assert(nonprintableMetadataKey.issues.some(item => item.code === "METADATA_KEY"), "YAML-nonprintable portable metadata keys must retain the metadata-key diagnostic");
assert([nonprintableMetadataValue, nonprintableHermes].every(result => result.issues.some(item => item.code === "FRONTMATTER_STRING")), "YAML-nonprintable metadata values must retain canonical string diagnostics");
assert(nonprintableSidecar.issues.some(item => item.code === "OPENAI_SHAPE"), "YAML-nonprintable sidecar strings must retain the sidecar-shape diagnostic");
assert(yamlPrintableControls.status === "pass", "YAML printable TAB, line breaks, BMP, and non-BMP scalar values must remain accepted");
assert(yamlPrintableLiterals.status === "pass" && yamlPrintableLiterals.metrics.skillMdLines === 8, "literal YAML-printable NEL, LS, and PS must remain scalar content rather than physical lines");
assert(yamlPhysicalLines.status === "pass", "CRLF and CR must remain physical YAML line breaks");
assert(unquotedScalars.every(result => result.status === "fail" && result.issues.some(item => item.code === "FRONTMATTER_STRING")), "all unquoted description scalars must fail");
assert(quotedScalars.every(result => result.status === "pass"), "quoted scalar lookalikes must remain strings");
assert(supportedPartialSidecars.every(result => result.status === "pass"), "supported partial sidecars are rejected");
assert(supportedPartialSidecars.every(result => result.coverage.creationMode === false), "general sidecar mode coverage changed");
assert(creationPartialSidecars.every(result => result.status === "fail" && result.issues.some(item => item.code === "TOOLBOXMD_GENERATED_SIDECAR")), "creation mode must reject generated sidecars without both UI fields");
assert(creationPartialSidecars.every(result => result.coverage.creationMode === true), "creation sidecar mode coverage changed");
assert(creationFullSidecar.status === "pass" && creationNoSidecar.status === "pass", "creation mode must accept a full generated sidecar or no optional sidecar");
assert(blankSidecars.every(result => result.status === "fail" && result.issues.some(item => item.code === "OPENAI_SHAPE")), "blank sidecar lacks semantic-section error");
assert(closedShellBare.status === "fail" && closedShellBare.issues.filter(item => item.code === "FRAGILE_SCRIPT_PATH").length === 25, "closed shell fences must reject every lexically adjacent bare helper path without shell parsing");
assert(closedShellSafe.status === "pass" && closedShellSafe.warningCount === 0, "explicit skill roots, prose, links, directory-only mentions, and leading-whitespace child names must remain safe");
assert(parentRelativeShell.status === "fail" && parentRelativeShell.issues.filter(item => item.code === "FRAGILE_SCRIPT_PATH").length === 5, "plain and mixed parent-relative helper prefixes must fail in closed shell fences");
assert(parentRelativeCode.status === "fail" && parentRelativeCode.issues.filter(item => item.code === "UNFENCED_SCRIPT_EXAMPLE").length === 4, "plain and mixed parent-relative helper prefixes must fail in closed non-shell code surfaces");
assert(windowsRelativeShell.status === "fail" && windowsRelativeShell.issues.filter(item => item.code === "FRAGILE_SCRIPT_PATH").length === 5, "Windows and mixed-separator task-relative helpers must fail in closed shell fences");
assert(windowsRelativeCode.status === "fail" && windowsRelativeCode.issues.filter(item => item.code === "UNFENCED_SCRIPT_EXAMPLE").length === 4, "Windows and mixed-separator task-relative helpers must fail in closed non-shell code surfaces");
assert(embeddedRelativeShell.status === "fail" && embeddedRelativeShell.issues.filter(item => item.code === "FRAGILE_SCRIPT_PATH").length === 9, "static embedded task-relative prefixes must fail across slash, backslash, mixed, nested, and dot-normalizing shell forms");
assert(embeddedRelativeCode.status === "fail" && embeddedRelativeCode.issues.filter(item => item.code === "UNFENCED_SCRIPT_EXAMPLE").length === 4, "static embedded task-relative prefixes must fail in closed non-shell code surfaces");
assert(scriptsComponentShell.status === "fail" && scriptsComponentShell.issues.filter(item => item.code === "FRAGILE_SCRIPT_PATH").length === 14, "the scripts path component must match case-insensitively across shell separator and static-prefix forms, including comma-bearing components");
assert(scriptsComponentCode.status === "fail" && scriptsComponentCode.issues.filter(item => item.code === "UNFENCED_SCRIPT_EXAMPLE").length === 13, "the scripts path component must match case-insensitively in closed non-shell code surfaces, including comma-bearing components");
assert(scriptsSubstringSafe.status === "pass", "scripts text after a comma inside an ordinary path component must not become a helper path");
assert(tildeSegmentShell.status === "fail" && tildeSegmentShell.issues.filter(item => item.code === "FRAGILE_SCRIPT_PATH").length === 6, "tildes inside ordinary path segments must not hide shell helper paths");
assert(tildeSegmentCode.status === "fail" && tildeSegmentCode.issues.filter(item => item.code === "UNFENCED_SCRIPT_EXAMPLE").length === 4, "tildes inside ordinary path segments must not hide non-shell helper paths");
assert(parentRelativeSafe.status === "pass", "literal skill roots, standalone home roots, URL tokens, and ordinary link destinations must remain safe");
assert(unfencedHelperContexts.status === "fail" && unfencedHelperContexts.issues.filter(item => item.code === "UNFENCED_SCRIPT_EXAMPLE").length === 8, "single-line inline, indented, and fenced code outside recognized shell fences must fail closed");
assert(unclosedShellFence.status === "fail" && unclosedShellFence.issues.some(item => item.code === "MARKDOWN_FENCE"), "unclosed recognized shell fences must fail");
assert(containerShellFences.status === "fail" && containerShellFences.issues.filter(item => item.code === "FRAGILE_SCRIPT_PATH").length === 3 && containerShellFences.issues.some(item => item.code === "UNFENCED_SCRIPT_EXAMPLE"), "nested blockquote/list fences and blockquote-indented code must preserve closed-surface checks");
assert(containerBlankLines.status === "pass", "blank lines inside root, blockquote, list, and nested blockquote-list fences must preserve container state");
assert(containerMissingClosers.every(result => result.issues.some(item => item.code === "MARKDOWN_FENCE")), "container fences must not accept a root-level closer");
assert(containerBoundarySafe.status === "pass" && containerBoundarySafe.warningCount === 0, "non-shell fences end at their Markdown container boundary without consuming root prose");
assert(containerBoundaryShell.status === "fail" && containerBoundaryShell.issues.filter(item => item.code === "MARKDOWN_FENCE").length === 1 && !containerBoundaryShell.issues.some(item => item.code === "UNFENCED_SCRIPT_EXAMPLE"), "recognized shell fences fail at their Markdown container boundary without consuming root prose");
assert(helperSourceBare.status === "fail" && executableSourceBare.status === "fail" && [helperSourceBare, executableSourceBare].every(result => result.issues.some(item => item.code === "FRAGILE_SCRIPT_PATH")), "helper and executable source files must reject bare helper paths");
assert(helperSourceParent.status === "fail" && helperSourceParent.issues.filter(item => item.code === "FRAGILE_SCRIPT_PATH").length === 8, "helper sources must reject leading and embedded task-relative paths across separator forms");
assert(helperSourceTilde.status === "fail" && helperSourceTilde.issues.filter(item => item.code === "FRAGILE_SCRIPT_PATH").length === 5, "helper sources must reject task-relative paths with tildes inside ordinary segments");
assert(helperSourceScriptCase.status === "fail" && helperSourceScriptCase.issues.filter(item => item.code === "FRAGILE_SCRIPT_PATH").length === 14, "helper sources must match the scripts path component case-insensitively across comma-bearing path segments");
assert(helperSourceScriptSubstrings.status === "pass", "helper sources must not match scripts text after a comma inside an ordinary path component");
assert(executableSourceEmbedded.status === "fail" && executableSourceEmbedded.issues.filter(item => item.code === "FRAGILE_SCRIPT_PATH").length === 6, "executable sources must reject embedded task-relative paths across separator and comma-bearing segment forms");
assert(executableSourceCommaSafe.status === "pass" && !executableSourceCommaSafe.issues.some(item => item.code === "FRAGILE_SCRIPT_PATH"), "executable sources must keep unquoted comma-plus-scripts text inside one path component");
assert(markdownHelperSource.status === "fail" && markdownHelperSource.issues.some(item => item.code === "FRAGILE_SCRIPT_PATH"), "Markdown files below scripts must retain helper-source coverage");
assert(markdownHelperLinksSafe.status === "pass" && !markdownHelperLinksSafe.issues.some(item => item.code === "FRAGILE_SCRIPT_PATH"), "ordinary link destinations in Markdown helper sources must remain safe");
assert(helperSourceSafe.status === "pass" && genericConfigSafe.status === "pass", "explicit helper roots must pass and generic configs must stay outside command scanning");
assert(unquotedDateDescription.status === "fail" && unquotedDateDescription.issues.some(item => item.code === "FRONTMATTER_STRING"), "unquoted dates must fail the canonical string contract");
assert(quotedName.status === "pass", "quoted ordinary name must pass the canonical string contract");
assert(unquotedNames.every(result => result.status === "fail" && result.issues.some(item => item.code === "FRONTMATTER_STRING")), "every unquoted name must fail before YAML implicit typing");
assert(quotedNames.every(result => result.status === "pass"), "quoted ordinary and implicit-looking names must remain strings");
assert([outsideExecutable, outsideShebang].every(result => result.status === "fail" && result.issues.some(item => item.code === "SCRIPT_LOCATION")), "executable and shebang helpers outside scripts must fail canonical package policy");
assert(outsideData.status === "pass" && !outsideData.issues.some(item => item.code === "SCRIPT_LOCATION"), "outside non-executable data without a shebang must remain allowed");
assert(portableMetadataSequence.status === "fail" && portableMetadataSequence.issues.some(item => item.code === "METADATA_SHAPE"), "portable metadata sequences must fail");
assert(metadataSequenceLevels.every(result => result.status === "fail" && result.issues.some(item => item.code === "METADATA_SHAPE")), "sequence markers must remain confined to Hermes config entries");
assert(unquotedPortableMetadata.status === "fail" && unquotedPortableMetadata.issues.some(item => item.code === "FRONTMATTER_STRING"), "portable metadata values must use JSON double quotes");
assert(metadataKeyFailures.every(result => result.status === "fail" && result.issues.some(item => item.code === "METADATA_KEY")), "portable metadata keys must use JSON double quotes");
assert(quotedPortableMetadataKeys.status === "pass", "quoted ordinary and scalar-looking portable metadata keys must pass");
assert(emptyMetadata.every(result => result.status === "fail" && result.issues.some(item => item.code === "METADATA_EMPTY")), "empty or comment-only metadata must fail");
assert(metadataOmitted.status === "pass", "omitting optional metadata must pass");
assert(hermesInvalidSequences.every(result => result.status === "fail" && result.issues.some(item => item.code === "METADATA_SHAPE")), "Hermes config entries must start with a sequence key");
assert(commentedScalars.every(result => result.status === "fail" && result.issues.some(item => item.code === "FRONTMATTER_STRING")), "trailing comments must not hide unquoted scalars");
assert(quotedHash.status === "pass", "hashes inside quoted strings must remain content");
assert(blockDescription.status === "fail" && blockDescription.issues.some(item => item.code === "FRONTMATTER_STYLE"), "block frontmatter must be rejected as noncanonical");
assert(description1024Raised.status === "pass" && description1024Raised.metrics.descriptionCharacters === 1024, "the exact portable description ceiling must pass when the package budget is raised");
assert(description1025Raised.status === "fail" && description1025Raised.issues.some(item => item.code === "DESCRIPTION_BUDGET" && item.message.includes("1025 > 1024")), "the portable description ceiling must not be raised by a package budget");
assert(description1024Lowered.status === "fail" && description1024Lowered.issues.some(item => item.code === "DESCRIPTION_BUDGET" && item.message.includes("1024 > 1000")), "the package budget must still tighten the portable description ceiling");
assert(doubledQuote.status === "fail" && doubledQuote.issues.some(item => item.code === "FRONTMATTER_STRING"), "single-quoted strings must fail the canonical contract");
assert(hermesDefault.status === "fail", "portable-core mode must reject nested Hermes metadata");
assert(hermesMetadata.status === "pass" && hermesMetadata.coverage.enabledExtensions.includes("hermes-metadata"), "explicit Hermes extension mode must pass");
assert(hermesMetadata.coverage.officialSkillsRef.status === "skipped_extension" && hermesMetadata.coverage.officialSkillsRef.attempted === false, "portable skills-ref must be skipped for the Hermes extension");
assert(hermesEmptyKeys.every(result => result.status === "fail" && result.issues.length === 1 && result.issues[0].code === "METADATA_SHAPE"), "empty and whitespace-only Hermes keys must fail once with a stable shape diagnostic");
assert(unsupportedMetadata.status === "fail" && unsupportedMetadata.issues.some(item => item.code === "METADATA_SHAPE"), "unsupported nested metadata must fail");
assert(nonStringMetadata.status === "fail" && nonStringMetadata.issues.some(item => item.code === "FRONTMATTER_STRING"), "Hermes config values must use JSON double quotes");
const brokenLinks = codeLinks.issues.filter(item => item.code === "BROKEN_LINK");
assert(brokenLinks.length === 1 && brokenLinks[0].message.includes("real-missing.md"), "root, blockquote, and list-contained code links must be ignored while a real broken link fails");
assert(markdownBoundaries.status === "pass", "escaped, indented-code, and protocol-relative Markdown boundaries changed");
assert(complexMarkdown.status === "pass" && complexMarkdown.warningCount === 2 && complexMarkdownStrict.status === "fail", "complex Markdown must require official coverage without false broken-link errors");
assert(nestedImage.status === "pass" && nestedImage.warningCount === 1 && nestedImageStrict.status === "fail", "nested image links must require official coverage");
assert(localPaths.every(result => result.status === "fail" && result.issues.some(item => item.code === "LOCAL_PATH")), "common container-local roots must fail");
assert(nodeHelper.status === "fail" && nodeHelper.issues.some(item => item.code === "LOCAL_PATH"), "Node helpers must be scanned for local paths");
assert(uncheckedShell.status === "pass" && uncheckedShell.issues.some(item => item.code === "SCRIPT_SYNTAX_UNCHECKED") && uncheckedShellStrict.status === "fail", "non-Python script syntax boundary changed");
assert(attestationMissing.status === "fail" && attestationMissing.issues.filter(item => item.code === "SCRIPT_SYNTAX_UNCHECKED").length === 3, "strict mode must fail without non-Python syntax attestations");
assert(attestationPartial.status === "fail" && attestationPartial.issues.filter(item => item.code === "SCRIPT_SYNTAX_UNCHECKED").length === 2, "an attestation must suppress only its exact helper warning");
assert(attestationValid.status === "pass" && attestationValid.warningCount === 0, "exact-digest attestations must let separately checked helpers pass strict mode");
assert(attestationValid.coverage.scriptSyntaxChecks.acceptedPaths.join(",") === "scripts/check.js,scripts/check.rb,scripts/check.sh" && attestationValid.coverage.scriptSyntaxChecks.executionVerifiedByToolboxMD === false, "syntax-attestation coverage must remain explicit and bounded");
assert(invalidAttestations.every(result => result.status === "fail" && result.issues.some(item => item.code.startsWith("SCRIPT_SYNTAX_CHECK"))), "invalid, stale, outside, Python, missing, and duplicate attestations must fail");
assert(binaryAsset.status === "pass" && !binaryAsset.issues.some(item => item.code === "UTF8"), "binary assets must not be decoded as declared text");
assert(systemShebang.status === "pass" && localShebangs.every(result => result.issues.some(item => item.code === "LOCAL_PATH")), "shebang path boundary changed");
assert(invalidScript.issues.some(item => item.code === "UTF8"), "invalid UTF-8 executable must fail");
assert(invalidPython.status === "fail" && invalidPython.issues.filter(item => item.code === "UTF8").length === 1 && !invalidPython.issues.some(item => item.code === "PYTHON_SYNTAX"), "invalid UTF-8 Python must stay a single package-validation issue");
assert(validPython.status === "pass" && !validPython.issues.some(item => item.code === "PYTHON_SYNTAX"), "valid Python helpers must retain AST acceptance");
assert(invalidShebang.issues.some(item => item.code === "UTF8"), "invalid UTF-8 shebang file must fail without executable mode");
assert(svgPath.issues.some(item => item.code === "LOCAL_PATH") && fileUri.issues.some(item => item.code === "LOCAL_PATH"), "decodable asset and file URI path checks changed");
assert([fileUri, fileUriLocalAuthority, fileUriLoopbackAuthority, fileUriIpv6Loopback].every(result => result.status === "fail" && result.issues.some(item => item.code === "LOCAL_PATH")), "empty, localhost, IPv4, and IPv6 loopback file URI authorities must remain local");
assert(fileUriIpv6Safe.status === "pass", "remote, zone-scoped, other IPv6 authorities and outer remote contexts must remain nonlocal");
assert(fileUriRemoteAuthority.status === "pass" && !fileUriRemoteAuthority.issues.some(item => item.code === "LOCAL_PATH"), "remote file URI authorities must remain nonlocal");
assert(fileUriCaseLocal.every(result => result.status === "fail" && result.issues.some(item => item.code === "LOCAL_PATH")), "file URI scheme and localhost matching must be case-insensitive");
assert(fileUriCaseSafe.status === "pass" && !fileUriCaseSafe.issues.some(item => item.code === "LOCAL_PATH"), "remote file authorities and wrong-case POSIX roots must remain nonlocal");
assert(fileUriSingleLocal.every(result => result.status === "fail" && result.issues.some(item => item.code === "LOCAL_PATH")), "single-slash local file URIs must classify decoded POSIX and Windows roots");
assert(fileUriSingleSafe.status === "pass" && !fileUriSingleSafe.issues.some(item => item.code === "LOCAL_PATH"), "remote, HTTP query, fragment, anchor, and wrong-case single-slash boundaries must remain nonlocal");
assert(encodedFileUriLocal.every(result => result.status === "fail" && result.issues.some(item => item.code === "LOCAL_PATH")), "percent-encoded local file URI roots must be decoded before classification");
assert(encodedFileUriSafe.status === "pass" && !encodedFileUriSafe.issues.some(item => item.code === "LOCAL_PATH"), "remote, query, fragment, wrong-case, and malformed percent boundaries must remain nonlocal");
assert(fileUriWindowsLocal.every(result => result.status === "fail" && result.issues.some(item => item.code === "LOCAL_PATH")), "empty and localhost file URIs must classify decoded Windows drive-user roots");
assert(fileUriWindowsSafe.status === "pass" && !fileUriWindowsSafe.issues.some(item => item.code === "LOCAL_PATH"), "remote Windows file URIs and wrong-case POSIX roots must remain nonlocal");
assert(windowsPaths.every(result => result.issues.some(item => item.code === "LOCAL_PATH")), "Windows local path checks changed");
assert(webRootLink.issues.some(item => item.code === "ROOT_LINK") && !webRootLink.issues.some(item => item.code === "LOCAL_PATH"), "web links must not be mistaken for workstation paths");
assert(remoteWindowsLinks.status === "pass" && !remoteWindowsLinks.issues.some(item => item.code === "LOCAL_PATH"), "remote and anchor links must hide URL query or fragment text from workstation-path scanning");
assert(localWindowsLinks.every(result => result.status === "fail" && result.issues.some(item => item.code === "LOCAL_PATH")), "file URI and drive-root Markdown links must remain local paths");
for (const [name, result, expectedEvals] of [["meeting", meeting, 1], ["deck", deck, 2]]) {
  assert(result.issues.some(item => item.code === "FRAGILE_SCRIPT_PATH"), `${name}: retained bare script pattern not detected`);
  assert(result.metrics.referenceFileCount === 1, `${name}: retained always-read reference pattern changed`);
  assert(result.metrics.evalFileCount === expectedEvals, `${name}: retained eval baggage pattern changed`);
}

const skillText = fs.readFileSync(path.join(root, freeze.package.path, "SKILL.md"), "utf8");
const ownSidecar = fs.readFileSync(path.join(root, freeze.package.path, "agents/openai.yaml"), "utf8");
assert(!/\bgit\s+(?:status|rev-parse|diff|log)\b/i.test(skillText), "creator embeds an unconditional Git command");
assert(/Inspect Git state only when .*user request(?:ed|s) Git delivery/.test(skillText), "conditional Git boundary missing");
assert(skillText.includes('PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/validate_skill.py" --creation-mode --warnings-as-errors "<target-skill-dir>"'), "strict creation-mode creator command missing");
assert(skillText.includes("Other task- or parent-relative helper paths fail in code."), "parent-relative helper guidance missing");
assert(skillText.includes("Use literal Unicode, not surrogate escapes"), "Unicode scalar guidance missing");
assert(skillText.includes("--script-syntax-checked '<helper-path>=<lowercase-sha256>'"), "exact-digest non-Python syntax attestation flow missing");
assert(skillText.includes("Generated Codex sidecars require nonempty `display_name` and `short_description`"), "creator sidecar policy missing");
assert(/^\s{2}display_name:\s+".+"$/m.test(ownSidecar) && /^\s{2}short_description:\s+".+"$/m.test(ownSidecar), "creator sidecar must retain nonempty UI fields");
assert(skillText.includes("always-read reference belongs in activated-core cost"), "always-read cost rule missing");
NODE

if find "$package" "${retained[@]}" -type d -name __pycache__ -o -type f \( -name '*.pyc' -o -name '*.pyo' \) | grep -q .; then
  echo "FAIL: regression wrote Python bytecode" >&2
  exit 1
fi

for index in "${!retained[@]}"; do
  node "$root/scripts/hash-tree.mjs" "${retained[$index]}" > "$test_tmp/retained-$index-after.json"
  cmp "$test_tmp/retained-$index-before.json" "$test_tmp/retained-$index-after.json"
done
for index in "${!pending[@]}"; do
  cmp "$test_tmp/pending-$index-before" "${pending[$index]}"
done

echo "PASS: ToolboxMD creating-skills vNext deterministic regression"
