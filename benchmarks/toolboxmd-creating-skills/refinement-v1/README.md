# Creator vNext bounded acceptance-refinement benchmark

This preregistered diagnostic compares two frozen Creator packages:

| Arm | Treatment | Package |
|---|---|---:|
| R0 | merged Creator vNext at `20fc268` | 46,953 B |
| R1 | bounded-refinement candidate at `abe2fd3` | 47,214 B |

R1 changes only 261 activated-core bytes. The broad validator and exact
48,000-byte internal cap are identical. Benchmark governance, graders, repair
rounds, hashes, and promotion rules remain outside both distributed packages.

## Execution

Each arm receives one fresh initial session and at most two fresh repair
sessions. Every phase has the same `gpt-5.6-sol` medium model, 900-second limit,
tool surface, isolation profile, brief, contract, and bounded external feedback.
There is no token-based eligibility cap; exact usage remains required evidence.
An arm stops early when it has no critical deterministic failure and reaches
63/70.

The known Grok brief runs first as an unranked development diagnostic. It cannot
change the already-frozen held-out task or grader. The first held-out task asks
for a metadata-only safe TAR/ZIP inspector and includes an independent hidden
fixture matrix plus blind semantic judge.

The reference archive fixture must score 70/70 before any authoring output is
allowed. Both treatment isolation preflights passed without starting a model
session.

## Claim boundary

This first held-out task is directional. It can show whether the bounded loop
helped on this task under equal budgets, but it cannot establish general Creator
superiority, production promotion, or a default Creator. Those claims require
at least two preregistered held-out skill families and repeatable evidence.

No real Grok call occurs, automatic Grok review stays disabled, and no wiki
capture is created.

## Commands

Run the structural and grader regression first:

```bash
bash tests/toolboxmd-creator-refinement-preregistration.test.sh
```

Then invoke `harness/run_bounded_refinement.py` once per task and arm from an
exact clean preregistration commit. Final safe-archive candidates are graded
semantically with `harness/run_archive_judge.py`. Credentials are supplied only
as the existing Codex auth-file path to the isolated runtime and are never
copied into repository results.
