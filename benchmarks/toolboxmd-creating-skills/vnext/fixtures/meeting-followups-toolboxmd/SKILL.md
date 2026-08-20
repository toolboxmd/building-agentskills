---
name: meeting-followups
description: Turn explicitly tagged meeting notes into a team follow-up, action tracker update, and QA record. Use when a user asks for a follow-up, action list, decision log, or tracker update from notes marked with [DECISION], [ACTION], [QUESTION], [IDEA], or [CHATTER]. Do not use for general meeting advice, agendas, facilitation, productivity coaching, or summaries of untagged notes.
---

# Meeting follow-ups

Create the three contract-compliant deliverables without changing the supplied notes or tracker.

## Inputs

Require:

- meeting notes whose relevant lines have a source marker and an explicit classification tag;
- the ISO meeting date;
- the existing `actions.csv` tracker.

Ask for any missing input. Never infer the meeting date. If a tagged action omits an owner or due date, continue with `TBD` as defined by the contract.

## Default path

1. Read [references/follow-up-contract.md](references/follow-up-contract.md) before producing files.
2. Parse tagged lines in source order. Classify only by their explicit tag; do not promote discussion, ideas, questions, or chatter into decisions or actions.
3. Resolve known owners using the contract. Preserve decision and question wording; make action wording imperative only when needed.
4. Create `output/follow-up.md`, copy the existing tracker to `output/actions.csv` and append explicit actions, then create `output/qa.json`. Do not modify either source input.
5. Validate all three files from the skill directory:

   ```bash
   python3 scripts/validate_outputs.py --notes <notes-path> --meeting-date <YYYY-MM-DD> --tracker <existing-actions.csv> --output-dir <output-dir>
   ```

6. Fix every reported error and rerun until the command exits `0`. Report the three output paths and any action fields left as `TBD`.

The validator is read-only. Exit `1` means the deliverables violate the contract; exit `2` means an input, path, or usage error prevented validation.

## Boundaries

- For untagged notes, ask the user to classify the relevant lines; do not guess private classifications.
- For requests about running better meetings, taking notes, writing agendas, or choosing collaboration practices, answer normally without this procedure.
- Write only the three deliverables under the requested `output/` directory. Preserve existing tracker rows byte-for-byte in meaning and row order.
