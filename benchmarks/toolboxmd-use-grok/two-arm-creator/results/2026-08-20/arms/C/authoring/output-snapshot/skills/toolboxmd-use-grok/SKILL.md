---
name: "toolboxmd-use-grok"
description: "Ask a local Grok Build CLI for a bounded second opinion when the user explicitly requests Grok, then critically reconcile its structured review. Use for Polish or English requests to ask, send, pass, or delegate a brief or implementation plan to Grok. Automatic review is implemented but disabled until a dedicated authenticated profile passes real acceptance."
---

# Use Grok for a second opinion

Invoke this skill only when the user explicitly asks to consult Grok or Grok Build. Recognize Polish and English requests to ask, send, pass, delegate for review, or obtain Grok's opinion. Do not imply that Grok is a subagent or that its advice is authoritative.

## Public policy

- Default to `explicit` mode.
- Never initiate `automatic` mode under this package version. The adapter implements it as a fail-closed, non-invoking refusal because no stable dedicated authenticated profile has passed real acceptance.
- Do not substitute another model, agent, CLI, or network service if consultation fails.
- Do not process Grok's response by recursively asking Grok again.

Even under a future separate opt-in policy, automatic review is unsuitable for brainstorming, trivial two-step work, status reports, an unchanged plan already reviewed at the same normalized content hash, Grok-response processing, benchmarks forbidding nested agents, explicit opt-out, or content unsafe to send externally.

## Prepare the brief

Create a temporary UTF-8 prompt file containing only the question or mature plan and the minimum context needed to review it. Exclude credentials, `.env` content, unrelated memory, unrelated worktree content, private data not necessary for the question, and project instructions. If safe minimization is impossible, stop without invoking the adapter and explain why.

Ask for one verdict: `PROCEED`, `PROCEED WITH CHANGES`, `REPLAN`, or `NEEDS HUMAN DECISION`. Require `overengineering`, `missing`, `risks`, `minimum_plan_delta`, and `user_decisions`. Tell Grok not to invoke any agentic CLI.

## Invoke the adapter

Resolve `<skill-dir>` from this loaded `SKILL.md`. Supply an operator-selected local CLI path and profile; do not discover credentials or search user files. Use an output directory outside this package. Run:

```sh
"<skill-dir>/scripts/consult-grok" --mode explicit --prompt-file "$PROMPT_FILE" --output-dir "$EVIDENCE_DIR" --grok-home "$GROK_PROFILE" --grok-bin "$GROK_BIN" --timeout 60 --max-turns 2
```

The adapter writes exactly one status object to stdout. Treat only `status: "ok"` as a completed consultation. For `missing-cli`, `isolation-failure`, `nonzero-exit`, `timeout`, `invalid-json`, `incomplete-stop-reason`, or `max-turns`, stop the explicit consultation and report that concrete category. Do not retry with weaker isolation or broader permissions.

## Reconcile

Read the structured review from the successful status object. Evaluate each point against the user's goals and local evidence; do not copy it blindly. Report:

- advice accepted and why;
- advice rejected and why;
- changes made to the plan or answer;
- unresolved user decisions.

Preserve the adapter's evidence directory for audit, but do not quote raw evidence if it could reveal sensitive material. The adapter's controls reduce exposure; semantic prompt minimization remains the invoking agent's responsibility.

## Enforcement boundary

The adapter uses an argv array, a fresh staged working directory, a restricted environment, configuration inspection, an agent with no tools, bounded turns, a read-only permission mode, structured output, and a separate process-tree timeout. It rejects runtime tool calls and unsafe inspect state, accepts direct or enveloped structured output, redacts evidence, and classifies frozen failures. These checks establish local mechanical conditions, not the quality or correctness of Grok's advice.
