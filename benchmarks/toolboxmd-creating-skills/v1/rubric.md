# Blind pairwise rubric

Judge the frozen A and B packages and their downstream results. Do not infer creator identity. Select `A`, `B`, or `tie` for each case and report confidence as `high`, `medium`, or `low`.

## Critical gate

A treatment has a critical failure when any of these is true:

- the generated package is invalid or cannot be used from its documented entry point;
- it writes outside the assigned output directory or mutates a protected input;
- a required deterministic script is absent, unsafe by default, or fails the case contract;
- its downstream result contradicts supplied source material, invents a required fact, or promotes unsupported evidence;
- it claims that advisory skill prose provides a hard enforcement mechanism;
- the run used another model, agent, creator treatment, hidden grader material, prior output, user memory, or network access;
- the reviewed artifact was manually repaired or semantically redacted.

A critical failure cannot be outweighed by stylistic strengths.

## Scored dimensions

Score each dimension from 0 to 4 for both A and B.

### 1. Primitive and invocation contract

- `0`: wrong primitive or unusable invocation contract.
- `2`: workable but boundaries or trigger conditions are vague.
- `4`: correct primitive, clear invocation owner, precise triggers and near-miss boundaries.

### 2. Source fidelity and scope

- `0`: contradicts, invents, or ignores essential source material.
- `2`: mostly faithful with meaningful omissions or weak provenance.
- `4`: grounded, complete for the task, explicit about missing facts and claim limits.

### 3. Workflow and executable mechanism

- `0`: workflow cannot produce the required result.
- `2`: usable happy path with weak defaults, verification, or error handling.
- `4`: concise default path, correct deterministic mechanisms, verification, and actionable failures.

### 4. Progressive disclosure and package design

- `0`: incoherent, bloated, or broken package.
- `2`: understandable but poorly partitioned or needlessly large.
- `4`: small coherent core, conditional references, justified scripts, no extraneous files.

### 5. Downstream utility

- `0`: fresh agent fails the held-out task.
- `2`: partially correct result requiring substantial repair.
- `4`: accurate, complete, inspectable result with the required artifacts and no repair.

## Verdict rule

A clear win requires an observable downstream advantage, no critical failure, at least a two-point total advantage, and confidence of at least `medium`. Prefer `tie` when differences are cosmetic, totals differ by less than two points, or evidence is insufficient.

For every case return:

- verdict and confidence;
- A and B scores for all five dimensions;
- critical failures, if any;
- at least two concrete path-backed observations;
- a short explanation centered on downstream usefulness.
