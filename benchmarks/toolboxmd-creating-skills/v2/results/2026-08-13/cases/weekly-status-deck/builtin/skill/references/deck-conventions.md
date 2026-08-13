# Aster deck conventions

## Classification

- `DONE`: verified completed work or a measured outcome already observed.
- `ON TRACK`: in-progress work with no stated blocker.
- `BLOCKED`: work that cannot proceed because of a stated dependency.
- `UNCONFIRMED`: an observation without a comparable baseline or sufficient evidence.

Use these labels exactly; do not replace them with synonyms. Status-bearing bullets on Outcomes, Work in progress, and Risks begin `- **LABEL** — `. Decisions and asks use an unlabelled bullet because `ASK` is not a status. Do not infer that an item is blocked merely because it has risk, or that a current measurement improved when no comparable baseline exists.

## Evidence and claim boundaries

- End every factual bullet with one source marker, for example `[W3]`. Preserve existing identifiers. When source notes have no identifiers, assign `W1`, `W2`, ... by note-unit order solely to make citations stable.
- Keep one claim or ask per single-line bullet. A marker supports only what its source states.
- Preserve numeric qualifiers and time comparisons: `8% week over week` must not become `8%`, `improved`, or a broader trend.
- Mark a current measurement with no comparable baseline `UNCONFIRMED` and describe only the current value.
- Exclude an `[IDEA]` that lacks evidence. It is not a factual outcome.
- Never invent a result, owner, date, budget, comparison, or confidence level.
- Use italic non-bullet text `_No evidence-backed items in the supplied notes._` for an empty section. Do not fabricate filler.

## Placement

Keep the exact five-slide order in the template:

1. `Aster Weekly Status`: show `Reporting range: YYYY-MM-DD to YYYY-MM-DD` as non-bullet text.
2. `Outcomes`: completed work, observed outcomes, and unconfirmed measurements.
3. `Work in progress`: active work that is on track.
4. `Risks`: blocked work and its stated dependency.
5. `Decisions and asks`: supported decisions or asks, including dates only when supplied.

## Worked example

For notes covering `2026-07-27 to 2026-07-31`:

```text
E1 [DONE] Help center refresh shipped.
E2 Tagged support contacts fell 8% week over week.
E3 Tutorial edit is 60% complete and has no blocker.
E4 Legal review is blocked by a missing data-processing addendum.
E5 Ask: approve the addendum by 2026-07-31.
E6 Trial activation is 38%; no comparable prior measurement exists.
E7 [IDEA] Say the product is the fastest in the category; no study exists.
```

Classify E1 and E2 as `DONE`, E3 as `ON TRACK`, E4 as `BLOCKED`, and E6 as `UNCONFIRMED`; include the E5 ask and exclude E7. Preserve `8% week over week`, `60%`, `38%`, the named dependency, and the supplied date.

## Validation receipt

Write `deck-check.json` with only these keys, in this order:

```json
{
  "schema_version": 1,
  "slide_count": 5,
  "required_sections": [
    "Aster Weekly Status",
    "Outcomes",
    "Work in progress",
    "Risks",
    "Decisions and asks"
  ],
  "evidence_ids": ["E1", "E2", "E3", "E4", "E5", "E6"],
  "unsupported_claims": 0,
  "checks": ["frontmatter", "slide-order", "evidence", "claim-boundary"]
}
```

`evidence_ids` contains each identifier actually used in the deck once, sorted by numeric suffix (then prefix for ties). The bundled validator writes this exact receipt shape only after the semantic review is explicitly attested.

