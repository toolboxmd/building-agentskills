---
name: meeting-followups
description: Turn concrete meeting notes or a transcript into a structured team follow-up, formal decision/action/question/idea lists, and an appended CSV action tracker with QA evidence. Use when the user provides meeting notes and asks to draft or write the follow-up, extract formal meeting outcomes, create an action list or decision log, or update the action tracker. Do not use for general meeting advice, facilitation, agendas, note-taking templates, or productivity guidance when no supplied notes are being transformed into deliverables.
---

# Meeting follow-ups

Transform supplied meeting notes into the required follow-up, tracker, and QA artifacts without promoting informal text into formal outcomes.

## Workflow

1. Identify the meeting-notes source, meeting date, and existing action tracker. Ask only for a missing input that cannot be recovered from the supplied material.
2. Read [references/deliverable-contract.md](references/deliverable-contract.md) completely before classifying or writing anything.
3. Parse source entries in order. Classify solely by their explicit markers; never infer decisions or actions from ordinary discussion.
4. Create `output/follow-up.md`, `output/actions.csv`, and `output/qa.json` relative to the task workspace. Do not modify the notes or existing tracker.
5. Preserve the existing tracker rows exactly and append one row per explicit action in source order. Resolve only known owner mappings; use `TBD` instead of inventing owners or dates.
6. Check every source marker, count, identifier, heading, column, and tracker append against the notes.
7. Run the deterministic validator and fix every error before finishing:

   ```bash
   python3 <skill-dir>/scripts/validate_outputs.py \
     --notes <meeting-notes> \
     --tracker-before <existing-actions.csv> \
     --meeting-date YYYY-MM-DD \
     --output-dir output
   ```

   If no prior tracker exists, omit `--tracker-before`; still create `actions.csv` with the exact header.

8. Report the three created files concisely. Do not expose ignored chatter or add inferred outcomes to the deliverables.
