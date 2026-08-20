---
name: "toolboxmd-use-grok"
description: "Ask a locally installed Grok Build CLI for a bounded second opinion when the user explicitly asks to send, pass, delegate, or request review from Grok in Polish or English. Reconcile its structured advice; do not use for implicit or automatic review."
---

# Use Grok

Obtain a bounded second opinion from Grok Build without treating its output as authority.

## Activation

Use this skill only when the user explicitly asks in Polish or English to ask, send, pass, or delegate material to Grok or Grok Build, or requests its review/opinion.

Do not activate for brainstorming, trivial work, status reporting, processing Grok's own response, an unchanged plan already reviewed, a benchmark forbidding nested agents, explicit opt-out, or material that cannot safely be sent externally.

Automatic mature-plan review is not a public default. The adapter implements `--mode automatic` as a fail-closed disabled path because no stable, dedicated, authenticated profile has passed real acceptance. Do not work around that result.

## Prepare the consultation

1. Confirm the request is explicit and the content is safe to disclose to the configured external service.
2. Exclude credentials, `.env` content, unrelated memory, unrelated worktree content, personal data not needed for review, and project instructions.
3. Create a minimal UTF-8 prompt file containing only the question or mature plan and necessary context. Tell Grok not to invoke any agentic CLI.
4. Choose a fresh output directory outside this skill. Never place evidence in the package.
5. Invoke the adapter from the loaded skill directory:

```sh
"<skill-dir>/scripts/consult-grok" --mode explicit --prompt-file "<prompt-file>" --output-dir "<output-dir>" --grok-home "<dedicated-grok-home>" --grok-bin "<grok-executable>" --timeout 60 --max-turns 1
```

Pass prompt content only through `--prompt-file`; never put it in a shell command or argument. Use an explicit executable file and dedicated Grok home supplied by the operator. Do not call the CLI directly.

## Handle the result

Read the adapter's single JSON status object from stdout.

- On `status: "ok"`, inspect `review` and the evidence directory. Accept, reject, or modify each material recommendation based on the task's constraints and primary evidence.
- Report the verdict and which advice was accepted, rejected, or changed, with reasons. Surface every requested `user_decisions` item.
- Do not copy advice blindly, recursively consult Grok about its response, or claim the review proves correctness.
- For explicit mode, any non-`ok` status stops the consultation. Report its concrete category and concise detail; do not silently continue as if review succeeded.
- Automatic mode's expected `isolation-failure` means skipped review. Main work may continue only when review was optional; a mandatory review remains blocked.

Expected failures are `missing-cli`, `isolation-failure`, `nonzero-exit`, `timeout`, `invalid-json`, `incomplete-stop-reason`, and `max-turns`.

## Output contract

A valid review has exactly these fields: `verdict` (`PROCEED`, `PROCEED WITH CHANGES`, `REPLAN`, or `NEEDS HUMAN DECISION`) and arrays `overengineering`, `missing`, `risks`, `minimum_plan_delta`, and `user_decisions`. No additional fields are accepted.

Evidence contains redacted raw stdout/stderr, invocation metadata, session identifier, usage, stop reason, and the parsed review. Treat evidence as potentially sensitive task data and retain it only as long as needed.
