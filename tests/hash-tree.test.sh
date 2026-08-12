#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_tmp="$(mktemp -d "${TMPDIR:-/tmp}/toolboxmd-hash-tree.XXXXXX")"
trap 'rm -rf "$test_tmp"' EXIT

mkdir -p "$test_tmp/tree/nested"
printf 'alpha\n' > "$test_tmp/tree/a.txt"
printf 'beta\n' > "$test_tmp/tree/nested/b.txt"

first=$(node "$root/scripts/hash-tree.mjs" "$test_tmp/tree")
second=$(node "$root/scripts/hash-tree.mjs" "$test_tmp/tree")

node - "$first" "$second" <<'NODE'
const [first, second] = process.argv.slice(2).map(JSON.parse);
if (first.aggregateSha256 !== second.aggregateSha256) process.exit(1);
if (first.files.length !== 2) process.exit(1);
if (first.files.map(file => file.path).join(",") !== "a.txt,nested/b.txt") process.exit(1);
if (!first.files.every(file => Number.isInteger(file.bytes) && /^[a-f0-9]{64}$/.test(file.sha256))) process.exit(1);
NODE

printf 'changed\n' > "$test_tmp/tree/a.txt"
third=$(node "$root/scripts/hash-tree.mjs" "$test_tmp/tree")

node - "$first" "$third" <<'NODE'
const [first, third] = process.argv.slice(2).map(JSON.parse);
if (first.aggregateSha256 === third.aggregateSha256) process.exit(1);
NODE

echo "PASS: tree hashing is stable and change-sensitive"
