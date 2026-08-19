---
name: toolboxmd-use-grok
description: Ask a locally installed Grok or Grok Build CLI for a bounded second opinion when the user explicitly requests Grok review in Polish or English, then reconcile its advice. Do not use for implicit or automatic review, brainstorming, status, Grok-response summaries, unchanged repeat reviews, nested-agent benchmarks, opt-outs, or content unsafe to send externally.
---

# Use Grok for an explicit review

Use this skill only when the user explicitly asks to ask, send, pass, delegate to, or obtain an opinion from Grok or Grok Build. The public default is explicit consultation only. Never present Grok as authoritative and never copy its response blindly.

## Default path

1. Confirm that external review is allowed and useful. Stop if the user opts out, a benchmark forbids nested agents, or the material contains credentials, `.env` content, private memory, unrelated worktree content, or anything else that cannot safely leave the session.
2. Create a minimal prompt file containing only the question or mature plan and context needed to review it. Remove secrets and unrelated content. Tell Grok not to invoke any agentic CLI.
3. Choose a fresh empty output directory. Use the locally configured Grok executable and authenticated Grok home supplied by the operator; do not discover credentials or copy them into staging.
4. Run the adapter once in explicit mode:

   ```text
   scripts/consult-grok --mode explicit --prompt-file FILE --output-dir DIR --grok-home DIR --grok-bin FILE --timeout SECONDS --max-turns INTEGER
   ```

5. Parse the single JSON status object on stdout. On `ok`, inspect its `review` and retained evidence. On any other status, stop the explicit consultation and report that concrete failure; do not silently continue or retry with weaker isolation.
6. Reconcile the review against the task evidence. Report advice accepted, rejected, and changed, with reasons. Surface any item in `user_decisions` to the user.

## Review contract

Accept one verdict: `PROCEED`, `PROCEED WITH CHANGES`, `REPLAN`, or `NEEDS HUMAN DECISION`. Require arrays named `overengineering`, `missing`, `risks`, `minimum_plan_delta`, and `user_decisions`, with no extra fields. Treat the review as advice, not proof.

Keep the exchange bounded to one consultation. Do not ask Grok to process its own response, repeat an unchanged plan already reviewed at the same normalized content hash, or begin an agent loop.

## Automatic mode

Automatic mature-plan review is not available in this package. Although the adapter accepts `--mode automatic`, it fails closed without invoking Grok because no stable dedicated authenticated profile has passed real acceptance. Do not work around this gate. A future personal policy may enable one review only after automatic isolation and real acceptance are separately proven.

Automatic review must also exclude brainstorming, trivial two-step work, status reporting, same-plan hashes, Grok-response processing, nested-agent benchmarks, explicit opt-out, and unsafe external content. If optional automatic review fails, report it as skipped; if the user made review mandatory, stop instead.

## Failure meanings

The adapter returns `missing-cli`, `isolation-failure`, `nonzero-exit`, `timeout`, `invalid-json`, `incomplete-stop-reason`, or `max-turns`. Evidence is redacted but may still contain task content; keep the output directory private and delete it according to the task's retention policy. Never paste credentials into a prompt or command line.
