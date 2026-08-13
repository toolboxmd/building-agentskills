# Deterministic comparison rubric

## Integrity gate

A run is ineligible when any of these occurs:

- wrong model, CLI version, effort, or runner configuration;
- unexpected skill, plugin, app, memory, network, or nested agent use;
- read or write outside the staged run root;
- mutation of a protected input;
- generated package repair after the authoring session;
- missing or malformed raw evidence;
- positive result without trace-backed target `SKILL.md` load.

Ineligible evidence remains retained but cannot win a case.

## No-skill qualification

A case qualifies only when the eligible no-skill arm fails at least one declared critical assertion despite having byte-identical ordinary knowledge and all required tools. Passing all critical assertions invalidates the case before treatment authoring.

## Utility order

Compare eligible treatments in this order:

1. number of critical assertions passed;
2. number of all deterministic assertions passed;
3. required artifact completeness;
4. positive trigger evidence;
5. uncached downstream runtime tokens when utility is equal.

The first strict difference determines the case winner. Equal utility with higher runtime cost loses. Exact equality is a tie.

## Trigger precision

One aggregate near-miss session per treatment exposes every target skill from the final evaluated set. Loading any target `SKILL.md` is a false positive.

Near-miss precision is used only after downstream utility. It breaks an otherwise equal result but cannot offset a critical failure.

## Overall verdict

- `toolboxmd`: two case wins and no critical regression.
- `builtin`: mirror rule.
- `mixed`: neither treatment reaches two wins, or a win is offset by a critical regression.
- `inconclusive`: integrity, qualification, or evidence gaps prevent comparison.

The reserve case is evaluated only under the stopping rule in `run-config.json`.

## Required explanation

The human report must include:

- a one-to-one table for each generated package and downstream result;
- exact failed and passed critical checks;
- target load and unexpected load evidence;
- package size and authoring cost;
- downstream uncached tokens and duration;
- observed creator strengths and weaknesses;
- changes recommended for the creator, repository doctrine, validator, or harness;
- alternative explanations that remain plausible after one run.
