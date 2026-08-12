#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <skill-directory>" >&2
  exit 2
fi

skill_dir="$1"
validator_source="git+https://github.com/agentskills/agentskills@69ef37e9424c0a7ea9dd2293b559e43ec8176379#subdirectory=skills-ref"

official_output=""
if ! official_output=$(uvx --from "$validator_source" skills-ref validate "$skill_dir" 2>&1); then
  echo "FAIL: official skills-ref validation" >&2
  echo "$official_output" >&2
  exit 1
fi

node - "$skill_dir" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(process.argv[2]);
const skillMd = path.join(root, "SKILL.md");
const content = fs.readFileSync(skillMd, "utf8");
const lineCount = content.split(/\r?\n/).length - (content.endsWith("\n") ? 1 : 0);

function fail(message) {
  console.error(`FAIL: ${message}`);
  process.exit(1);
}

if (lineCount > 500) {
  fail(`SKILL.md exceeds 500 lines (${lineCount})`);
}

const targets = [];
const markdownLink = /!?\[[^\]]*\]\(([^)]+)\)/g;
for (const match of content.matchAll(markdownLink)) {
  let target = match[1].trim();
  if (target.startsWith("<") && target.endsWith(">")) {
    target = target.slice(1, -1);
  }
  if (!target || target.startsWith("#") || target.startsWith("/") || /^[a-z][a-z0-9+.-]*:/i.test(target)) {
    continue;
  }
  target = target.split("#", 1)[0].split("?", 1)[0];
  if (target) targets.push(target);
}

const openaiYaml = path.join(root, "agents", "openai.yaml");
if (fs.existsSync(openaiYaml)) {
  const yaml = fs.readFileSync(openaiYaml, "utf8");
  for (const match of yaml.matchAll(/^\s*icon_(?:small|large):\s*["']?([^"'\s]+)["']?\s*$/gm)) {
    targets.push(match[1]);
  }
}

for (const target of [...new Set(targets)]) {
  const resolved = path.resolve(root, target);
  if (resolved !== root && !resolved.startsWith(`${root}${path.sep}`)) {
    fail(`relative reference escapes skill package: ${target}`);
  }
  if (!fs.existsSync(resolved)) {
    fail(`broken relative reference: ${target}`);
  }
}
NODE

if [[ -d "$skill_dir/scripts" ]]; then
  while IFS= read -r -d '' script; do
    case "$script" in
      *.py)
        python3 -c 'import pathlib, sys; compile(pathlib.Path(sys.argv[1]).read_bytes(), sys.argv[1], "exec")' "$script"
        ;;
      *.sh)
        bash -n "$script"
        ;;
      *.js|*.mjs|*.cjs)
        node --check "$script" >/dev/null
        ;;
    esac
  done < <(find "$skill_dir/scripts" -type f -print0 | LC_ALL=C sort -z)
fi

echo "PASS: valid skill package: $skill_dir"
