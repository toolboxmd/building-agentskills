---
name: sanitizing-customer-exports
description: Normalize, validate, stably sort, and audit LumenDesk customer export CSV files. Use when an agent must turn a customer export into the exact canonical CSV and deterministic audit JSON contract, or safely reject malformed, prohibited, or duplicate customer data.
---

# Sanitize Customer Exports

Run the bundled sanitizer from the caller's current directory:

```bash
python3 <skill-directory>/scripts/sanitize_export.py --input INPUT --output OUTPUT --audit AUDIT
```

Supply three distinct paths. Treat the input as immutable. The script performs the schema checks, Unicode normalization, validation, stable sorting, hashing, deterministic serialization, atomic replacement, and failure cleanup; do not manually rewrite rows or audit fields.

On success, report the requested CSV and audit paths. On failure, relay the actionable stderr message and do not create substitute artifacts. The script removes stale requested output files on rejection and never requires network access or third-party packages.
