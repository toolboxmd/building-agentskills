# Anti-patterns: failure modes catalog

Each anti-pattern below has a one-line definition, a one-line evidence trail (citing the karpathy-wiki v2.2 commit or the source report section), and a one-line counter. Use this as a checklist for self-audit and as a reviewer aid.

For the positive form of each pattern, follow the cross-link. Many of these anti-patterns are concrete failures of the second hero question (what fires on rules?) from the three-question framework; see `docs/03-three-questions.md` for the framework that this catalog inverts.

## Decoration without mechanism

- **Definition.** A SKILL.md invariant ("must," "always," "never," numeric threshold) that lives only in prose. The agent reads it and decides whether to act.
- **Evidence.** Karpathy-wiki pre-v2.2 had three decoration-without-mechanism instances: index-size threshold (live wiki was 25 KB / 3x over an 8 KB stated threshold; zero schema-proposal captures fired across 30+ ingests); manifest origin contract (Iron Rule #7 enumerated valid origins, but the validator did not check); validator-blocks-commit (audit Finding 04 traced 7 broken links to ingester ignoring validator). `LESSONS` 2.1, commits `dabf10a`, `36f0aa8`, `d325dda`.
- **Counter.** Every threshold or invariant must answer "what fires on it?" Wire to a script, validator, hook, or captured artifact. See `docs/07-mechanism-vs-decoration.md`.

## Heredoc-in-prose silent correctness

- **Definition.** A snippet embedded in SKILL.md prose (bash heredoc, JSON template, YAML stub) that gets executed verbatim by a headless subprocess, with subtle textual hazards (leading whitespace, line endings, character substitution) corrupting the output without failing tests.
- **Evidence.** Karpathy-wiki Task 56 (commit `dabf10a`) shipped two such bugs: 3-space indent leak from numbered-list rendering (validator rejected the rendered captures) and macOS `wc -c` whitespace leak in trigger-field strings. Both caught by reviewer in `0e0f815`. `LESSONS` 2.2.
- **Counter.** Test the snippet by rehearsing the verbatim copy. Paste the bytes from SKILL.md into the test; do not retype. Add an assertion on the rendered output's first byte (e.g., `head -1 file == '---'`). See `docs/05-authoring/prose-discipline.md`.

## Subagent reformatting hazard

- **Definition.** A dispatched implementer subagent reformats unrelated lines (line wrapping, trailing whitespace cleanup, alignment) as a "quality gesture" while completing its task. The reformat is not requested but is not forbidden; the agent treats it as helpful. The result is a diff that obscures the actual change.
- **Evidence.** Karpathy-wiki Task 62 (commit `a832fa5`): implementer reflowed all of TODO.md to ~80-char wrap as part of a section-move commit. Stats: 171 insertions, 59 deletions for substantively a 1-section move + 2 frontmatter edits. `LESSONS` 2.3.
- **Counter.** Add an explicit "Diff Scope" block to the implementer dispatch prompt forbidding reformat of unrelated lines. The acceptable diff is "the lines you had to add, edit, or delete to satisfy the task; nothing else." If the implementer notices an unrelated improvement, report it as a DONE_WITH_CONCERNS observation, do not silently bundle. `LESSONS` 2.3 has the full text.

## Cross-script regression

- **Definition.** A change to one script breaks another script that shares a contract (a constant, a schema, an exported interface). The plan's narrow test step ("run the validator's own test") misses the cross-script breakage.
- **Evidence.** Karpathy-wiki Task 50 (`LESSONS` 2.4): removing `type: source` from `wiki-validate-page.py:VALID_TYPES` broke `wiki-normalize-frontmatter.py` (which mapped `sources/` directory to `type: source`). Caught by reviewer running full suite; commit `42b24bf`.
- **Counter.** When a task modifies a contract, the regression-test scope is the FULL test suite (`bash tests/run-all.sh`), not the test for the immediate file. See `docs/06-testing/unit-tests.md`.

## Spec arithmetic errors

- **Definition.** A test fixture's prose claims "constructs an X-byte file by writing N entries of Y bytes each" but the math `N * Y` does not satisfy the threshold X.
- **Evidence.** Karpathy-wiki Task 56 fixture (`LESSONS` 2.5): plan said `range(90)` with prose "~9000 bytes." Each entry was actually ~70 bytes; `90 * 70 = 6,300` bytes, below the 8,192 threshold the test was supposed to exercise. Implementer caught it during step 1; adjusted to `range(120)`.
- **Counter.** Sanity-check `N * M` against the target threshold before dispatching the implementer. Add to plan self-review.

## Inline-language injection in BEFORE/AFTER blocks

- **Definition.** A plan's BEFORE/AFTER block embeds Python (or another language) inside bash, with variable interpolation through string substitution rather than argv. Path injection is unlikely in practice but a one-line hardening prevents the entire class.
- **Evidence.** Karpathy-wiki Task 58 (commit `a968f6c`, hardened in `ff12716`): added embedded Python that read `${wiki}` directly into the Python source string via shell interpolation. Unsafe if `$wiki` contains an apostrophe or backslash. `LESSONS` 6.5.
- **Counter.** Use argv interpolation: `python3 -c "import sys; ..." "${wiki}"` and reference as `sys.argv[1]`. Plan self-review checks for this pattern in any inline-language snippet.

## Stale module-level docstring

- **Definition.** A script's interface (subcommand list, function list, flag list) is updated in `main()` or the help string but the module-level docstring at the top of the file remains stale.
- **Evidence.** Karpathy-wiki Task 54 (commit `36f0aa8`, fixed in `3dfc26b`): added `validate` subcommand to `wiki-manifest.py`. Updated `usage:` print statement in `main()` but not the module-level docstring at lines 4-7. `LESSONS` 6.3.
- **Counter.** When modifying a script's interface, the plan's modify set should include the script's own docstring, own help string, and any READMEs that mention the interface. See `docs/06-testing/unit-tests.md`.

## Description summarizing workflow instead of triggers (Claude Code-specific)

- **Definition.** A SKILL.md description summarizes the body's workflow instead of naming triggering conditions. Claude Code's agent may follow the description and skip the body.
- **Evidence.** Source: `LANDSCAPE` 1.2; `obra/superpowers` writing-skills/SKILL.md:160-172. Verbatim: "A description saying 'code review between tasks' caused Claude to do ONE review, even though the skill's flowchart clearly showed TWO reviews (spec compliance then code quality)."
- **Counter.** Description starts with triggers ("Use when...") and lists 3-7 concrete trigger conditions. Skip the workflow summary; that lives in the body. See `docs/05-authoring/triggers.md`. (Flag: this anti-pattern is most acute on Claude Code, where the description is the primary activation signal. Other harnesses with explicit invocation, like OpenCode's `skill` tool, are less affected.)

## Skills with no test coverage

- **Definition.** "It's just prose" rationalization. The skill ships with no tests; the prose is treated as self-evidently correct.
- **Evidence.** Karpathy-wiki Task 56's heredoc bugs (`LESSONS` 4.4): the original test was a hand-cleaned variant of the snippet that hid the bugs. Without the verbatim-snippet test added in `0e0f815`, the malformed captures would have shipped to production.
- **Counter.** Pressure scenarios for discipline skills; verbatim-snippet tests for prose-with-snippets; `skills-ref validate` for spec compliance. See `docs/06-testing/unit-tests.md`.

## Skills depending on undocumented harness behaviors

- **Definition.** A skill depends on harness-specific quirks (substitution semantics, env var propagation, hook event ordering) that are not in the documented spec.
- **Evidence.** Karpathy-wiki: `${CLAUDE_PLUGIN_ROOT}` is a config-time substitution token in plugin.json and hooks.json; it does NOT propagate to the Bash tool. A SKILL.md using `${CLAUDE_PLUGIN_ROOT}` in bash fails for personal-symlink installs (literal string reaches Bash, expands to empty, command becomes invalid). See `/Users/lukaszmaj/wiki/concepts/claude-code-plugin-root-substitution.md`. (`LANDSCAPE` 4.5.)
- **Counter.** Test on real harness instances (not just the spec). Document harness gotchas in `docs/11-cross-platform/`. Use spec-portable patterns when possible; isolate harness-specific code paths.

## TDD-doesn't-fit gating absent

- **Definition.** A plan task's test step is "run the test to verify it passes immediately" without naming whether this is a regression-pin, a mechanism-rehearsal, or a TDD violation.
- **Evidence.** Karpathy-wiki Tasks 56 and 59: plan said "test passes immediately" without flagging the inversion as legitimate. The implementer is left guessing whether they are violating TDD discipline. `LESSONS` 5.
- **Counter.** Mark "test passes immediately" tasks explicitly. State whether the test is a regression-pin or a mechanism-rehearsal, and link the relevant doc. See `docs/06-testing/tests-that-pass-immediately.md`.

## How to use this catalog

For self-audit:

- Open your SKILL.md; check each anti-pattern against your skill.
- For each pattern that applies, follow the cross-link to the positive form and verify your skill complies with the cure.

For code review:

- Read the diff with this catalog in hand.
- For each pattern, ask "did this diff introduce or fix one of these?" Comment accordingly.

For plan review:

- Read the plan with this catalog in hand.
- The catalog flags the plan-shape anti-patterns (cross-script regression scope, spec arithmetic, inline-language injection, TDD-inversion gating). Each plan task that risks one of these should have explicit guarding language.

## Sources

- `LESSONS` 2 (Sections 2.1 through 2.6, all subsections).
- `LESSONS` 6 (Sections 6.3, 6.5).
- `LANDSCAPE` 1.2 (description-as-workflow-summary CSO violation).
- `LANDSCAPE` 4.4 (no-test-coverage anti-pattern).
- `LANDSCAPE` 4.5 (undocumented-harness-behavior anti-pattern).

Cross-links: `docs/03-three-questions.md`, `docs/07-mechanism-vs-decoration.md`, `docs/05-authoring/prose-discipline.md`, `docs/06-testing/unit-tests.md`, `docs/06-testing/tests-that-pass-immediately.md`, `docs/05-authoring/triggers.md`, `case-studies/2026-04-25-karpathy-wiki-v2.2.md`.
