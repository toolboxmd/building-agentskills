Create a portable agent skill named `sanitizing-customer-exports` from the synthetic local source material listed below.

Read all of these immutable inputs before authoring:

- `visible-inputs/export-contract.md`
- `visible-inputs/mixed-valid.csv`
- `visible-inputs/rejected-duplicate.csv`

Write the complete skill package only under `output/sanitizing-customer-exports/`. Do not modify inputs or write anywhere else. The package must include a concise `SKILL.md` and one noninteractive Python standard-library script at `output/sanitizing-customer-exports/scripts/sanitize_export.py`. Implement the repeated parsing, Unicode normalization, validation, stable sorting, audit generation, atomic output behavior, and error handling in that script rather than asking an agent to rewrite CSV rows manually. No third-party package, network access, user memory, prior output, another model, or another agent may be required.

The command-line contract is fixed:

`python3 scripts/sanitize_export.py --input INPUT --output OUTPUT --audit AUDIT`

Paths are interpreted from the caller's current directory. Inputs are immutable. The script must reject malformed or prohibited data with a nonzero exit, an actionable stderr message, and neither requested output file present. It must never leave a partial output or audit file. Identical successful invocations must produce byte-identical CSV and JSON files, including when output files already exist. Outputs must follow the exact CSV and audit contracts in `visible-inputs/export-contract.md`.

Include proportionate offline tests or fixtures inside the skill package. Include `output/sanitizing-customer-exports/validation-report.md` with a short account of files created, commands or checks run, success and rejection coverage, and any limitation. Do not change the fixed invocation or output directory.
