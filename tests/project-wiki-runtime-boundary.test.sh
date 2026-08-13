#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

expected_pointer=$'role = "project-pointer"\nwiki = "./wiki"\ncreated = "2026-08-13"\nfork_to_main = false'
if [[ "$(cat "$root/.wiki-config")" != "$expected_pointer" ]]; then
  echo "FAIL: project wiki pointer is not portable and project-scoped" >&2
  exit 1
fi

expected_structural=$'role = "project"\ncreated = "2026-05-06"'
if [[ "$(cat "$root/wiki/.wiki-config")" != "$expected_structural" ]]; then
  echo "FAIL: tracked wiki config contains machine-specific runtime choices" >&2
  exit 1
fi

if ! grep -Fxq '.wiki-config.local' "$root/wiki/.gitignore"; then
  echo "FAIL: per-machine wiki runtime config is not ignored" >&2
  exit 1
fi

if git -C "$root" ls-files --error-unmatch wiki/.wiki-config.local >/dev/null 2>&1; then
  echo "FAIL: a per-machine provider profile is tracked" >&2
  exit 1
fi

for path in \
  "$root/wiki/inbox/.gitkeep" \
  "$root/wiki/raw/.gitkeep" \
  "$root/wiki/concepts/_index.md" \
  "$root/wiki/entities/_index.md" \
  "$root/wiki/ideas/_index.md" \
  "$root/wiki/queries/_index.md"; do
  if [[ ! -f "$path" ]]; then
    echo "FAIL: missing project-wiki structural path: ${path#"$root/"}" >&2
    exit 1
  fi
done

if find "$root/wiki/.wiki-pending" -maxdepth 1 -type f \( -name '*.md' -o -name '*.md.processing' \) -print -quit | grep -q .; then
  echo "FAIL: project wiki has an unprocessed capture" >&2
  exit 1
fi

node - "$root" <<'NODE'
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const root = process.argv[2];
const wiki = path.join(root, "wiki");

function assert(condition, message) {
  if (!condition) {
    console.error(`FAIL: ${message}`);
    process.exit(1);
  }
}

const rawRelative = "raw/2026-08-13-toolboxmd-creating-skills-benchmark-v2.md";
const manifest = JSON.parse(fs.readFileSync(path.join(wiki, ".manifest.json"), "utf8"));
const entry = manifest[rawRelative];
assert(entry, "benchmark case-study raw evidence is absent from the wiki manifest");
const raw = fs.readFileSync(path.join(wiki, rawRelative));
assert(crypto.createHash("sha256").update(raw).digest("hex") === entry.sha256, "wiki raw evidence hash changed");
assert(JSON.stringify(entry.referenced_by) === JSON.stringify(["concepts/benchmark-integrity-for-agent-skills.md"]), "wiki evidence lineage changed");

const runs = fs.readFileSync(path.join(wiki, ".ingest-runs.jsonl"), "utf8")
  .split(/\r?\n/)
  .filter(Boolean)
  .map(line => JSON.parse(line));
const benchmarkRuns = runs.filter(run => /toolboxmd-creator-benchmark-v2-(?:causal-design|final-result)\.md$/.test(run.capture));
assert(benchmarkRuns.filter(run => run.status === "started").length === 2, "benchmark wiki ingest start count changed");
assert(benchmarkRuns.filter(run => run.status === "completed" && run.exit_code === 0).length === 2, "benchmark wiki ingest completion evidence changed");
assert(benchmarkRuns.every(run => run.provider === "claude" && run.model === "sonnet"), "benchmark wiki ingest attribution changed");
NODE

echo "PASS: project wiki is routed, portable, indexed, and fully ingested"
