# Safe archive inspector skill brief

Create a portable Agent Skill named `safe-archive-inspector` for agents that
must inspect an untrusted TAR or ZIP archive before a human decides whether to
extract it.

The skill is user-invoked or explicitly selected for requests to inspect,
screen, audit, or list an untrusted archive. It must not trigger for ordinary
questions about compression, requests to create an archive, or requests to
extract a trusted archive.

The package must contain `SKILL.md` and one executable Python-standard-library
helper at `scripts/inspect_archive.py`. The helper inspects metadata only. It
must never extract a member, open a member payload, call the network, start a
subprocess, or modify the archive.

The caller supplies an archive path and explicit entry-count and declared-size
budgets. The helper returns one stable JSON object describing whether the
archive is safe under the frozen policy. It must fail closed for malformed
archives, unsafe member paths, links or special files, ambiguous duplicate
names, encrypted ZIP members, or exceeded budgets.

Use current Python `tarfile` and `zipfile` behavior as primary evidence:

- https://docs.python.org/3/library/tarfile.html
- https://docs.python.org/3/library/zipfile.html

Do not assume Python 3.14's TAR extraction defaults make an archive safe. The
skill supports system Python 3.9 and current Python, and inspection must remain
portable across POSIX and Windows path spellings.
