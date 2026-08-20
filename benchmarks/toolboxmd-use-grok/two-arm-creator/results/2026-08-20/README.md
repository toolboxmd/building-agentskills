# Two-arm Creator semantic rerun result

## Verdict

`INCONCLUSIVE`

Both authoring runs and both blind judge runs were isolation-eligible. Token
usage was recorded without acting as an eligibility gate, and semantic grading
completed for both candidates. Neither generated artifact is recommendable
because each has critical deterministic contract failures.

The preregistration was committed and pushed as `d17ff85` before either fresh
authoring run started. The two treatments, prompts, inputs, rubric, answer key,
schema, and harness remained frozen throughout execution.

## Scores and cost

| Arm | Treatment | Authoring input | Output | Duration | Package | Deterministic | Semantic | Total |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| C | final Creator vNext | 680,310 | 19,607 | 433.083 s | 18,101 B | 35/70 | 29/30 | 64/100 |
| D | frozen built-in Creator | 949,164 | 15,783 | 376.502 s | 16,269 B | 20/70 | 27/30 | 47/100 |

Arm C has the higher descriptive total by 17 points, used fewer input tokens,
and earned two more semantic points. This is not a known-task recommendation:
both artifacts are excluded by critical deterministic failures, and one sample
per treatment is directional evidence rather than a variance estimate.

The previous ineligible four-arm run produced 43/70 for both C and D. The fresh
35/70 and 20/70 values demonstrate substantial one-run variance and make a
general Creator ranking especially unsafe.

## Deterministic boundary

Arm C failed:

- direct, envelope, and streaming success handling;
- the exact safe argv, prompt-file, and environment contract;
- concrete failure classification;
- credential-shaped input rejection before invocation;
- the non-critical numeric-boundary gate.

Arm D failed every item above and also:

- inspect allow-list fail-closed behavior;
- complete timeout process-tree termination;
- automatic-mode disabled and fail-closed behavior.

The grader executed each adapter against the same frozen fake Grok scenarios.
The failures therefore outweigh semantic plausibility when deciding whether a
generated package is safe to use.

## Semantic boundary

Both anonymous judges classified all 12 activation and near-miss fixtures
correctly and awarded full procedure points:

| Arm | Activation | Procedure | Privacy/reliability | Semantic total |
|---|---:|---:|---:|---:|
| C | 10/10 | 10/10 | 9/10 | 29/30 |
| D | 10/10 | 10/10 | 7/10 | 27/30 |

The semantic judge inspected the candidate and frozen fixtures; it did not
execute the adapter. Runtime claims therefore come only from the deterministic
grader. C lost one privacy point because direct or enveloped output could be
accepted without a stop reason and usage was not required before acceptance. D
also had weaker HOME isolation and incomplete native-tool denial and detection.

## Isolation and claim boundary

- both control and model preflights passed;
- both live loopback network controls succeeded and sandboxed access was denied;
- copied treatment hashes matched the preregistered sources;
- every authoring and judge process exited zero within its wall-clock limit;
- token usage was present for all four model runs;
- no real Grok call occurred;
- automatic Grok review remains disabled;
- no treatment is admitted to held-out promotion from this known brief.

## Acceptance-refinement implication

The result supports a process hypothesis, not a promotion claim. Both one-pass
Creators generated semantically coherent packages while missing critical
executable boundaries. The historical acceptance-refined Grok closed the same
class of gap through evidence-driven test and repair work and reached 70/70
deterministically.

A plausible next Creator treatment is therefore a bounded agentic refinement
loop that preserves an immutable raw candidate, derives acceptance cases from
the brief, runs deterministic validation and representative rehearsal,
classifies failures, applies the smallest evidence-linked repair, and freezes
each delta. That mechanism must use a fixed round, time, and tool budget.

Grok cannot validate the generality of that mechanism because its failures are
now development evidence. A promotion claim requires at least one held-out
skill brief whose acceptance failures were not used to design the loop, plus a
fair baseline under the same total execution budget.
