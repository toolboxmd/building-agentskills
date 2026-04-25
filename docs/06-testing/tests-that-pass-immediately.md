# Tests that pass immediately: the two valid TDD inversions

Standard TDD discipline (Layer 2 superpowers convention from `test-driven-development`): write the test, watch it fail (the RED step), then write the code to make it pass (the GREEN step). The skill's iron law: "Tests passing immediately prove nothing."

This is correct in most cases. Karpathy-wiki v2.2 surfaced two specific cases where the inversion (write the test, watch it pass on the first run) is not just valid but is the right discipline. This page names them, gives the v2.2 evidence, and tells you how to recognize when you are in one of these cases versus when you are skipping TDD.

Source: `LESSONS` 5; `REVIEWER` "What the analyzer got right" #6 (TDD-inversion is genuinely new).

## Case A: regression-pin

The test pins existing correct behavior so a future refactor cannot silently break it.

Karpathy-wiki Task 59 example (`test-archive-strips-processing.sh`):

The helper `wiki_capture_archive` at `scripts/wiki-capture.sh:47` already strips the `.processing` suffix when archiving a capture file. Audit Finding 03 surfaced 4 legacy archive files that still had `.md.processing` suffixes from older code paths. The test exists not to drive the implementation (the implementation is already correct) but to prevent a future refactor from breaking the contract again.

The test:

```bash
# Setup: place a .md.processing file in an archive scenario
echo "..." > /tmp/test-capture.md.processing
# Exercise: call the helper
wiki_capture_archive /tmp/wiki /tmp/test-capture.md.processing
# Assert: the archived file ends in .md, not .md.processing
ls /tmp/wiki/.wiki-pending/archive/2026-04/test-capture.md
```

This passes immediately. The implementation is correct; the test pins it. A future refactor that changes the helper without updating the test will see the test fail; the regression is caught.

When to use regression-pin:

- The audit found a class of bugs (legacy artifacts, drift, broken state).
- The current implementation is correct.
- A future refactor is plausible (the module is still active code, not frozen).

Document the regression-pin status in the test header so a future reader does not think the test was a TDD violation:

```bash
# REGRESSION-PIN: prevents reintroduction of audit Finding 03 (legacy
# .md.processing in archives). wiki_capture_archive at scripts/wiki-capture.sh:47
# is already correct; this test fails if a future refactor breaks it.
```

## Case B: mechanism-rehearsal

The test rehearses a SKILL.md snippet because the actual ingester is a `claude -p` subprocess executing prose (the snippet is the contract; the LLM is the implementation).

Karpathy-wiki Task 56 example (`test-index-threshold-fires.sh`):

The actual ingester is a detached `claude -p` process that reads SKILL.md and runs the bash literally. The test cannot run the ingester (it would cost an LLM call). Instead, the test rehearses the mechanism in pure bash, asserting that the bash produces the right artifact.

The post-`0e0f815` test goes further: it copies the SKILL.md snippet verbatim into the test, so any change to the SKILL.md snippet must be mirrored to the test (and vice versa). This is closer to a contract test than a feature test.

```bash
# MECHANISM-REHEARSAL: the actual ingester is a `claude -p` subprocess that
# reads SKILL.md ingest step 7.6 and runs the bash. We cannot test that
# subprocess (LLM cost). The bash here is COPIED VERBATIM from SKILL.md;
# any divergence between this and the SKILL.md prose breaks the contract.
```

The test:

```bash
# Setup: index.md over the 8192-byte threshold
mkdir -p /tmp/wiki/.wiki-pending/schema-proposals
python3 -c "..."  # generate index.md > 8192 bytes

# Exercise: paste the SKILL.md ingest step 7.6 snippet verbatim
WIKI_ROOT=/tmp/wiki
size="$(wc -c < "${WIKI_ROOT}/index.md" | tr -d ' ')"
if [[ ${size} -gt 8192 ]]; then
    # ... (copied from SKILL.md verbatim)
fi

# Assert: a schema-proposal file exists
test -f "${WIKI_ROOT}/.wiki-pending/schema-proposals/"*-index-split.md
```

This passes immediately if the snippet is correct. It catches any future divergence between the SKILL.md prose and the bash-as-tested.

When to use mechanism-rehearsal:

- The actual mechanism is an LLM call (a subprocess with `claude -p` or equivalent).
- The mechanism's contract is expressible as code (bash, python).
- Running the LLM call is too expensive for routine testing.

The verbatim discipline is essential. Retyping the snippet is the failure mode that hid the v2.2 heredoc bugs originally; only the verbatim-paste catches platform-whitespace and indent-leak bugs. See `docs/05-authoring/prose-discipline.md`.

## When the inversion is invalid

Most of the time, "tests passing immediately" is a TDD violation. The test author has written the implementation first (or the test author and the implementer are the same person, the implementer wrote first and the test author rationalized). The test passes because it tests the existing code, not the contract.

The TDD skill is right about this case. Two specific failure shapes:

- **Test would have driven a new feature's design.** If the test is for a feature that did not exist yet, write the test first. Watch it fail. Then write the feature. The "RED" step is the design feedback; skipping it skips the feedback.
- **Test exists to catch a bug.** Bug-fix tests must fail before the fix lands. If the test passes immediately, you have not proven the test would have caught the bug. The test is decorative; the fix may or may not work.

For these cases, "tests passing immediately prove nothing" is the right discipline.

## How to tell which case you are in

Ask yourself, in order:

1. Does the implementation already exist and is it correct? If yes, you are in Case A (regression-pin) or Case B (mechanism-rehearsal). Pick the one that fits.
2. Does the implementation not yet exist? You are in canonical TDD. Watch the test fail before writing the implementation.
3. Is there a bug being fixed? You are in canonical bug-fix TDD. Write the test, watch it fail (the test catches the bug), apply the fix, watch the test pass.

The test header should say which case you are in. If the test does not declare its case, the next reviewer cannot tell whether the immediate-pass is a discipline win or a discipline violation.

## Plan-shape implications

If you are writing a plan that includes a test step, mark "test passes immediately" tasks explicitly:

> Step 2: Run the test to verify it passes immediately. (This test is a regression pin / mechanism rehearsal; see [link]. The implementation already exists; the test prevents future regression / verifies the contract.)

Without this annotation, the implementer will think they are violating TDD and may rewrite the test to fail first (defeating the regression-pin or mechanism-rehearsal purpose). Source: `LESSONS` 2.0 (writing-plans gap; "TDD-doesn't-fit gating").

## Sources

- `LESSONS` 5 (the two valid TDD inversions; Tasks 56 and 59).
- `REVIEWER` "What the analyzer got right" #6 (TDD-inversion is genuinely new; not in superpowers test-driven-development or writing-skills RED-GREEN-REFACTOR).

Cross-links: `docs/06-testing/red-green-for-prose.md`.
