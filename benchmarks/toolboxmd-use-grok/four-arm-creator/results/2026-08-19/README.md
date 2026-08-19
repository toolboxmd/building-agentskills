# Four-arm Creator diagnostic result

## Verdict

`INELIGIBLE_TOKEN_CAP`

This execution does not identify a winning Creator. Arms C and D exceeded the
pre-registered 750,000 input-token cap, so the whole four-arm comparison became
ineligible for ranking. The semantic judge, paired repeat, and held-out stages
were not started. Raising the cap after seeing these outputs would invalidate
the pre-registration, so these artifacts remain diagnostic evidence only.

All four control and model preflights passed. Every authoring process exited
zero within 600 seconds, and every arm produced the required two-file Grok
package without symlinks. No real Grok call occurred. Automatic Grok review
remains disabled.

## Authoring observations

| Arm | Treatment | Input tokens | Cap status | Duration | Candidate | Deterministic diagnostic |
|---|---|---:|---|---:|---:|---:|
| A | legacy ToolboxMD | 747,055 | pass by 2,945 | 323.630 s | 15,238 B | 35/70 |
| B | early vNext `bfbd679` | 598,371 | pass by 151,629 | 366.076 s | 20,691 B | 35/70 |
| C | final vNext `20fc268` | 831,996 | fail by 81,996 | 380.062 s | 20,031 B | 43/70 |
| D | frozen built-in Codex | 1,151,683 | fail by 401,683 | 429.756 s | 16,354 B | 43/70 |

The deterministic values are descriptive because the abort gate had already
made ranking impossible. Every generated artifact had at least one critical
contract failure and therefore none is recommendable as generated.

## Deterministic failure boundary

A and B did not retain the required `review.json` object for direct, envelope,
or streaming success fixtures. C and D did retain it.

All four candidates:

- missed the exact frozen Grok CLI argument and tool allow-list contract;
- invoked the fake CLI for credential-shaped prompt input instead of rejecting
  it before the call;
- classified a result-error event as `nonzero-exit` instead of
  `incomplete-stop-reason`;
- accepted timeout `601` and max-turns `9` instead of rejecting those frozen
  upper-bound violations before invocation.

All four passed the exact two-file shape, executable stdlib-Python adapter,
product budgets, inspect fail-closed behavior, portable-frontmatter check,
timeout process-tree cleanup, and automatic-mode fail-closed behavior.

The unranked historical raw Grok reference scored 35/70. The separately
acceptance-refined Grok reference scored 70/70 with no critical failure. This
supports only the narrow conclusion that post-generation acceptance work closed
the frozen contract gaps. It does not identify which Creator is generally
better.

## Custom ToolboxMD validator diagnostic

This check is deliberately unscored. It applies the final vNext validator's
`toolboxmd-portable-core-v2` subset and cannot decide the Creator comparison.

| Arm | Result | Errors | Narrow observation |
|---|---|---:|---|
| A | fail | 5 | required canonical frontmatter strings plus one unfenced helper example |
| B | fail | 2 | `name` is outside the validator's canonical one-line JSON-string form |
| C | pass | 0 | accepted under the frozen custom validator profile |
| D | fail | 6 | required canonical frontmatter strings plus two unfenced helper examples |

The validator script SHA-256 is
`f49186278510607eeb5dff2571dcb0ae70ed8cf90465e7f7b32dc92724af2713`.
The exact limits and issue codes are retained in `summary.json` and rechecked by
the result regression test.

## Decision boundary

There are two honest next states:

1. accept this as a completed, ineligible diagnostic and retain the four
   outputs as failure evidence; or
2. pre-register a new common input-token cap and run all four arms again from
   fresh contexts.

The current outputs must not be reused as ranked results under a larger cap.
Any new real Grok call or automatic-mode acceptance remains a separate user
decision.
