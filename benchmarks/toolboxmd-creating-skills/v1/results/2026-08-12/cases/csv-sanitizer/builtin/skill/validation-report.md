# Validation report

Created `SKILL.md`, `agents/openai.yaml`, the standard-library sanitizer at `scripts/sanitize_export.py`, and offline integration tests at `tests/test_sanitize_export.py`.

Final checks run from the package directory:

- `python3 -m unittest discover -s tests -v`
- `python3 ../../creator/scripts/quick_validate.py .`
- End-to-end success on the supplied mixed-valid fixture, with exact expected CSV rows, hashes, counts, key order, UTF-8, newline, stable ordering, and byte-identical repeat output checked.
- End-to-end rejection on the supplied normalized duplicate fixture, with nonzero status, actionable stderr, and stale output/audit removal checked.
- Additional offline coverage for malformed UTF-8 and CSV, wrong schema, extra cells, invalid email/region/status, distinct resolved paths, missing destination directories, comma quoting, blank lines, stable ties, and immutable input behavior.

Limitation: replacement of each requested file is atomic, but no filesystem API can make two separate destination-path replacements a single atomic operation. If the second replacement fails, the script immediately removes the first, so it never returns with a partial requested artifact set.
