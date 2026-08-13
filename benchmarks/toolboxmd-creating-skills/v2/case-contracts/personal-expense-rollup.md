# Personal expense rollup

## Daily job

Apply personal category rules to extracted transactions, update an expense tracker, create a monthly review, and validate the result.

## Target skill

`personal-expense-rollup`

## Why a skill should help

The model can manipulate CSV data, but the useful skill must activate from a normal request, apply private mappings, remove duplicates, exclude transfers, keep deterministic ordering and totals, and complete QA.

## No-skill qualification

The no-skill arm receives the same extracted CSV, existing tracker, and private rules. OCR is deliberately excluded so a failure measures procedural adherence rather than vision quality.

## Positive trigger

A natural request asks to roll the latest transactions into the personal tracker and prepare the monthly review. It does not mention a skill or list the procedure.

## Near miss

A related request asks for general ideas for reducing subscription spending. It should not activate the transaction-processing procedure.

## Authoring material

The creator receives the user's category, duplicate, transfer, ordering, summary, and QA contract plus a worked example with different transactions.

## Held-out downstream task

The held-out CSV contains new expenses, an input duplicate, an existing-tracker duplicate, and an excluded transfer.

## Critical assertions

The updated tracker is byte-exact, sorted, deduplicated, and excludes the transfer. The monthly review contains exact totals and category values. The QA receipt records exact counts, total, and checks. Protected inputs remain unchanged.

## Cost and trace evidence

Record package size, authoring tokens, target load, unexpected loads, downstream uncached tokens, output tokens, duration, deterministic checks, and boundary audit.
