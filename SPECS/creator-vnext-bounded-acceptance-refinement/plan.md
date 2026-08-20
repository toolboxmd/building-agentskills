---
title: Creator vNext bounded acceptance refinement
status: APPROVED FOR EXECUTION
date: 2026-08-20
owner: lukemaj
scope: thin Creator instruction, equal-budget refinement evaluation, and held-out diagnostic
execution_authorization: user approved generalizing the acceptance-refined Grok process and instructed execution on 2026-08-20
parent_product_commit: 20fc268615079ade496e31cc5e55f51bcc5ad3b0
related:
  - https://github.com/toolboxmd/building-agentskills/pull/2
  - https://github.com/toolboxmd/building-agentskills/pull/3
---

# Creator vNext bounded acceptance refinement

## Outcome

Test whether a small Creator-facing generate-test-repair instruction improves
newly authored skills when compared with the merged Creator vNext under equal
model, tool, attempt, and wall-clock budgets.

This is a new treatment. It does not rewrite or rank the completed four-arm or
two-arm Grok diagnostics.

## Evidence and claim boundary

- Pull request 2 merged standalone Creator vNext at `20fc268` with a
  48,000-byte internal package cap.
- The ineligible four-arm run cannot rank its outputs because its frozen token
  cap was exceeded.
- The fresh C/D known-Grok rerun completed semantic grading without a token
  disqualification. C scored 64/100 and D 47/100, but both packages had
  critical executable-contract failures and neither was recommendable.
- The historical acceptance-refined Grok package scored 70/70 on the frozen
  deterministic contract. It is development evidence, not held-out proof.
- Current primary guidance supports minimal evaluation-driven instructions,
  representative trigger and non-trigger cases, isolated testing, and
  iteration from observed failures rather than imagined requirements:
  - https://agentskills.io/specification
  - https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
  - https://platform.claude.com/docs/en/agents-and-tools/agent-skills/enterprise
- OpenAI's evaluation guidance requires reporting the tested system, harness,
  retries, tokens, time, elicitation method, and validity checks:
  - https://openai.com/index/trustworthy-third-party-evaluations-foundations/

No known-brief result may establish general Creator superiority, production
promotion, or a default Creator.

## Grok consultation reconciliation

The user explicitly authorized one bounded plan consultation. Grok Build CLI
1.0.5 returned `PROCEED WITH CHANGES` in explicit mode, run
`8668b9c0-d43d-4da6-ab56-083d2e4f435b`. The adapter observed an `end_turn`, no
tool calls, no web search, and no redactions. The redacted review SHA-256 was
`9eaef25c7606867e0bc0d373b1bd45fc0587b0efa85b6d899a2418f631ee83da`.
The bounded retained summary is `grok-consultation-summary.json` beside this
plan; transient profile and raw process files are not repository artifacts.

Accepted advice:

- keep only a thin repair instruction in the Creator;
- keep hashes, freeze rules, failure taxonomy, fixed rounds, and benchmark
  governance in the external harness;
- compare against the merged Creator with equal attempts and compute;
- freeze the loop and held-out contract before a new Grok development run;
- retain the 48,000-byte cap and broad validator unchanged.

Rejected advice:

- a harness-only change would not test the user's product hypothesis, so the
  Creator receives a small instruction delta;
- token usage remains reported cost rather than an eligibility cap, matching
  the user's explicit C/D decision.

## Product delta

Change only Creator step 6:

1. preserve an immutable raw candidate outside the distributed package;
2. derive acceptance cases from the evidence brief and runtime contract;
3. validate, test helpers, and rehearse a representative task;
4. classify failures by the broken contract;
5. apply the smallest supported repair and rerun;
6. stop on a green gate or the externally agreed repair budget;
7. report raw/refined lineage, remaining failures, and exact product costs.

Do not add Grok-specific checks, a benchmark framework, a grader, eval files,
or another validator surface to the three-file Creator package. Keep the
48,000-byte cap and all other product budgets unchanged.

## Evaluation treatments

| Arm | Frozen Creator | Repair behavior |
|---|---|---|
| R0 | merged Creator vNext at `20fc268` | generic equal-budget retry baseline |
| R1 | exact candidate from this branch | structured acceptance refinement |

Both arms receive the same authoring model, reasoning effort, brief, primary
sources, tool surface, filesystem and network boundary, initial wall-clock
allowance, and up to two repair attempts. Each repair receives the same
externally produced failing assertion IDs and evidence. R0 gets a neutral
request to improve the artifact; R1 follows its frozen Creator procedure.

There is no input- or output-token eligibility cap. Record exact usage. Each
initial or repair session has a 900-second wall-clock limit, so each arm has at
most three model sessions and 2,700 seconds. Stop early when the external gate
has no critical failure and meets its score floor.

## Development diagnostic

After this plan, both treatments, prompts, harness, budgets, and held-out
contract are frozen, run R0 and R1 on the known Grok brief. This run may reveal
implementation or harness defects. It is unranked for promotion and cannot
change the held-out grader, stop rule, or claim boundary.

## First held-out brief

Freeze a new `safe-archive-inspector` brief before the known-Grok run. The
requested skill must inspect untrusted TAR and ZIP archives without extracting
them and return a stable machine-readable report. It must use Python standard
library APIs, remain cwd-independent, avoid network access, enforce explicit
entry-count and declared-uncompressed-size budgets, and fail closed for archive
members that violate the stated path or file-type policy.

The brief may cite current Python `tarfile` and `zipfile` documentation. The
authoring agents do not receive the external grader or its hidden fixtures.
The grader independently covers ordinary archives, corrupt input, absolute and
parent paths, link and special-file members, duplicate or ambiguous names,
resource ceilings, output stability, triggering, and difficult near misses.

Python's documentation is the source boundary:

- https://docs.python.org/3/library/tarfile.html
- https://docs.python.org/3/library/zipfile.html

The first held-out brief is directional only. A claim of general improvement
requires at least two preregistered held-out briefs from different skill
families, no critical executable-contract failure, semantic non-regression,
and a repeatable lead under equal budgets.

## Frozen decision rules

- A critical safety or runtime-contract failure makes that artifact
  non-recommendable even when semantic output is strong.
- A green artifact must have no critical failure and at least 90% of available
  deterministic points.
- Report raw-to-refined deltas for both treatments; do not score lineage shape
  as product utility.
- Extra attempts are not awarded. If one arm stops early, report saved cost.
- Do not retune the loop, hidden fixtures, weights, or promotion rule after any
  authoring output exists.
- Publish `INCONCLUSIVE` when isolation, variance, score floors, or critical
  failures do not support the bounded claim.

## Execution order

1. Freeze and verify the thin Creator candidate under the unchanged 48 KB cap.
2. Commit and push the product candidate before generating benchmark outputs.
3. Freeze the two treatments, prompts, harness, Grok development grader,
   held-out archive brief, hidden grader, fixtures, and all hashes.
4. Commit and push the preregistration before any new authoring session.
5. Run the unranked known-Grok development diagnostic with R0 and R1.
6. Do not change the held-out boundary based on the Grok outputs.
7. Run the first held-out comparison and blind semantic grading.
8. Publish raw, per-round, grader, timing, usage, and isolation evidence.

## Verification and delivery

For the product branch run at minimum:

```text
bash tests/toolboxmd-creating-skills-vnext.test.sh
npm test
npm run build:docs
git diff --check
```

Also reproduce package bytes and aggregate hashes from an external cwd. Keep
tests, commits, pushes, reviews, PR state, merges, blockers, scope drift, and
remaining user decisions separate in every handoff.

Do not merge the product candidate or benchmark evidence without a new explicit
user decision. Do not create or ingest wiki captures.
