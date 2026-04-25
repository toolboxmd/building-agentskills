# RED-GREEN-REFACTOR for prose changes

This page covers the discipline for SKILL.md prose changes. The standard RED-GREEN-REFACTOR cycle (Layer 2 superpowers convention from test-driven-development) maps cleanly to script changes; it does not map cleanly to pure-prose changes. Karpathy-wiki v2.2 surfaced four distinct prose-change sub-modes, each with its own discipline.

Source: `LESSONS` 4 (the four sub-modes from Tasks 51, 55, 56-prose, 59-prose); `LESSONS` 6.2 (the multi-pattern grep miss).

## The four sub-modes

Pure-prose tasks are not all the same. They differ in what the change is doing to the document, and the discipline differs accordingly.

| Sub-mode | Example v2.2 task | Test discipline |
|---|---|---|
| Prose-as-deletion | Task 51 (remove `sources/` rules) | Multi-pattern grep returns 0 hits |
| Prose-as-addition | Task 56 prose half (insert ingest step 7.6) | Section-header grep returns 1 hit AND verbatim-snippet test |
| Prose-as-tightening | Task 55 (strengthen Iron Rule #7) | BEFORE/AFTER in commit message AND reviewer reads diff |
| Prose-as-refactor | Task 59 prose tighten | `wc -l` check AND reviewer reads diff |

Each sub-mode has a different "test" that constitutes verification. Match the sub-mode to your task before deciding what to verify.

## Prose-as-deletion

You are removing references to a deprecated concept. The "test" is `grep -c <pattern> SKILL.md` returning 0.

The trap: enumerate ALL related patterns, not just the most obvious one.

Karpathy-wiki Task 51 evidence: the implementer removed the `sources/<basename>` source-pointer rule prose. The plan's verification step said "Verify no `sources/<basename>` mentions remain." The implementer ran the grep, saw zero hits, committed. The reviewer caught three surviving `type: source` mentions at lines 341, 344, 364 because the implementer's grep was for the directory pattern (`sources/<basename>`), not the type-whitelist value (`type: source`). Commit `697318a` fixed it.

The discipline:

> When removing a concept from a SKILL.md, enumerate every related pattern (the directory name, the type value, the rule name, the section header, any cross-references). Grep for each. The "I greped, no hits" satisfaction is unjustified if you only greped for one pattern.

Concretely, before deletion:

1. Write out every name the deleted concept goes by. Directory? Type value? Rule name? Section header? Cross-reference target?
2. Grep for each in turn.
3. The deletion is verified only when ALL greps return zero.

## Prose-as-addition

You are adding a new procedure to the SKILL.md. The "test" is two assertions: the prose appears AND any embedded snippet works verbatim.

Karpathy-wiki Task 56's prose half (insert ingest step 7.6) shipped with a heredoc snippet that the agent would execute verbatim. The test discipline (post-`0e0f815` fix):

1. Assert the section header exists: `grep -c '^7.6\.' SKILL.md` returns 1.
2. Rehearse the heredoc verbatim in a unit test. Paste the bytes from SKILL.md into the test; do not retype. Assert the rendered output is exactly what the SKILL.md prose claims it will be.

The verbatim-snippet test catches the silent-correctness bugs documented in `docs/05-authoring/prose-discipline.md` (the heredoc indent leak; the `wc -c` whitespace leak). Without it, the bugs slip past the prose-as-addition's "section exists" check.

## Prose-as-tightening

You are strengthening an existing rule. There is no script to test. The "test" is the diff itself plus a reviewer reading it.

Karpathy-wiki Task 55 (strengthen Iron Rule #7 prose). The plan included verbatim BEFORE and AFTER blocks in the task. The implementer ran the edit; the reviewer read the BEFORE / AFTER in the commit message and verified the AFTER appears in SKILL.md. No fix-up needed.

The discipline:

> Prose-as-tightening tests are the diff plus the reviewer. There is no mechanical test for "this prose is now bulletproof." The reviewer is the discipline.

Make the reviewer's job easier:

- Include verbatim BEFORE / AFTER blocks in the commit message.
- Cite the audit finding or pressure-test that motivated the tightening.
- If the rule has a counterpart mechanism (a script, a hook), name it; the tightening is hollow without an enforcer.

## Prose-as-refactor

You are restructuring (renaming, moving sections, line-budget compliance) without changing semantics. The "test" is `wc -l SKILL.md` ≤ 500 and the reviewer reading the diff.

Karpathy-wiki Task 59's prose half tightened step 10's `.processing` strip prose to make the contract explicit. No mechanical test (the script `wiki_capture_archive` was already correct; the test pinned its behavior). The plan called it out explicitly: "Step 4: Tighten SKILL.md prose for step 10 to make the contract explicit." A prose change as a follow-up to a script-correctness pin. No fix-up needed.

The discipline:

> Prose-as-refactor tests are the line count plus the reviewer. The semantic invariant (this rename / move does not change what the agent does) cannot be mechanically verified; the reviewer holds the contract.

Same reviewer-friendly rules as prose-as-tightening: clear BEFORE / AFTER, audit citation, mechanism note.

## When the discipline is not RED-GREEN at all

Pure-prose changes do not have a "watch the test fail before implementing" RED step. The test for prose-as-deletion is "grep returns zero" which only becomes true AFTER deletion; you cannot watch it fail. Same for prose-as-addition: the section-header grep is true only after the section is added.

This is fine. RED-GREEN-REFACTOR is the discipline for behavior-bearing prose. For cosmetic and structural prose, the test is the diff plus the reviewer; the cycle is "write, diff, review."

For behavior-bearing prose that includes embedded code snippets (the prose-as-addition sub-mode with a snippet), the verbatim-snippet test IS a RED-GREEN cycle: write the test (RED, watch it fail because the snippet is not in SKILL.md yet); add the snippet to SKILL.md (GREEN); refactor for clarity (the test still passes). This is the only sub-mode where the canonical TDD cycle applies.

## Sources

- `LESSONS` 4 (the four prose-change sub-modes; Tasks 51, 55, 56-prose, 59-prose).
- `LESSONS` 6.2 (Task 51 multi-pattern grep miss; the orphan `type: source` references).

Cross-links: `docs/06-testing/unit-tests.md`, `docs/06-testing/tests-that-pass-immediately.md`.
