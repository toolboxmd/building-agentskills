# Team follow-up contract

Use this contract whenever a user asks to turn meeting notes into a follow-up, action list, decision log, or tracker update.

## Classification

- Only a line explicitly marked `[DECISION]` is a decision.
- Only a line explicitly marked `[ACTION]` is an action.
- A line marked `[IDEA]` is deferred and must never become a tracker row.
- A line marked `[QUESTION]` is an open question.
- Ignore `[CHATTER]` in the deliverables.

## Owner mapping

- Maya Chen: `@maya`
- Leo Park: `@leo`
- Nina Gomez: `@nina`
- Oliver Smith: `@oliver`

Do not invent an owner. Use `TBD` when an action has no owner. Do not invent a date. Use `TBD` when an action has no explicit due date.

## Required files

Write all results under `output/` and do not modify source files.

### `output/follow-up.md`

Use exactly these headings and this order:

1. `# Meeting follow-up`
2. `## Decisions`
3. `## Action items`
4. `## Open questions`
5. `## Deferred ideas`

Every bullet must end with the source marker from the meeting note, for example `[M03]`. Keep decision and question wording faithful. Normalize action wording only enough to make it imperative.

Action bullets use:

```text
- @owner | due YYYY-MM-DD or TBD | action text [source]
```

### `output/actions.csv`

Copy the existing tracker and append explicit new actions in source order. Keep exactly these columns:

```text
action_id,owner,due_date,status,action,source
```

New identifiers use `M-YYMMDD-NN`, where the date is the meeting date and `NN` starts at `01` for that meeting. New rows have status `open`. The `source` cell contains the marker without brackets.

### `output/qa.json`

Write one JSON object with exactly these keys and meanings:

- `schema_version`: integer `1`
- `meeting_date`: ISO meeting date
- `decision_count`: explicit decisions
- `action_count`: explicit actions
- `open_question_count`: explicit open questions
- `deferred_idea_count`: explicit ideas
- `tracker_rows_added`: number of appended action rows
- `missing_due_dates`: action identifiers whose due date is `TBD`, in source order
- `checks`: exactly `source-citations`, `tracker-schema`, and `no-idea-promotion` in that order

Before finishing, verify the source counts, tracker header, unique identifiers, and absence of idea rows.
