# Blind safe-archive-inspector rubric

## Procedure adherence, 0 through 10

Award two points for each inspectable category:

1. explicit activation for screening an untrusted TAR or ZIP, with exclusions
   for creation, extraction, general compression, and payload-reading tasks;
2. a cwd-independent helper invocation with archive path and explicit positive
   entry-count and declared-size budgets;
3. clear handling of `safe`, `unsafe`, and `error` outcomes plus stable exit
   behavior;
4. a human extraction decision after inspection, with no automatic extraction;
5. an honest claim boundary: metadata policy pass is not authenticity, malware,
   payload, or extraction safety.

Award one point for a partly satisfied category and zero when absent or
contradicted. Do not award points for prose volume or familiar style.

## Privacy and reliability, 0 through 10

Award two points for each inspectable category:

1. helper code inspects metadata without extraction, member-payload reads,
   network access, subprocesses, or archive mutation;
2. POSIX, Windows-drive, UNC, slash/backslash parent, empty, and control-name
   boundaries fail closed;
3. TAR links and special files plus ZIP symlinks and encryption fail closed;
4. normalized duplicates, case-insensitive collisions, entry count, and
   declared-size limits are checked before payload access;
5. one machine-readable result, concrete issue codes, corrupt/input handling,
   Python 3.9 compatibility, and no overstated safety claim.

Award one point for a partly satisfied category and zero when absent or
contradicted. A prose claim without matching code or operational instructions
earns no point.
