# Sanitization run report

All commands were run from the case root.

1. Command: `python3 output/sanitizing-customer-exports/scripts/sanitize_export.py --input downstream-inputs/customers-unicode.csv --output downstream-output/customers-sanitized.csv --audit downstream-output/customers-audit.json`
   Exit status: `0`

2. Command: `python3 output/sanitizing-customer-exports/scripts/sanitize_export.py --input downstream-inputs/customers-unicode.csv --output downstream-output/customers-sanitized-second.csv --audit downstream-output/customers-audit-second.json`
   Exit status: `0`

3. Command: `python3 output/sanitizing-customer-exports/scripts/sanitize_export.py --input downstream-inputs/customers-prohibited.csv --output downstream-output/rejected.csv --audit downstream-output/rejected-audit.json`
   Exit status: `1`
   Diagnostic: `error: line 1: invalid header; expected customer_ref,email,region,display_name,note,status in that order`
   Requested output and audit files absent: yes.

## Determinism verification

- `customers-sanitized.csv` and `customers-sanitized-second.csv` are byte-identical: yes.
- `customers-audit.json` and `customers-audit-second.json` are byte-identical: yes.
- Both successful artifact pairs are byte-identical: yes.
