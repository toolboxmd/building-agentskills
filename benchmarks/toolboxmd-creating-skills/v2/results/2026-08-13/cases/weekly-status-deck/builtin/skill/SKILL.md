---
name: weekly-status-deck
description: Create or update an Aster leadership weekly status deck from weekly notes, check-ins, changelogs, or an existing status deck. Use when the user asks to turn a reporting period's notes into a leadership or executive status presentation, or to refresh that five-slide Marp artifact; produce the exact Aster deck plus its JSON validation receipt. Do not use for general advice, coaching, or critique about status communication, for prose status updates or emails, or for presentation design when the user is not asking for a deck artifact from weekly notes.
---

# Weekly status deck

Turn supplied weekly evidence into the fixed Aster leadership deck. Keep claims narrower than or equal to the evidence.

## Build the deck

1. Locate the source notes and reporting range. If the range is absent and cannot be derived without guessing, ask for it.
2. Read [references/deck-conventions.md](references/deck-conventions.md) before drafting. Use its classification, evidence, empty-section, and receipt rules.
3. Work only in the user's requested destination; otherwise use `output/`. Do not modify source notes.
4. Copy [assets/status-deck-template.md](assets/status-deck-template.md) to `<destination>/status-deck.md`. Replace every placeholder while retaining the frontmatter, five headings, and slide order byte-for-byte.
5. Create an evidence ledger in working context. Preserve existing identifiers; if notes lack them, assign `W1`, `W2`, ... by source order solely for citations. Do not create a separate ledger file.
6. Exclude unsupported ideas. Preserve every number, qualifier, comparison, dependency, owner, and date exactly as supported. Never supply a missing result, owner, date, budget, comparison, or confidence level.
7. Put one concise claim or ask on each single-line bullet and end every factual bullet with its bracketed evidence identifier. Use only the contract status labels.
8. Review every deck claim against the ledger. Confirm that each claim is directly supported, qualifiers remain intact, ideas are absent, and unsupported claims equal zero.
9. Generate and validate `<destination>/deck-check.json` with the bundled checker:

   ```bash
   python3 <skill-dir>/scripts/validate_deck.py \
     <destination>/status-deck.md \
     --notes <notes-file> \
     --claims-reviewed \
     --write-receipt <destination>/deck-check.json
   ```

   Omit `--notes` only when notes are not available as a local file. Never pass `--claims-reviewed` before completing step 8. Fix every reported error and rerun. The checker is structural support, not a substitute for semantic claim review.

Return links to the deck and receipt plus a terse validation result.

