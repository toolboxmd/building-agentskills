#!/usr/bin/env bash
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$root/scripts/build-llms.ts"
out="$root/public/llms.txt"

if [ ! -f "$script" ]; then
  echo "EXPECTED-MISSING-SCRIPT: scripts/build-llms.ts" >&2
  exit 1
fi

cd "$root"
if ! npm run build:llms >/dev/null; then
  echo "FAIL: npm run build:llms exited non-zero" >&2
  exit 1
fi

block="$(awk '/<!-- TOOLS:START -->/{flag=1;next}/<!-- TOOLS:END -->/{flag=0}flag' "$out")"
if ! printf '%s\n' "$block" | grep -q '^### Hero$'; then
  echo "FAIL: '### Hero' missing between TOOLS markers" >&2
  exit 1
fi
if ! printf '%s\n' "$block" | grep -q '^### Authoring$'; then
  echo "FAIL: '### Authoring' missing between TOOLS markers" >&2
  exit 1
fi
bullets="$(printf '%s\n' "$block" | grep -c '^- ' || true)"
if [ "$bullets" -lt 24 ]; then
  echo "FAIL: only $bullets bullets between TOOLS markers (need >=24)" >&2
  exit 1
fi
echo "OK: build-llms"
