# Two-arm Creator semantic rerun for `toolboxmd-use-grok`

This directory compares two frozen Creator treatments on one known Grok brief:

| Arm | Treatment | Frozen source |
|---|---|---|
| C | final Creator vNext | merged pull request 2 package at `20fc268` |
| D | built-in Codex `skill-creator` | retained 0.147.0-era snapshot |

The earlier four-arm execution completed authoring for both treatments, but its
pre-registered 750,000 input-token rule made the whole comparison ineligible
before semantic judging. These are fresh authoring runs, not a reclassification
of the old outputs.

## Execution contract

- model `gpt-5.6-sol`, medium reasoning;
- one fresh isolated context per treatment;
- common authoring prompt and Grok brief;
- 900-second authoring wall-clock limit;
- no input- or output-token eligibility cap;
- exact token usage remains mandatory evidence;
- no real Grok call;
- deterministic grading for both generated packages;
- a fresh blind semantic judge for every isolation-eligible package, including
  packages with deterministic critical failures.

Semantic points describe activation, procedure adherence, and privacy behavior.
They do not override a critical deterministic contract failure. The maximum is
70 deterministic plus 30 semantic points.

## Claim boundary

This is a known-brief diagnostic because Grok evidence influenced Creator
vNext. A known-task recommendation requires isolation eligibility, no critical
failure, at least 85/100, and an 8-point lead. Otherwise the honest verdict is
inconclusive. One run per treatment is directional evidence, not a variance
estimate or a general Creator promotion.

The 70/70 acceptance-refined Grok reference is not a ranked treatment here. Its
generate-test-repair lineage motivates a separate future Creator hypothesis
that must be evaluated with a fixed repair budget and held-out skill brief.
