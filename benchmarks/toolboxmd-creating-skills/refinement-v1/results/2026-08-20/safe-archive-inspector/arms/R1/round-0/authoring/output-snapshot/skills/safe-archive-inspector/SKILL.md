---
name: "safe-archive-inspector"
description: "Inspect or audit an untrusted TAR or ZIP before a human extraction decision. Use when a user explicitly asks to screen, inspect, list, or audit an archive. Do not use for general compression questions, archive creation, or extraction of a trusted archive."
compatibility: "Requires Python 3.9 or later; uses only the Python standard library."
---

# Safe Archive Inspector

Screen an untrusted TAR or ZIP using metadata only. This skill is user-invoked
or explicitly selected; never extract automatically.

## Inputs

Require all three:

- an archive filesystem path;
- a positive maximum entry count;
- a positive maximum total of member sizes declared in metadata.

If a budget is missing, ask for it. Do not invent a permissive limit.

## Inspect

Resolve this loaded `SKILL.md` to its absolute directory, then run exactly one
inspection command:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/inspect_archive.py" --archive "<archive-path>" --max-entries "<positive-int>" --max-total-bytes "<positive-int>"
```

The helper writes exactly one compact JSON object to stdout and nothing to
stderr. Exit 0 means `safe`, 1 means `unsafe`, and 2 means input or archive
error. Treat the JSON `status` as authoritative rather than relying only on the
process exit status.

The frozen policy rejects:

- empty, absolute POSIX, Windows drive or UNC paths;
- paths containing NUL/ASCII control characters or a `..` segment after
  converting backslashes to slashes;
- duplicate normalized paths and case-insensitive normalized collisions;
- TAR symbolic links, hard links, devices, FIFOs, and other non-file/non-directory types;
- ZIP symbolic links, special types, and encrypted members;
- entry counts or summed declared sizes above the supplied budgets;
- malformed or unrecognized archives.

The helper never extracts members, opens member payloads, calls the network,
starts a subprocess, or modifies the archive. It counts archive members and
sums nonnegative sizes declared in TAR headers or the ZIP central directory.

## Report

Report `format`, `entryCount`, `declaredBytes`, and every code in `issues`.
Explain that `safe` means only that no violation was found under this
metadata-only policy and these budgets. It does not establish that payloads are
malware-free, safe, authentic, or safe to extract. Leave extraction to a human
decision and a separately controlled process.

Issue codes are: `INPUT`, `ARCHIVE_INVALID`, `PATH_EMPTY`, `PATH_ABSOLUTE`,
`PATH_PARENT`, `PATH_CONTROL`, `PATH_DUPLICATE`, `PATH_CASE_COLLISION`,
`TYPE_LINK`, `TYPE_SPECIAL`, `ZIP_ENCRYPTED`, `ENTRY_LIMIT`, and `SIZE_LIMIT`.

## Gotchas

- Python 3.14 TAR extraction defaults do not make an archive safe; this helper
  does not use extraction filters because it never extracts.
- Both slash styles are path separators for policy checks, regardless of the
  host operating system.
- A clean metadata result is not permission to extract.
