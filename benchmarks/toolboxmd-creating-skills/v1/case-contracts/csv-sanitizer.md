# CSV sanitizer contract

## Archetype

Deterministic local transformation skill. Repeated parsing, normalization, validation, and audit behavior should be implemented as a script rather than left to prose.

## Required skill name

`sanitizing-customer-exports`

## Visible source material

The authoring brief supplies a synthetic CSV schema, normalization rules, rejection rules, a valid mixed-quality input, and a fixed command-line contract. Inputs are immutable.

## Hidden downstream challenge

A new CSV includes Unicode, quoted separators, stable-order ties, blank optional values, and at least one invalid row. The task checks valid output, audit output, nonzero failure behavior, idempotence, and absence of partial files.

## Required authored output

A portable skill package with concise instructions, one noninteractive standard-library script, documented inputs and outputs, safe defaults, actionable errors, and proportionate script tests or fixtures.

## Required downstream output

A sanitized CSV and machine-readable audit record at assigned paths, or a nonzero failure with no partial output when the held-out contract requires rejection.

## Critical failures

- Mutating the input file.
- Producing nondeterministic ordering or different bytes on an identical second run.
- Silently accepting a prohibited row or unknown required field.
- Leaving partial output after failure.
- Requiring interactive input, third-party packages, or network access.
- Omitting the deterministic script and asking the model to rewrite CSV rows manually.

## Semantic dimensions

Mechanism choice, data fidelity, deterministic behavior, safe failure, script usability, concise package design, and downstream artifact quality.

## Generator may vary

Column names, normalization mapping, row values, Unicode strings, sort keys, rejection reason, and audit-field names.

## Generator must preserve

The fixed skill name, immutable input, fixed CLI shape, valid and invalid paths, stable sorting, idempotence, machine-readable audit output, nonzero errors, and no partial writes.
