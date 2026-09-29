#!/usr/bin/env bash
# Set the version in package.json, package-lock.json and .claude-plugin/plugin.json.
# Usage: bump-version.sh X.Y.Z (choose the level with the rule in AGENTS.md).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
version="${1:?usage: bump-version.sh X.Y.Z}"
if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "FAIL: '$version' is not X.Y.Z" >&2
  exit 1
fi
npm version "$version" --no-git-tag-version --allow-same-version >/dev/null
node -e '
const fs = require("fs");
const p = ".claude-plugin/plugin.json";
const j = JSON.parse(fs.readFileSync(p, "utf8"));
j.version = process.argv[1];
fs.writeFileSync(p, JSON.stringify(j, null, 2) + "\n");
' "$version"
echo "Set version $version. Add a '## [$version]' CHANGELOG.md entry and commit."
echo "After the user merges, the maintainer tags the merge commit: git tag v$version <merge-sha> && git push origin v$version"
