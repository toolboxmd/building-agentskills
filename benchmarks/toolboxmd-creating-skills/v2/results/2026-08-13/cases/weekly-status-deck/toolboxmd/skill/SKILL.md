---
name: weekly-status-deck
description: Turn weekly notes into Aster's five-slide internal leadership status deck and validation receipt. Use when asked to create or update a weekly leadership/status deck from notes, updates, metrics, risks, decisions, or asks. Do not use for general advice, coaching, or critique about status communication when no deck artifact is requested.
---

# Weekly Status Deck

Create an evidence-bounded Marp deck from the user's weekly notes. Work directly from those notes; do not invoke or depend on another presentation skill.

## Inputs and outputs

Require weekly notes and a reporting range. Accept source identifiers already present in the notes; if they are absent, assign stable identifiers to individual source items before drafting and use those identifiers consistently.

Write, relative to the user's requested work location:

- `output/status-deck.md`
- `output/deck-check.json`

Do not modify the source notes. If the user gives a different explicit output directory, place both files there together.

## Default path

1. Read all supplied weekly notes. Extract the reporting range, source IDs, completed outcomes, active work, blockers, measurements, decisions, and asks. Keep each claim traceable to a source item.
2. Read [references/deck-conventions.md](references/deck-conventions.md) before classifying claims or drafting. It contains the status meanings, claim boundaries, evidence rules, and worked mapping.
3. Copy [assets/status-deck-template.md](assets/status-deck-template.md) to the output deck path and replace its placeholders. Preserve its frontmatter, five-slide order, headings, footer, and separators exactly.
4. Put verified completed work and supported results under Outcomes; active work under Work in progress; blockers under Risks; and supported decisions or asks under Decisions and asks. Use only the prescribed status labels.
5. Review every bullet against the notes. Preserve numbers, qualifiers, dates, and comparison periods exactly. Remove unsupported ideas and any inferred result, owner, date, budget, comparison, or confidence.
6. Validate and write the receipt only after completing the semantic review:

   ```bash
   python3 scripts/validate_deck.py output/status-deck.md --receipt output/deck-check.json --claim-boundary-reviewed
   ```

7. Fix every reported error and rerun the command. Finish only when it exits `0`, then open the JSON receipt and confirm it has the expected six keys and reports zero unsupported claims.

## Hard boundaries

- Treat prose instructions as judgment guidance; the script enforces only observable structure and citation rules.
- Never present a current measurement without a comparable baseline as an improvement or trend.
- Never turn an unsupported `[IDEA]` into deck content.
- Never invent missing facts. If the reporting range is missing, ask for it; if other information is missing, omit the unsupported claim.
- Every factual bullet must end with its bracketed source identifier.

Run `python3 scripts/validate_deck.py --help` for alternate paths and check-only behavior.
