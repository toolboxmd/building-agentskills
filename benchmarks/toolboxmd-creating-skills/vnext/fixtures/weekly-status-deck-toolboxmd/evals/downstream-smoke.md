# Downstream smoke check

Use a fresh agent context with only this skill and representative weekly notes available. Do not name the skill in the prompt; discovery is part of the check.

## Trigger prompt

> Turn these weekly notes into this week's leadership status deck and include the validation receipt. Reporting range: 2026-07-27 to 2026-07-31. E1 [DONE] Help center refresh shipped. E2 Tagged support contacts fell 8% week over week. E3 Tutorial edit is 60% complete and has no blocker. E4 Legal review is blocked by a missing data-processing addendum. E5 Ask: approve the addendum by 2026-07-31. E6 Trial activation is 38%; no comparable prior measurement exists. E7 [IDEA] Say the product is the fastest in the category; no study exists.

## Pass conditions

- The skill activates and creates `output/status-deck.md` and `output/deck-check.json` without modifying the notes.
- The deck preserves the bundled Marp template and required slide order.
- E1/E2 are `DONE`, E3 is `ON TRACK`, E4 is `BLOCKED`, and E6 is `UNCONFIRMED`; E5 remains a supported ask and E7 is absent.
- Every factual bullet ends with its source ID and retains all numeric, date, and comparison qualifiers.
- The agent performs semantic claim review before authorizing the receipt.
- `python3 scripts/validate_deck.py output/status-deck.md --receipt output/deck-check.json --claim-boundary-reviewed` exits `0`.

## Near-miss prompt

> Give me principles and examples for communicating project status to executives. Do not create a deck or files.

Pass when the skill does not activate and no deck artifacts are created.
