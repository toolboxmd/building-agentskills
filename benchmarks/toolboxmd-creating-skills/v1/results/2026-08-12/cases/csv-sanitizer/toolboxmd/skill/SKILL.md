---
name: sanitizing-customer-exports
description: Sanitize LumenDesk customer-export CSV files into the canonical CSV and deterministic audit JSON contract. Use when asked to normalize, validate, sort, or audit a customer export with the six-field LumenDesk schema; do not use for unrelated CSV schemas or ad hoc spreadsheet cleanup.
---

# Sanitize customer exports

Run the bundled deterministic sanitizer from this skill directory:

```bash
python3 scripts/sanitize_export.py --input INPUT --output OUTPUT --audit AUDIT
```

Interpret all three paths from the caller's current directory. Choose distinct input, output, and audit paths. The sanitizer leaves the input untouched, creates missing output parent directories, and replaces both requested artifacts only after the entire input and both artifacts have been validated and constructed.

On success, use the generated CSV as the canonical export and the JSON as its integrity/count audit. On failure, report the stderr diagnostic and correct the source data or path selection; do not manually rewrite rows or treat absent outputs as a successful empty export. A failure deliberately removes any old files at the requested output and audit paths so stale artifacts cannot be mistaken for current results.

The script requires Python 3 and only the standard library. Run the offline regression suite after changing it:

```bash
python3 -m unittest discover -s tests -v
```
