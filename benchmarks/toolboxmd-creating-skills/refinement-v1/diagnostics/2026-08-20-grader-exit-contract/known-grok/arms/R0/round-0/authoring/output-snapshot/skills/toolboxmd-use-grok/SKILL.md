---
name: "toolboxmd-use-grok"
description: "Ask Grok or Grok Build for a bounded second opinion when the user explicitly requests it, then reconcile the review. Use for Polish or English requests to ask, send, pass, or delegate a brief or plan to Grok. Automatic plan review is disabled until a dedicated authenticated profile passes real isolation acceptance."
---

# Use Grok

Obtain a bounded external review without treating it as authority. The calling agent owns privacy, final judgment, and the explanation to the user; the adapter owns deterministic isolation and evidence.

## Activation

Use this skill only when the user explicitly asks to ask, send, pass, or delegate material to Grok or Grok Build for an opinion or review, including equivalent Polish requests such as “zapytaj Groka” or “przekaż Grok Build”.

Do not activate merely because a plan exists. Automatic review is an optional personal-policy behavior, not the public default, and the adapter currently rejects `--mode automatic` fail-closed. Also do not review:

- open brainstorming, trivial work, or status reporting;
- Grok's own response or an unchanged plan already reviewed at the same normalized-content hash;
- work that forbids nested agents, or when the user opts out;
- credentials, secrets, `.env` content, private data, unrelated memory, or unrelated worktree content.

If the user's explicit request contains unsafe external content, stop and ask for a sanitized brief. Never weaken isolation to complete a consultation.

## Prepare the brief

Create a UTF-8 prompt file outside this skill package containing only the question or mature plan and the minimum context needed. Remove credentials, private identifiers, unrelated files, instructions to invoke other agentic CLIs, and unnecessary source text. State that Grok must not use tools, agents, agentic CLIs, MCP, web, memory, or project context.

Ask for exactly this review object:

- `verdict`: `PROCEED`, `PROCEED WITH CHANGES`, `REPLAN`, or `NEEDS HUMAN DECISION`;
- arrays `overengineering`, `missing`, `risks`, `minimum_plan_delta`, and `user_decisions`.

## Run

Resolve `<skill-dir>` from this loaded `SKILL.md`. The operator must provide an existing dedicated `--grok-home`, the Grok executable path, an evidence output directory, a positive timeout, and a positive bounded turn count.

```sh
"<skill-dir>/scripts/consult-grok" --mode explicit --prompt-file "<prompt-file>" --output-dir "<output-dir>" --grok-home "<grok-home>" --grok-bin "<grok-bin>" --timeout 120 --max-turns 3
```

Do not call the CLI directly or add approval/yolo flags. The adapter emits exactly one JSON status object. Treat `status: "ok"` as a completed review. For an explicit request, any other status stops the consultation and must be reported by its concrete category: `missing-cli`, `isolation-failure`, `nonzero-exit`, `timeout`, `invalid-json`, `incomplete-stop-reason`, or `max-turns`. Do not silently retry, change profiles, or continue as though review succeeded.

Automatic mode remains intentionally unavailable. If a separate policy requests it, one review may eventually occur only after a coherent executable plan exists and before presenting or executing it, but only after a stable dedicated authenticated profile passes real acceptance. Until then, its `isolation-failure` result means “skipped”; continue only if review was optional.

## Reconcile

Read the structured review and its evidence location. Evaluate every suggestion against the user's goal, constraints, and primary evidence. Never copy advice blindly or let Grok expand scope.

Report to the user:

1. the verdict and material risks;
2. advice accepted and why;
3. advice rejected and why;
4. changes made to the plan;
5. unresolved user decisions.

Keep the retained run directory for audit only as long as needed. It contains staged prompt material plus redacted stdout, stderr, effective-inspection data, and invocation metadata; handle it at the same sensitivity as the prompt.
