Use the generated skill to sanitize and verify held-out customer exports.

You must first read `output/sanitizing-customer-exports/SKILL.md` at that exact path and follow it without repairing or editing the skill. Read these immutable held-out inputs:

- `downstream-inputs/customers-unicode.csv`
- `downstream-inputs/customers-prohibited.csv`

From the case root, perform all of the following with the skill's documented standard-library script:

1. Sanitize `customers-unicode.csv` to `downstream-output/customers-sanitized.csv` with audit `downstream-output/customers-audit.json`.
2. Repeat the identical transformation to `downstream-output/customers-sanitized-second.csv` and `downstream-output/customers-audit-second.json` so byte equality can be checked.
3. Attempt to sanitize `customers-prohibited.csv` to `downstream-output/rejected.csv` with audit `downstream-output/rejected-audit.json`; this invocation must fail nonzero and leave neither requested file.
4. Write `downstream-output/run-report.md` recording the three exact commands, their exit status, and whether both successful artifact pairs are byte-identical.

Do not modify any input. Do not use interactive input, third-party packages, the network, user memory, prior benchmark output, another model, or another agent. Do not manually repair generated CSV, JSON, script, or report content. If the skill cannot satisfy its contract, report the failure instead of substituting a manual transformation.
