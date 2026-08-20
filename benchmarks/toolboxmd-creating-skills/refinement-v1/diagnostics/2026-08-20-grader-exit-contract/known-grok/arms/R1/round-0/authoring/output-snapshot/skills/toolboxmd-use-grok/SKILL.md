---
name: "toolboxmd-use-grok"
description: "Ask the local Grok Build CLI for a bounded second opinion when a user explicitly asks in English or Polish to ask, send, pass, or delegate a plan or brief to Grok/Grok Build, then reconcile its review. Do not use for implicit or automatic review; automatic mode remains disabled until a dedicated authenticated profile passes real isolation acceptance."
---

# Use Grok

Obtain a bounded review from Grok without treating its advice as authoritative.

## Activate only on an explicit request

Use this skill when the user explicitly asks, in English or Polish, to ask, send, pass, or delegate a question, brief, proposal, or implementation plan to Grok or Grok Build, or asks for Grok's opinion/review.

Do not activate for ordinary brainstorming, trivial work, status reporting, summarizing Grok's existing response, an unchanged plan already reviewed at the same normalized-content hash, a benchmark forbidding nested agents, an explicit opt-out, or material that cannot safely leave the session.

Automatic plan review is not a public default. Even if a separate personal policy opts in, automatic mode is disabled until a stable dedicated authenticated `GROK_HOME` passes real acceptance. Never bypass that fail-closed result.

## Prepare the consultation

1. Confirm the request is explicit. If sending the content could disclose credentials, `.env` data, private or unrelated memory, or unrelated worktree content, stop and ask for a safe redacted brief.
2. Create a UTF-8 prompt file containing only the question or mature plan and the minimum context needed to review it. Exclude secrets, unrelated repository content, instructions from other projects, and Grok's prior response.
3. Ask for exactly one verdict: `PROCEED`, `PROCEED WITH CHANGES`, `REPLAN`, or `NEEDS HUMAN DECISION`. Ask it to identify overengineering, missing items, risks, the minimum plan delta, and user decisions. Tell it not to invoke an agentic CLI.
4. Choose a new output directory outside the skill package. Locate the operator-provided Grok binary and Grok home; do not discover credentials or copy authentication into the prompt, staging area, or evidence.

## Run the adapter

Resolve `<skill-dir>` from this loaded `SKILL.md`, then run:

```sh
"<skill-dir>/scripts/consult-grok" --mode explicit --prompt-file "<prompt-file>" --output-dir "<output-dir>" --grok-home "<grok-home>" --grok-bin "<grok-bin>" --timeout 120 --max-turns 1
```

Pass every value as a separate argument. Never put prompt content on a command line or interpolate it into a shell command. Do not call Grok directly; the adapter owns isolation preflight, staging, process limits, parsing, and evidence.

Read the single JSON status object from stdout. On `status: "ok"`, read the returned review and evidence paths. For any other status, stop the explicit consultation and report its concrete category: `missing-cli`, `isolation-failure`, `nonzero-exit`, `timeout`, `invalid-json`, `incomplete-stop-reason`, or `max-turns`. Do not retry with weaker isolation.

## Reconcile rather than copy

Evaluate every suggestion against the user's goals and available evidence. Report:

- advice accepted and why;
- advice rejected and why;
- changes made to the plan or answer and why;
- any decision still requiring the user.

Preserve Grok's verdict as advice, not as a substitute for judgment. Do not recursively send Grok's response back to Grok, and perform at most one consultation for unchanged normalized content.

## Adapter outputs and limits

The adapter uses a fresh staged directory, an isolated environment, read-only/no-memory/no-subagent/no-web instructions, structured output, bounded turns, and a separate process-tree timeout. It rejects unexpected effective configuration and runtime tool calls. It writes redacted stdout/stderr plus invocation metadata and the parsed review under the requested output directory. Evidence must not be treated as safe to publish without review.
