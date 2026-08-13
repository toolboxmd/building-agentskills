# Deliverable contract

Apply every rule in this reference.

## Classification

- Treat only a line explicitly marked `[DECISION]` as a decision.
- Treat only a line explicitly marked `[ACTION]` as an action.
- Treat `[IDEA]` as deferred; never create a tracker row for it.
- Treat `[QUESTION]` as an open question.
- Ignore `[CHATTER]` in every deliverable.

Keep entries and citations in source order. Every notes entry begins with a source marker such as `M03`; render its citation as `[M03]` in Markdown and as `M03` in CSV.

## Owner and missing-value rules

| Person | Tracker owner |
|---|---|
| Maya Chen | `@maya` |
| Leo Park | `@leo` |
| Nina Gomez | `@nina` |
| Oliver Smith | `@oliver` |

Do not invent an owner or due date. Use `TBD` when an action has no explicit owner or due date.

## Required files

Write all results beneath `output/` relative to the task workspace. Do not modify source files.

### `follow-up.md`

Use exactly these headings in this order, even when a section has no bullets:

```markdown
# Meeting follow-up
## Decisions
## Action items
## Open questions
## Deferred ideas
```

End every bullet with its source citation. Keep decision and question wording faithful. Normalize action wording only enough to make it imperative. Use this action format exactly:

```text
- @owner | due YYYY-MM-DD or TBD | action text [source]
```

Use ordinary `- text [source]` bullets for decisions, questions, and ideas.

### `actions.csv`

Copy the existing tracker and append explicit new actions in source order. Keep exactly this header:

```text
action_id,owner,due_date,status,action,source
```

Create new IDs as `M-YYMMDD-NN`, using the meeting date and a two-digit sequence beginning at `01` for that meeting. Give every new row status `open`. Put the unbracketed source marker in `source`. Quote CSV fields according to standard CSV rules when their content requires it.

### `qa.json`

Write one JSON object with exactly these keys in this order:

```json
{
  "schema_version": 1,
  "meeting_date": "YYYY-MM-DD",
  "decision_count": 0,
  "action_count": 0,
  "open_question_count": 0,
  "deferred_idea_count": 0,
  "tracker_rows_added": 0,
  "missing_due_dates": [],
  "checks": [
    "source-citations",
    "tracker-schema",
    "no-idea-promotion"
  ]
}
```

Replace counts with the explicit source counts. List the IDs of actions whose due date is `TBD` in source order. `tracker_rows_added` must equal the number of appended action rows.

## Worked example

For meeting date `2026-07-20`:

```text
E01 [DECISION] Keep the help center public.
E02 [ACTION] Oliver Smith | 2026-07-22 | Publish the revised FAQ.
E03 [IDEA] Maybe record a welcome video.
E04 [QUESTION] Who will translate the FAQ?
```

Classify one decision cited `[E01]`, one action owned by `@oliver` and due `2026-07-22` cited `[E02]`, one open question cited `[E04]`, and one deferred idea cited `[E03]`. Append exactly one tracker row for `E02`; never append `E03`.

## Final QA

- Match every section's citations to markers of its own type.
- Match source counts and tracker rows added.
- Preserve the exact tracker header and all existing rows.
- Ensure new IDs follow the meeting-date sequence and all IDs are unique.
- Ensure no idea marker appears in an appended tracker row.
