# Deck conventions

Read this file before classifying notes or drafting a deck.

## Status vocabulary

Use these labels verbatim; do not substitute synonyms:

- `DONE`: verified completed work.
- `ON TRACK`: in-progress work with no stated blocker.
- `BLOCKED`: work that cannot proceed because of a stated dependency.
- `UNCONFIRMED`: an observation without a comparable baseline or sufficient evidence.

These meanings control classification. A metric does not become `DONE` merely because it is numeric. A blocker requires an explicitly stated dependency; do not infer one from delay or uncertainty.

## Evidence and claim boundaries

- End every factual bullet with its bracketed source identifier, such as `[W3]`.
- Preserve numeric qualifiers and time comparisons, including units and phrases such as “week over week.”
- Mark a current measurement with no comparable baseline `UNCONFIRMED`; do not describe it as an improvement, decline, or trend.
- Exclude an `[IDEA]` that lacks evidence. It is not a factual outcome.
- Do not invent a result, owner, date, budget, comparison, confidence level, cause, or consequence.
- Keep supported asks and decisions, with their source identifiers, on the final slide. Do not manufacture an owner or due date for them.

Use one bullet per independently sourced claim. If a sentence combines claims with different sources, split it so each bullet has an unambiguous final citation. A bullet may state a status as `**DONE**`, `**ON TRACK**`, `**BLOCKED**`, or `**UNCONFIRMED**`; the words and citation still belong to the factual bullet.

## Worked mapping

Given notes for `2026-07-27 to 2026-07-31`:

```text
E1 [DONE] Help center refresh shipped.
E2 Tagged support contacts fell 8% week over week.
E3 Tutorial edit is 60% complete and has no blocker.
E4 Legal review is blocked by a missing data-processing addendum.
E5 Ask: approve the addendum by 2026-07-31.
E6 Trial activation is 38%; no comparable prior measurement exists.
E7 [IDEA] Say the product is the fastest in the category; no study exists.
```

Map the material as follows:

- Outcomes: `E1` and `E2` as `DONE`, retaining “8% week over week”; include the current `E6` measurement as `UNCONFIRMED` with its missing-baseline caveat.
- Work in progress: `E3` as `ON TRACK`, retaining “60% complete” and the lack of a blocker.
- Risks: `E4` as `BLOCKED`, naming the missing addendum dependency.
- Decisions and asks: the supported `E5` ask, retaining its date.
- Nowhere: `E7`, because it is an unsupported idea.

Every included bullet ends in its corresponding `[E#]` marker.

## Final semantic review

Before authorizing the receipt, compare the deck with the notes line by line:

1. Each factual bullet has support and ends with the matching source ID.
2. Each number, date, qualifier, and comparison matches its source.
3. Each status matches the definitions above.
4. No missing baseline has become a trend claim.
5. No unsupported idea or invented detail remains.

Only after this review may you pass `--claim-boundary-reviewed` to the validator. That flag records completion of human review; it does not make the script a semantic fact checker.
