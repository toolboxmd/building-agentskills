# Sanitizer Run Report

## Commands and exit status

1. `python3 output/sanitizing-customer-exports/scripts/sanitize_export.py --input downstream-inputs/customers-unicode.csv --output downstream-output/customers-sanitized.csv --audit downstream-output/customers-audit.json`
   - Exit status: `0`

2. `python3 output/sanitizing-customer-exports/scripts/sanitize_export.py --input downstream-inputs/customers-unicode.csv --output downstream-output/customers-sanitized-second.csv --audit downstream-output/customers-audit-second.json`
   - Exit status: `0`

3. `python3 output/sanitizing-customer-exports/scripts/sanitize_export.py --input downstream-inputs/customers-prohibited.csv --output downstream-output/rejected.csv --audit downstream-output/rejected-audit.json`
   - Exit status: `1`
   - Error: `header must be exactly: customer_ref,email,region,display_name,note,status`

## Verification

- `customers-sanitized.csv` and `customers-sanitized-second.csv` are byte-identical: yes.
- `customers-audit.json` and `customers-audit-second.json` are byte-identical: yes.
- Both successful artifact pairs are byte-identical: yes.
- `rejected.csv` was left absent after rejection: yes.
- `rejected-audit.json` was left absent after rejection: yes.
