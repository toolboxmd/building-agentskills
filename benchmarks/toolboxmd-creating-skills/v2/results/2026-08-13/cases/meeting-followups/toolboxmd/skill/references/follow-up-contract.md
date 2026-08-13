# Follow-up output contract

Apply every convention in this file whenever producing the follow-up package.

## Classification

- Only `[DECISION]` is a decision.
- Only `[ACTION]` is an action.
- `[IDEA]` is deferred and never becomes a tracker row.
- `[QUESTION]` is an open question.
- Omit `[CHATTER]` from all deliverables.

Every delivered bullet ends with its note's source marker in brackets, such as `[M03]`.

## Owners and missing fields

Map full names exactly:

| Name | Tracker owner |
|---|---|
| Maya Chen | `@maya` |
| Leo Park | `@leo` |
| Nina Gomez | `@nina` |
| Oliver Smith | `@oliver` |

Never invent an owner or date. Use `TBD` when an action has no owner or no explicit due date.

## `output/follow-up.md`

Use exactly these headings in this order, with no additional headings:

```markdown
# Meeting follow-up
## Decisions
## Action items
## Open questions
## Deferred ideas
```

List the corresponding tagged entries beneath each section in source order. Keep decision and question wording faithful. Normalize action wording only enough to make it imperative.

Every action bullet has exactly this shape:

```text
- @owner | due YYYY-MM-DD or TBD | action text [source]
```

Use `TBD` in the owner position when no owner is explicit. For a missing date, write `due TBD`.

## `output/actions.csv`

Copy the existing tracker, preserving all rows and their order, then append only explicit `[ACTION]` entries in source order. Keep exactly this header:

```csv
action_id,owner,due_date,status,action,source
```

For new rows:

- set `action_id` to `M-YYMMDD-NN`, using the meeting date and a two-digit sequence starting at `01` for that meeting;
- use the mapped owner or `TBD`;
- use the explicit ISO due date or `TBD`;
- set `status` to `open`;
- put the source marker in `source` without brackets.

Identifiers must be unique across the complete tracker.

## `output/qa.json`

Write one JSON object with exactly these keys in this order:

1. `schema_version`: integer `1`
2. `meeting_date`: ISO meeting date
3. `decision_count`: number of explicit decisions
4. `action_count`: number of explicit actions
5. `open_question_count`: number of explicit open questions
6. `deferred_idea_count`: number of explicit ideas
7. `tracker_rows_added`: number of appended action rows
8. `missing_due_dates`: new action identifiers whose due date is `TBD`, in source order
9. `checks`: exactly `["source-citations", "tracker-schema", "no-idea-promotion"]`

Before finishing, verify source counts, the exact tracker header, unique identifiers, source citations, and the absence of idea rows.
