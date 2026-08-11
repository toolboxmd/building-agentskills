#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

authoring="docs/05-authoring/provider-neutral-runtime.md"
benchmark="docs/06-testing/benchmark-integrity.md"
case_study="case-studies/2026-08-11-karpathy-wiki-provider-aware-ingest.md"
evidence="case-studies/evidence/2026-08-11-karpathy-wiki-ingest-benchmark.json"

for required in "$authoring" "$benchmark" "$case_study" "$evidence"; do
  if [[ ! -f "$required" ]]; then
    echo "FAIL: missing $required" >&2
    exit 1
  fi
done

node -e 'JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"))' "$evidence"

grep -q 'docs/05-authoring/provider-neutral-runtime' docs.json
grep -q 'docs/06-testing/benchmark-integrity' docs.json
grep -q 'case-studies/2026-08-11-karpathy-wiki-provider-aware-ingest' docs.json

grep -q 'provider-neutral-runtime.md' README.md
grep -q 'benchmark-integrity.md' README.md
grep -q 'provider-neutral-runtime.md' skills/building-agentskills/SKILL.md
grep -q 'benchmark-integrity.md' skills/building-agentskills/SKILL.md

grep -q '877e659' "$case_study"
grep -q 'nested model delegation' "$benchmark"
grep -q 'cross-run read leakage' "$benchmark"

echo "PASS: provider-neutral runtime and benchmark-integrity docs are wired"
