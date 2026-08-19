---
name: "toolboxmd-use-grok"
description: "Ask the local Grok Build CLI for a bounded second opinion when the user explicitly says to ask, send, pass, delegate to, or get an opinion from Grok. Use for Polish and English requests. Do not auto-review plans from this public skill; automatic review requires a separate opt-in policy and accepted isolation."
---

# Use Grok

Ask Grok for a bounded second opinion, then reconcile it with the task evidence. Grok's answer is a proposal, not authority.

## Boundaries

- Public default: run only when the user explicitly asks for Grok or Grok Build.
- Automatic mature-plan review requires a separate personal opt-in policy and accepted isolation. This skill does not enable that policy.
- Do not use automatic review during brainstorming, trivial work, status reporting, Grok-response processing, a nested-agent benchmark, explicit opt-out, an unchanged reviewed plan hash, or unsafe external content.
- Implementation or repository mutation by Grok is outside this version.

## Explicit consultation

1. Confirm the requested question and prepare the smallest self-contained brief. Include only context needed for the opinion.
2. Exclude credentials, secrets, `.env` content, unrelated memory, and unrelated repository content. If safe minimization is not possible, stop and explain why.
3. Resolve `<skill-dir>` from this loaded `SKILL.md`. Choose an evidence directory outside the installed skill and a prompt file outside the product package.
4. Run:

```bash
"<skill-dir>/scripts/consult-grok" \
  --mode explicit \
  --prompt-file "<brief-path>" \
  --output-dir "<evidence-dir>"
```

Pass `--grok-home "<dedicated-profile>"` when the user selected a profile. Never copy `auth.json` or credentials into a temporary directory.

An explicit consultation failure is blocking because the user asked for Grok. Report the adapter's error category, evidence directory, and safe recovery action.

## Optional automatic plan review

Use this path only when a personal instruction explicitly opts in and the adapter's automatic acceptance is recorded as passing.

Automatic review is currently disabled. The adapter fails closed before consultation. The synthetic real acceptance used the default authenticated profile and did not behaviorally prove the deny rules. Do not enable a personal policy until a dedicated authenticated profile and a new acceptance establish both boundaries.

Before review, require a coherent, executable implementation plan. Normalize its content conceptually and track one review per content hash in the current task. Do not persist state until repeated reviews demonstrate that deterministic storage is needed.

Run the adapter with `--mode automatic` and an explicitly selected stable dedicated `--grok-home`. Automatic mode fails closed when its profile, version, auth presence, or effective configuration cannot prove isolation. A failed optional review is reported as skipped and normal work may continue unless the user made Grok mandatory.

## Review request

Ask Grok to review only the supplied brief, not inspect the repository. Tell it not to call Codex, Claude, Grok, or another agentic CLI. Request this structure:

```text
VERDICT: PROCEED | PROCEED WITH CHANGES | REPLAN | NEEDS HUMAN DECISION

OVERENGINEERING:
MISSING:
RISKS:
MINIMUM PLAN DELTA:
USER DECISIONS:
```

The adapter supplies the equivalent strict JSON Schema and retains redacted raw process evidence.

## Reconcile

Read `review.json` and `metadata.json` from the reported run directory. Return a short reconciliation:

- Grok verdict and material rationale;
- advice accepted, with evidence;
- advice rejected, with reasons;
- minimum changes made to the plan;
- decisions that still belong to the user.

Do not silently replace the plan. Keep the revised plan no larger than required to address accepted findings.

## Gotchas

- An empty `GROK_HOME` does not isolate user `.agents` skills or Cursor MCP discovery when the normal `HOME` remains visible.
- `grok inspect` reports discovered configuration, while the runtime init event reports what the session actually exposes. Preserve their minimized summaries, not unrelated skill descriptions.
- A restrictive Grok allowlist still advertises `todo_write`, `search_tool`, and `use_tool`. The adapter denies the underlying `Read` and `MCPTool` access classes and rejects any observed tool call. The current deny claim is source-backed, not behaviorally accepted.
- `--json-schema` implies JSON output in Grok 1.0.3. The adapter explicitly requests `streaming-messages-json` as well because automatic mode must inspect the runtime init event; a missing init fails closed.
- `--max-turns` limits model rounds; the adapter's wall-clock timeout is a separate process-tree boundary.
- A zero exit code is insufficient. Completion requires valid schema output and an `end_turn` stop reason.
