---
title: Creator vNext versus built-in semantic rerun
status: APPROVED FOR EXECUTION
date: 2026-08-20
owner: lukemaj
scope: fresh two-treatment Grok authoring diagnostic with deterministic and semantic grading
execution_authorization: user approved arms C and D, no token-based disqualification, and semantic grading on 2026-08-20
parent_pull_request: https://github.com/toolboxmd/building-agentskills/pull/3
---

# Creator vNext versus built-in semantic rerun

## Outcome

Run a fresh, isolated comparison of final Creator vNext and the frozen built-in
Codex `skill-creator` on the known Grok brief. Record both deterministic contract
compliance and blind semantic utility. Token usage is a reported cost, not an
eligibility gate.

## Frozen decisions

- Arm C is the exact Creator vNext package merged through pull request 2.
- Arm D is the built-in Creator snapshot already frozen by the four-arm run.
- Each arm receives one fresh context, the same prompt, model, reasoning effort,
  filesystem boundary, network policy, tool surface, and 900-second authoring
  wall-clock limit.
- Input and output tokens have no post-run eligibility cap. Their exact values
  must still be present in retained evidence.
- Every isolation-eligible authored candidate receives deterministic grading and
  a fresh blind semantic judge run, even when deterministic grading finds a
  critical failure. A critical failure still makes that artifact
  non-recommendable.
- Semantic grading does not call the real Grok CLI. Automatic Grok review stays
  disabled.
- The result is a known-brief diagnostic. One run per arm is directional
  evidence and cannot establish general Creator superiority.

## Execution sequence

1. Freeze and hash both treatments, inputs, prompts, rubric, answer key, schema,
   and the copied two-arm harness.
2. Commit and push the preregistration before any new authoring output exists.
3. Run C and D concurrently from fresh opaque sandboxes.
4. Retain command events, prompt capture, environment keys, network denial,
   output snapshots, usage, timing, and treatment hashes.
5. Grade both candidates deterministically.
6. Run one anonymous semantic judge context per candidate and retain its evidence.
7. Aggregate deterministic and semantic scores without changing weights or
   decision rules after seeing output.
8. Publish an inconclusive result when isolation, critical failures, the score
   floor, or the required lead does not support a known-task winner.

## Acceptance-refinement hypothesis

The historical raw Grok package and the 70/70 acceptance-refined package suggest
that the useful general mechanism may be a bounded generate-test-repair loop,
not a larger one-pass instruction file. That hypothesis is deliberately outside
arms C and D in this rerun because the Grok failures are already visible.

A later Creator treatment may generalize this process as:

1. generate an immutable raw candidate;
2. derive acceptance cases from the brief and observed runtime contract;
3. run deterministic validation and representative rehearsal;
4. classify failures by contract boundary;
5. apply the smallest evidence-linked repair;
6. repeat for a fixed number of rounds or until the gate is green;
7. freeze raw and refined packages with full lineage.

To claim a Creator improvement, that mechanism needs a fixed repair budget and
at least one held-out skill brief whose failures were not used to design the
loop. Grok remains development evidence, not held-out proof.

## Exclusions

- Do not alter either treatment after preregistration.
- Do not reuse the 2026-08-19 C or D outputs as ranked samples.
- Do not add Grok-specific fixes to Creator vNext in this experiment.
- Do not run a real Grok consultation or enable automatic review.
- Do not create or ingest wiki captures.
- Do not merge pull request 3 or a follow-up pull request without separate user
  approval.
