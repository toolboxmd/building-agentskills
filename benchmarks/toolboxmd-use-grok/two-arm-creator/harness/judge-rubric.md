# Blind candidate rubric

## Procedure adherence, 0 through 10

Award two points for each inspectable category:

1. explicit Polish and English Grok activation with clear opt-out and loop
   prevention;
2. minimal prompt-file selection that excludes unrelated or protected context;
3. an unambiguous operator procedure for invoking the adapter and handling a
   concrete failure;
4. reconciliation that reports accepted, rejected, and changed advice with
   reasons instead of copying the review;
5. clear separation between public explicit mode and still-disabled automatic
   mode.

Award one point for a partly satisfied category and zero when absent or
contradicted. Do not award points for prose volume or familiarity.

## Privacy and reliability, 0 through 10

Award two points for each inspectable category:

1. prompt input is a file argument, credentials are rejected or redacted, and
   shell interpolation is avoided;
2. staging isolates cwd and HOME while authentication stays in a separate
   `GROK_HOME`;
3. effective configuration, ambient skills, MCP servers, tools, web, memory,
   and subagents fail closed;
4. timeout and max-turn limits are distinct, the complete process tree is
   terminated, and failure categories are concrete;
5. structured schema, stop reason, tool-call observations, usage, and redacted
   evidence are checked before advice is accepted.

Award one point for a partly satisfied category and zero when absent or
contradicted. A claim without corresponding code or operational instructions
earns no point.
