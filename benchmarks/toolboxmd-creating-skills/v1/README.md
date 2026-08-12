# ToolboxMD creating-skills benchmark v1

## Decision

This benchmark asks whether the frozen `toolboxmd-creating-skills` candidate produces more useful skills than the built-in Codex `skill-creator` for three declared archetypes under one frozen Codex configuration.

It is a one-run directional screen. It does not estimate variance, test implicit triggering, rank models, or establish cross-provider superiority.

## Treatments

- `builtin`: the inspectable Codex 0.147.0 baseline snapshot under `baselines/`.
- `toolboxmd`: the tracked candidate tree frozen before exact case instances exist.

Both arms receive the same authoring prompt, fixtures, model, effort, sandbox, attribution guard, and time policy. Every run starts in its own root with exactly one creator package available by explicit path.

## Cases

The public contracts cover three archetypes:

1. A reference-heavy incident-triage skill.
2. A deterministic CSV transformation skill.
3. An evidence-gated release communication skill.

The contracts and scoring rules are visible before candidate freeze. Exact prompts and synthetic fixtures are generated only after freeze by an independent agent that cannot inspect either creator. This bounds the result to the three declared archetypes while keeping exact instances held out.

## Run sequence

1. Validate and hash both creator treatments.
2. Generate and hash exact sealed cases.
3. Prove no implicit skills are visible and outbound network access fails.
4. Run six authoring sessions, one per case and treatment.
5. Validate and hash all generated skill packages without repair.
6. Run six fresh downstream-use sessions.
7. Apply deterministic assertions.
8. Copy frozen artifacts byte for byte beneath neutral A/B parent directories.
9. Run one blind semantic review and reveal the mapping afterward.

The default budget is 13 model sessions. At most one ambiguous case may be replayed. Contaminated attempts remain evidence and do not enter the score.

## Pass rule

The candidate passes when:

- its own package validates;
- all three candidate-authored packages pass critical mechanical contracts;
- it wins at least two of three blind downstream comparisons;
- the remaining case contains no critical candidate regression;
- no win depends on contamination, identity leakage, or manual repair.

## Evidence boundary

Mechanical validity, authoring quality, downstream utility, and cost are recorded separately. A passing result supports a narrow recommendation for this configuration and these archetypes. A failed or inconclusive result remains inspectable but does not change public doctrine or the current loader recommendation.
