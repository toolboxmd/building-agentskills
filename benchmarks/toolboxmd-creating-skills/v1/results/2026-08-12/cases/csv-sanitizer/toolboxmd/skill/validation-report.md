# Validation report

## Files created

- `SKILL.md`: activation boundary and fixed invocation guidance.
- `scripts/sanitize_export.py`: standard-library CSV sanitizer and audit writer.
- `tests/test_sanitize_export.py`: offline subprocess regression tests.
- `validation-report.md`: this report.

## Checks run

- `python3 -m py_compile scripts/sanitize_export.py tests/test_sanitize_export.py` passed.
- `python3 scripts/sanitize_export.py --help` passed and showed the fixed required options.
- `python3 -m unittest discover -s tests -v` passed all three test methods.
- The package validator passed its portable layout, frontmatter, and reference checks.
- A smoke run against `mixed-valid.csv` succeeded; its CSV rows, audit hashes, counts, key order, and final newlines were inspected.
- A smoke run against `rejected-duplicate.csv` exited nonzero with an actionable duplicate diagnostic and no requested artifacts.

## Coverage

Success coverage includes normalization, comma-preserving CSV quoting, stable sorting, exact deterministic bytes across replacement runs, hashes, counts, and ordered JSON. Rejection coverage includes duplicate normalized references, malformed UTF-8, malformed quote structure, and colliding resolved paths; rejection tests begin with stale artifacts and assert their removal while preserving a colliding input.

## Limitation

Validation was entirely offline. The tests exercise representative contract boundaries rather than every invalid value permutation or operating-system-level interruption during the two-file replacement sequence.
