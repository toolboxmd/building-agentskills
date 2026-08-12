# LumenDesk customer export contract

All data in this benchmark is synthetic.

## Input schema

The header must be exactly these six names in this order:

`customer_ref,email,region,display_name,note,status`

CSV is UTF-8 with a header and follows ordinary RFC 4180 quoting. Reject an unexpected, missing, reordered, or duplicate column. Reject malformed UTF-8 or malformed CSV.

## Normalization

Apply Unicode NFKC normalization to every field first.

- `customer_ref`: trim surrounding Unicode whitespace and uppercase. It is required and must match `CUS-[0-9]{4}` after normalization.
- `email`: trim surrounding Unicode whitespace and lowercase. It is required, must contain exactly one `@`, and both sides must be nonempty. Internal whitespace is prohibited.
- `region`: trim surrounding Unicode whitespace, case-fold, and map `north`, `n`, or `nord` to `NORTH`; map `south`, `s`, or `sud` to `SOUTH`.
- `display_name`: trim surrounding Unicode whitespace and collapse each run of internal whitespace to one ASCII space. It is required.
- `note`: trim surrounding Unicode whitespace and collapse each run of internal whitespace to one ASCII space. It is optional and may be blank. Preserve commas as data.
- `status`: trim surrounding Unicode whitespace and case-fold. Map `active` or `enabled` to `ACTIVE`; map `paused` or `hold` to `PAUSED`.

Reject a row with an invalid required value, unsupported region, unsupported status, extra cell, or a `customer_ref` that duplicates another row after normalization. Blank lines are ignored and are not rows.

## Output CSV

Write UTF-8 without a byte-order mark, with `\n` line endings and the exact input header. Use Python CSV quoting with `csv.QUOTE_MINIMAL`. Sort by normalized `region`, then normalized `status`, preserving original input order for ties. Always end the CSV with one newline.

## Audit JSON

Write a UTF-8 JSON object with exactly these keys in this order:

1. `schema_version`: integer `1`
2. `input_sha256`: lowercase SHA-256 of the exact input bytes
3. `output_sha256`: lowercase SHA-256 of the exact output CSV bytes
4. `rows_read`: number of nonblank data rows
5. `rows_written`: number of output rows
6. `region_counts`: object with keys `NORTH`, then `SOUTH`, including zeros
7. `status_counts`: object with keys `ACTIVE`, then `PAUSED`, including zeros

Serialize with `ensure_ascii=false`, indentation of two spaces, and a final newline. Do not include timestamps, source paths, temporary filenames, or environment-dependent values.

## Safety and invocation

Invoke as:

`python3 scripts/sanitize_export.py --input INPUT --output OUTPUT --audit AUDIT`

Input, output, and audit paths must be three distinct resolved paths. Create missing parent directories for requested outputs. Validate the complete input and construct both complete artifacts before atomically replacing requested outputs. On any error, exit nonzero and ensure neither requested output nor requested audit exists, removing old requested artifacts if necessary. Never mutate the input.
