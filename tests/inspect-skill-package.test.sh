#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_tmp="$(mktemp -d "${TMPDIR:-/tmp}/toolboxmd-inspect-skill.XXXXXX")"
trap 'rm -rf "$test_tmp"' EXIT
mkdir -p "$test_tmp/skill/references" "$test_tmp/skill/scripts"
printf '%s\n' '---' 'name: fixture' 'description: Use for a fixture.' '---' '' '# Fixture' '' 'Read the guide.' > "$test_tmp/skill/SKILL.md"
printf 'guide\n' > "$test_tmp/skill/references/guide.md"
printf '#!/usr/bin/env python3\n' > "$test_tmp/skill/scripts/run.py"

inspection=$(node "$root/scripts/inspect-skill-package.mjs" "$test_tmp/skill")
node - "$inspection" <<'NODE'
const result = JSON.parse(process.argv[2]);
if (!/^[a-f0-9]{64}$/.test(result.aggregateSha256)) process.exit(1);
if (result.fileCount !== 3 || result.referenceFileCount !== 1 || result.scriptFileCount !== 1) process.exit(1);
if (result.skillMd.lines < 1 || result.skillMd.words < 1 || result.skillMd.descriptionCharacters < 1) process.exit(1);
if (result.packageBytes <= result.skillMd.bytes) process.exit(1);
NODE

echo "PASS: skill package inspection records comparable size metrics"
