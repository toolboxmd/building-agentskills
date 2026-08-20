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

## Observed result

The known Grok task remained unranked. R0 moved `45 -> 47 -> 42/70`; R1 moved
`35 -> 45 -> 45/70`. Both final artifacts retained three critical failures and
were not recommendable. R1 recovered more strongly after the first feedback
round and finished three points higher, but that does not establish a Creator
advantage.

Both held-out archive arms stopped after their initial session with a reported
70/70 deterministic score. The blind semantic judge reported 30/30 for R0 and
28/30 for R1. A required post-run contract audit then proved that both graded
candidates accept a ZIP member with an embedded NUL because Python exposes the
truncated value through `ZipInfo.filename` while preserving the original value
in `ZipInfo.orig_filename`. The frozen contract requires NUL rejection, but the
deterministic grader omitted that case. The semantic judge also penalized only
R1 for this shared implementation defect.

The held-out comparison is therefore **INCONCLUSIVE**, not 100 versus 98. The
raw scores and evidence remain retained, but neither a treatment lead nor a
promotion claim is allowed. The grader gap must be fixed and frozen before a
new, genuinely held-out skill family is run.

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
