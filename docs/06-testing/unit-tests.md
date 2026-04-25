# Unit tests: what to test in a skill

A SKILL.md is documentation. Most documentation is not testable. Skills are different: their scripts are testable like any other code, their disciplines are testable via pressure scenarios, and their spec compliance is testable via the official validator. This page covers the three kinds of test a non-trivial skill should have, and the cross-script regression rule that determines test scope when contracts change.

## Three kinds of test

### Script unit tests

If your skill ships with `scripts/`, every script change ships with a test that fails before the change and passes after. This is straight TDD applied to skill code.

The convention from karpathy-wiki (`CLAUDE.md`):

> Every new script must have unit tests before the script itself exists (TDD discipline).

Karpathy-wiki ships 21 unit tests at v2.2 (`REVIEWER` verification). The convention: PASS/FAIL prefix on output lines, an "ALL PASS" terminator at the end of a successful run, exit 1 on any FAIL. The format makes the test runner itself a parseable artifact for CI or for human eye-balling.

Example test runner shape (karpathy-wiki `tests/run-all.sh`):

```bash
#!/usr/bin/env bash
set -e
fail=0
for test in tests/unit/*.sh tests/integration/*.sh; do
    bash "$test" || fail=$((fail+1))
done
if [[ $fail -gt 0 ]]; then
    echo "FAIL: $fail test(s) failed"
    exit 1
fi
echo "ALL PASS"
```

### Pressure scenarios for discipline skills

Source: `obra/superpowers` writing-skills/SKILL.md lines 11-14:

> Writing skills IS Test-Driven Development applied to process documentation. You write test cases (pressure scenarios with subagents), watch them fail (baseline behavior), write the skill (documentation), watch tests pass (agents comply), and refactor (close loopholes).

A pressure scenario is a fresh-subagent test of a discipline:

1. Dispatch a subagent against the skill's domain WITHOUT the skill loaded. Document the rationalizations the subagent produces (this is the baseline behavior; the subagent will rationalize because the skill is not there to stop it).
2. Add the skill addressing those specific rationalizations (the skill's rationalization table grows from this step).
3. Re-dispatch a subagent against the same domain WITH the skill loaded. Verify the subagent now complies.

The pressure scenario is the discipline-skill equivalent of a unit test. It is more expensive than a unit test (each scenario is a subagent dispatch) but it is the only way to verify a discipline rule actually steers behavior.

Karpathy-wiki ships 4 GREEN scenarios at v2.2 (`tests/green/`; `REVIEWER` verification). Superpowers ships equivalents in `tests/skill-triggering/`.

### `skills-ref validate` for spec compliance

Source: agent-skills spec at https://agentskills.io/specification; `REVIEWER` G9.

The official validator from the agent-skills repo:

```bash
skills-ref validate ./your-skill
```

It checks:

- Frontmatter format (required fields present).
- Name format (lowercase, hyphens, ≤64 chars, matches parent dir, no reserved words).
- Directory layout (one-level-deep references; canonical sub-dirs).
- Description length (≤1,024 chars per the spec).

Run it before merging any frontmatter or directory-structure change. The validator catches mechanical violations cheaply; a human reviewer should not be the first to notice that your `name` field has uppercase letters in it.

Karpathy-wiki and superpowers both run validator-equivalent checks. Add `skills-ref validate` to your CI when CI exists (this repo's v0 has no CI; the validator is a manual step for now).

## Cross-script regression: the contract-touching rule

Source: `LESSONS` 2.4 (Task 50 cross-script regression; commit `42b24bf`).

When you modify a contract (a constant, a schema, an exported interface) in one script, the regression-test scope is the FULL test suite, not the test for the immediate file. Other scripts may share the contract; their tests may break in ways the immediate script's test does not surface.

The v2.2 evidence: removing `type: source` from `wiki-validate-page.py:VALID_TYPES` broke `wiki-normalize-frontmatter.py` (which mapped `sources/` directory → `type: source`). The plan's test step said run the validator's own unit test; the implementer ran `test-validate-page.sh`, saw it pass, committed. The reviewer caught it by running `tests/run-all.sh` and seeing `test-normalize-frontmatter.sh` fail.

The discipline:

> When a task modifies a contract (a constant, a schema, an exported interface), the regression-test scope is `bash tests/run-all.sh`, not the test for the immediate file. The cost of running an extra suite is seconds; the cost of a missed regression is a fix-up commit.

If your test infrastructure has a `run-all.sh` (or equivalent), make it the default for contract-touching changes. Reserve the per-file test for changes that touch only one file's behavior.

## What to put in test fixtures

Test fixtures (the captured input data your tests run against) carry the same discipline as the script code they exercise. Two specific traps surfaced in v2.2:

- **Arithmetic sanity.** If your fixture says "construct an X-byte file by writing N entries of Y bytes each," sanity-check that `N * Y > X` BEFORE running. Karpathy-wiki Task 56's fixture used `range(90)` with prose claiming "~9000 bytes"; each entry was actually ~70 bytes (= 6,300 bytes, below the 8,192 threshold the test was supposed to exercise). The implementer caught it during step 1 and adjusted to `range(120)`. See `LESSONS` 2.5.
- **Format sufficiency.** A fixture that lacks a required frontmatter field will fail the validator AND the test. If the test is supposed to exercise a particular code path, the fixture must satisfy every other code path that runs first. v2.2 had a missing `quality:` block in `tests/fixtures/.../orphan-source.md` that the spec reviewer flagged as a fixture, not code, issue.

## Test scope and the audit cycle

Skills evolve. As a skill grows, the test surface grows. A discipline skill that started with 50 lines of prose and one rationalization may need 4 GREEN scenarios + 21 unit tests + a self-review meta-test by version 2. The audit cycle (`docs/09-evolution.md`) should include "test surface coverage" as a checked dimension; if the skill has scripts but no tests, that is an audit finding.

## Sources

- `LESSONS` 2.4 (cross-script regression; commit `42b24bf`).
- `REVIEWER` G9 (the `skills-ref validate` library).
- `LANDSCAPE` 1.2 (superpowers' TDD-for-skills; pressure scenarios with subagents).
- `LANDSCAPE` 3.7 (test patterns: unit tests, integration tests, GREEN scenarios, self-review meta-test).

Cross-links: `case-studies/2026-04-25-karpathy-wiki-v2.2.md` (the cross-script regression in detail), `docs/09-evolution.md` (audit-cycle includes test surface coverage).
