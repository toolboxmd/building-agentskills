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

## Post-run exact-HEAD review amendment

Exact-HEAD reviews of commits `223e49d8697141b13c53fec249d5b5ebb3682f75`,
`46938699eb21ad3f6167f147f956781704976b35`, and
`91533764d5c2336f7876f2565405e7ae74090a2f`, followed by review of
`e5c5e8bceed532ff6a9968448a06edf13a69365c` and
`5ef565ad6f251ec2b87686271e985f622f64c22d` and then
`705e5eafd43b9164797243f1a2bb250cbb6f2a4b` and
`03c55051faa0d53e3e50e0db57debaa3306a09b6`, found nine findings after the
authoring outputs and deterministic grades had already been recorded.

The active Grok product could accept a direct or enveloped success without a
runtime init event and without applying the complete inspect allowlist. The
active product now requires the strict inspect fallback whenever init is
missing. This changes the live active package after the run, not the historical
acceptance-refined reference scored below.

The frozen grader's PID-existence probe could treat a terminated Linux zombie
as a live timeout child. The live diagnostic harness now treats Linux `Z`, `X`,
and `x` process states as terminated. The preregistered files remain unchanged;
`post-run-amendment.json` binds their original hash and commit to the live
post-review code. Stored deterministic grades remain historical evidence from
the preregistered grader.

The active Grok product's evidence redaction could miss a JSON-escaped copy of
a protected multiline or quote-containing prompt. It now removes literal,
UTF-8 JSON-escaped, and ASCII JSON-escaped variants before retaining evidence.

The active Grok product's pre-call input filter recognized only a short vendor
list. It now rejects generic credential assignments, including API keys, secret
keys, tokens, credentials, and database connection values, before invoking
Grok. A regression keeps an ordinary `MONKEY` assignment outside that boundary.

The structural skill and benchmark result are now discoverable from the
repository wiki index and log. No pending wiki capture was created.

Applying the credential-assignment pattern to an already serialized structured
review could consume JSON syntax and turn a valid response into an input error.
Structured review strings are now redacted recursively before serialization,
so credential-shaped review examples remain redacted without corrupting JSON.

Parser-level invalid input previously exited through argparse before the stable
status contract could run. Invalid mode, nonnumeric timeout, and missing
required-argument fixtures now each receive one `input` JSON object on stdout,
exit code 2, no stderr usage text, and no run directory.

Output-directory resolution or creation could also fail before the handler and
produce a traceback. Those operations now return one `input` JSON object with
exit code 2 and omit `runDir` when no evidence directory could be retained.

The frozen network preflight treated any nonzero curl result as denial. The
retained exit-6 DNS failures therefore do not independently prove sandbox
network enforcement. The live harness now starts a loopback HTTP endpoint,
requires an unsandboxed HTTP 200 control, and then requires the sandboxed probe
against that same live endpoint to fail. A model-free preflight-only run passed
with host HTTP 200 and sandboxed curl exit 7. Historical preflight artifacts and
grades remain unchanged, while their network-isolation claim is explicitly
insufficient.

None of these corrections changes the token-cap abort, starts semantic judging,
or makes ranking permissible.

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
