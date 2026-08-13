# Personal expense rollup contract

Use this contract when the user asks to add extracted bank transactions to the personal tracker or prepare a monthly spending review.

## Inputs and output

Read the latest extracted transaction CSV and the existing tracker under `workspace/`. Write results under `output/` and never modify the inputs.

Create:

- `output/expense-tracker.csv`
- `output/monthly-review.md`
- `output/qa.json`

## Categories

Match merchant text case-insensitively after trimming surrounding whitespace:

- prefix `BIEDRONKA*`: `Groceries`
- exact `PKP INTERCITY`: `Transport`
- exact `SPOTIFY`: `Subscriptions`
- exact `APTEKA SOWA`: `Health`
- exact `PRZELEW WLASNY`: excluded `Transfer`

An unmapped merchant must not be guessed. Stop and report it instead of writing a partial tracker.

## Duplicate and transfer rules

- `transaction_id` is the stable duplicate key.
- Skip a row when its identifier already exists in the tracker.
- Within the new input, accept the first occurrence and skip later occurrences of the same identifier.
- Exclude transfers from the tracker and all spending totals.
- Count both existing-tracker and repeated-input rows as duplicates skipped.

## Tracker contract

Use exactly this header:

```text
date,transaction_id,merchant,category,amount_pln
```

Retain existing valid rows. Append accepted expense rows, then sort all rows by ISO date and transaction identifier. Format every amount with two decimal places.

## Monthly review contract

Use exactly these headings:

1. `# August 2026 spending review`
2. `## Total`
3. `## By category`
4. `## Processing notes`

Show the August total and each non-zero category total with two decimal places and `PLN`. State counts for accepted rows, duplicate rows skipped, and transfers excluded.

## QA contract

Write `output/qa.json` with exactly:

- `schema_version`: integer `1`
- `month`: `2026-08`
- `input_rows`: count of new input data rows
- `accepted_rows`: count appended
- `duplicates_skipped`: all duplicate input rows
- `transfers_excluded`: excluded transfer rows
- `tracker_rows`: final data-row count
- `total_pln`: numeric monthly total with two-decimal value
- `checks`: exactly `mapping`, `deduplication`, `transfer-exclusion`, `sort-order`, and `totals` in that order

Before finishing, verify unique identifiers, exact ordering, mapping coverage, transfer exclusion, and totals recalculated from the final tracker.
