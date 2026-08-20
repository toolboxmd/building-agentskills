---
name: "safe-archive-inspector"
description: "Inspect an untrusted TAR or ZIP using metadata only, explicit entry and declared-size budgets, and a fail-closed path/type policy before a human extraction decision. Use when asked to inspect, screen, audit, or list an untrusted archive; not for compression questions, archive creation, or extracting a trusted archive."
---

# Safe Archive Inspector

Inspect an untrusted TAR or ZIP without extracting it or opening member payloads. The helper is the policy mechanism; do not reproduce its checks by hand.

## Invoke

The user invokes this skill, or an agent explicitly selects it, for requests to inspect, screen, audit, or list an untrusted archive before a human decides whether to extract it.

Do not select it for ordinary compression questions, archive creation, or requests to extract a trusted archive. This skill never authorizes or performs automatic extraction.

Obtain both positive integer budgets from the caller: maximum entry count and maximum total declared bytes. If either is absent, ask for it; do not invent a limit.

Resolve `<skill-dir>` from this loaded `SKILL.md`, then run:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/inspect_archive.py" --archive "<path>" --max-entries "<positive-int>" --max-total-bytes "<positive-int>"
```

Run the helper directly. Do not extract, mount, preview, or open any member, and do not pass the archive to another archive tool as part of this workflow.

## Interpret the result

The helper writes exactly one compact JSON object to stdout, leaves stderr empty, and uses these statuses and exits:

- `safe`, exit 0: no violation was found within this metadata-only frozen policy and the supplied budgets.
- `unsafe`, exit 1: one or more policy violations are listed in `issues`.
- `error`, exit 2: input was invalid or the archive was malformed or unsupported.

The object also reports `format`, `entryCount`, and the sum of declared uncompressed member sizes as `declaredBytes`. Treat every issue code as decisive. Report the JSON result and explain issue codes plainly when useful.

`safe` does not mean malware-free, payload-safe, authentic, or safe to extract. It is only a metadata-policy result. Preserve that boundary in the response and leave every extraction decision and action to a human.

## Frozen policy

The helper fails closed on:

- empty, absolute POSIX, Windows drive or UNC paths;
- NUL or other ASCII controls, or any `..` component after slash/backslash normalization;
- duplicate normalized paths or case-insensitive normalized collisions;
- TAR symbolic/hard links and ZIP symbolic links;
- TAR/ZIP special files and encrypted ZIP members;
- entry-count or total-declared-size budget excess;
- malformed, unsupported, or unreadable inputs.

Only regular files and directories are allowed. Limits use archive metadata before any payload access. Python TAR extraction defaults are irrelevant because this workflow never extracts.
