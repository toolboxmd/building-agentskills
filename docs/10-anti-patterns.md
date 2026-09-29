# Anti-patterns: failure modes catalog

Each anti-pattern below has a one-line definition, a one-line evidence trail (citing the karpathy-wiki v2.2 commit, the source report section, or the AgentsMD benchmark records, PR or Issue), and a one-line counter. Use this as a checklist for self-audit and as a reviewer aid.

For the positive form of each pattern, follow the cross-link. Many of these anti-patterns are concrete failures of the second hero question (what fires on rules?) from the three-question framework; see [Three questions](/docs/03-three-questions) for the framework that this catalog inverts.

## Decoration without mechanism

- **Definition.** A SKILL.md invariant ("must," "always," "never," numeric threshold) that lives only in prose. The agent reads it and decides whether to act.
- **Evidence.** Karpathy-wiki pre-v2.2 had three decoration-without-mechanism instances: index-size threshold (live wiki was 25 KB / 3x over an 8 KB stated threshold; zero schema-proposal captures fired across 30+ ingests); manifest origin contract (Iron Rule #7 enumerated valid origins, but the validator did not check); validator-blocks-commit (audit Finding 04 traced 7 broken links to ingester ignoring validator). `LESSONS` 2.1, commits `dabf10a`, `36f0aa8`, `d325dda`.
- **Counter.** Every threshold or invariant must answer "what fires on it?" Wire to a script, validator, hook, or captured artifact. See [Mechanism vs decoration](/docs/07-mechanism-vs-decoration).

## Heredoc-in-prose silent correctness

- **Definition.** A snippet embedded in SKILL.md prose (bash heredoc, JSON template, YAML stub) that gets executed verbatim by a headless subprocess, with subtle textual hazards (leading whitespace, line endings, character substitution) corrupting the output without failing tests.
- **Evidence.** Karpathy-wiki Task 56 (commit `dabf10a`) shipped two such bugs: 3-space indent leak from numbered-list rendering (validator rejected the rendered captures) and macOS `wc -c` whitespace leak in trigger-field strings. Both caught by reviewer in `0e0f815`. `LESSONS` 2.2.
- **Counter.** Test the snippet by rehearsing the verbatim copy. Paste the bytes from SKILL.md into the test; do not retype. Add an assertion on the rendered output's first byte (e.g., `head -1 file == '---'`). See [Prose discipline](/docs/05-authoring/prose-discipline).

## Subagent reformatting hazard

- **Definition.** A dispatched implementer subagent reformats unrelated lines (line wrapping, trailing whitespace cleanup, alignment) as a "quality gesture" while completing its task. The reformat is not requested but is not forbidden; the agent treats it as helpful. The result is a diff that obscures the actual change.
- **Evidence.** Karpathy-wiki Task 62 (commit `a832fa5`): implementer reflowed all of TODO.md to ~80-char wrap as part of a section-move commit. Stats: 171 insertions, 59 deletions for substantively a 1-section move + 2 frontmatter edits. `LESSONS` 2.3.
- **Counter.** Add an explicit "Diff Scope" block to the implementer dispatch prompt forbidding reformat of unrelated lines. The acceptable diff is "the lines you had to add, edit, or delete to satisfy the task; nothing else." If the implementer notices an unrelated improvement, report it as a DONE_WITH_CONCERNS observation, do not silently bundle. `LESSONS` 2.3 has the full text.

## Cross-script regression

- **Definition.** A change to one script breaks another script that shares a contract (a constant, a schema, an exported interface). The plan's narrow test step ("run the validator's own test") misses the cross-script breakage.
- **Evidence.** Karpathy-wiki Task 50 (`LESSONS` 2.4): removing `type: source` from `wiki-validate-page.py:VALID_TYPES` broke `wiki-normalize-frontmatter.py` (which mapped `sources/` directory to `type: source`). Caught by reviewer running full suite; commit `42b24bf`.
- **Counter.** When a task modifies a contract, the regression-test scope is the FULL test suite (`bash tests/run-all.sh`), not the test for the immediate file. See [Unit tests](/docs/06-testing/unit-tests).

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
- **Counter.** When modifying a script's interface, the plan's modify set should include the script's own docstring, own help string, and any READMEs that mention the interface. See [Unit tests](/docs/06-testing/unit-tests).

## Description summarizing workflow instead of triggers (Claude Code-specific)

- **Definition.** A SKILL.md description summarizes the body's workflow instead of naming triggering conditions. Claude Code's agent may follow the description and skip the body.
- **Evidence.** Source: `LANDSCAPE` 1.2; `obra/superpowers` writing-skills/SKILL.md:160-172. Verbatim: "A description saying 'code review between tasks' caused Claude to do ONE review, even though the skill's flowchart clearly showed TWO reviews (spec compliance then code quality)."
- **Counter.** Description starts with triggers ("Use when...") and lists 3-7 concrete trigger conditions. Skip the workflow summary; that lives in the body. See [Triggers](/docs/05-authoring/triggers). The reported case is on Claude; no other host has been measured.

## Skills with no test coverage

- **Definition.** "It's just prose" rationalization. The skill ships with no tests; the prose is treated as self-evidently correct.
- **Evidence.** Karpathy-wiki Task 56's heredoc bugs (`LESSONS` 4.4): the original test was a hand-cleaned variant of the snippet that hid the bugs. Without the verbatim-snippet test added in `0e0f815`, the malformed captures would have shipped to production.
- **Counter.** Pressure scenarios for discipline skills; verbatim-snippet tests for prose-with-snippets; `skills-ref validate` for spec compliance. See [Unit tests](/docs/06-testing/unit-tests).

## Skills depending on undocumented harness behaviors

- **Definition.** A skill depends on harness-specific quirks (substitution semantics, env var propagation, hook event ordering) that are not in the documented spec.
- **Evidence.** Karpathy-wiki: `${CLAUDE_PLUGIN_ROOT}` is a config-time substitution token in plugin.json and hooks.json; it does NOT propagate to the Bash tool. A SKILL.md using `${CLAUDE_PLUGIN_ROOT}` in bash fails for personal-symlink installs (literal string reaches Bash, expands to empty, command becomes invalid). See [the plugin-root substitution wiki page](https://github.com/toolboxmd/karpathy-wiki/blob/main/wiki/concepts/claude-code-plugin-root-substitution.md). (`LANDSCAPE` 4.5.)
- **Counter.** Test on real harness instances (not just the spec). Document harness gotchas in `docs/11-cross-platform/`. Use spec-portable patterns when possible; isolate harness-specific code paths.

## Provider identity embedded in semantic instructions

- **Definition.** A reusable semantic skill calls itself a Claude, Codex, or Grok worker and constructs that provider's CLI command inside the procedure.
- **Evidence.** In the 2026-08-11 karpathy-wiki benchmark, the Spark model followed the frozen skill's Claude identity and launched a nested Claude ingester during the duplicate case. The attempt became attribution-invalid. The later runtime ship [`877e659`](https://github.com/toolboxmd/karpathy-wiki/commit/877e659) removed provider command construction from the ingest skill.
- **Counter.** Keep semantic judgment provider-neutral. Put provider/model/effort in structured local profiles and translate them through tested adapters. See [Provider-neutral runtime](/docs/05-authoring/provider-neutral-runtime).

## Contaminated agent benchmark

- **Definition.** A model comparison allows the candidate to delegate to another model or read memory, sibling runs, prior answers, graders, or rubrics.
- **Evidence.** One Spark attempt delegated to Claude; another read global memory, a previous run, and grader source before its first write. Both were stopped and excluded. The [evidence manifest](/case-studies/evidence/2026-08-11-karpathy-wiki-ingest-benchmark.json) records the invalid attempts and artifact hashes.
- **Counter.** Freeze inputs, isolate each run, forbid nested agentic invocation, audit read and command events, keep the candidate map outside blind review, and preserve contaminated attempts as ineligible evidence. See [Benchmark integrity](/docs/06-testing/benchmark-integrity).

## Mechanical completion used as a quality score

- **Definition.** Exit zero, valid files, or a green deterministic checker is treated as proof that an authored knowledge base is complete and useful.
- **Evidence.** The strongest Spark sample passed 19/21 deterministic assertions but scored 69/100 in blind semantic review; all candidates materially under-extracted customer research. Raw sources existed, but future-agent retrieval remained partial.
- **Counter.** Grade authored pages first with held-out realistic questions. Keep lifecycle, deterministic, semantic, and retrieval scores separate. Do not add a second LLM reviewer to every production ingest; qualify models offline. See [Benchmark integrity](/docs/06-testing/benchmark-integrity).

## TDD-doesn't-fit gating absent

- **Definition.** A plan task's test step is "run the test to verify it passes immediately" without naming whether this is a regression-pin, a mechanism-rehearsal, or a TDD violation.
- **Evidence.** Karpathy-wiki Tasks 56 and 59: plan said "test passes immediately" without flagging the inversion as legitimate. The implementer is left guessing whether they are violating TDD discipline. `LESSONS` 5.
- **Counter.** Mark "test passes immediately" tasks explicitly. State whether the test is a regression-pin or a mechanism-rehearsal, and link the relevant doc. See [Tests that pass immediately](/docs/06-testing/tests-that-pass-immediately).

## Trigger that does not name the action

- **Definition.** A routing row names a goal or a phase ("choose or run proof, review, or claim readiness") instead of the observable action the read must precede, so the agent takes the action without matching it to the row.
- **Evidence.** Opus 5.5 on Claude Code read the verification procedure before `gh pr create` in 0 of 5 runs ([toolboxmd/agentsmd#181](https://github.com/toolboxmd/agentsmd/pull/181)) and in 5 of 5 once the row began "Before opening or updating a PR" ([toolboxmd/agentsmd#184](https://github.com/toolboxmd/agentsmd/pull/184)). In the 0 of 5 runs, Opus branched, tested, committed and opened the PR without reading it ([case study](/case-studies/2026-09-29-agentsmd-routing-benchmarks)).
- **Counter.** Word each trigger as a before-clause that names the action. See [Triggers](/docs/05-authoring/triggers), "Routing rows".

## Bare conjunct in a routing row

- **Definition.** A routing row joins a second required file with "and" instead of giving it its own before-clause; a model can read the file inside the clause and treat the bare conjunct as optional.
- **Evidence.** In the row "Writing for agents and prose; SKILL-MECHANICS.md before editing a SKILL.md or a Skill description", Opus 5.5 attempted to read SKILL-MECHANICS.md in 15 of 15 runs and prose.md in 4 of 15 (first #174 batch, arms A, B and C, [`records-prefix.jsonl`](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/174-routing-injection/records-prefix.jsonl)). Those are attempts, not successful reads: the harness refused every procedure read in that batch, which is invalid for scoring, so the figures show which files Opus chose to open. With the harness fixed and prose.md in its own before-clause, Opus read both successfully in 5 of 5 ([toolboxmd/agentsmd#179](https://github.com/toolboxmd/agentsmd/pull/179)). Codex and Grok Build read every link either way.
- **Counter.** Give each required file its own before-clause, and name the next file inside the file the model reliably reads. See [Triggers](/docs/05-authoring/triggers), "Routing rows".

## Abstract task-start rule instead of a before-action pointer

- **Definition.** Always-loaded text says "invoke the Skill at task start" and relies on the description to do the rest, or a session-start pointer is worded as a one-time check, so the Skill is not loaded before later kinds of action.
- **Evidence.** Opus 5.5 loaded the AgentsMD `operations` Skill in 0 of 40 naive runs although the global contract told it to invoke it ([toolboxmd/agentsmd#164 results](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/164-trigger-audit/results.md)); a session-start pointer naming the Skill and the actions it governs reached 20 of 20 ([toolboxmd/agentsmd#174 results](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/174-routing-injection/results.md)). A later pointer worded as a check before the first tool call dropped verification from 5 of 5 (the row reword alone) to 3 of 5 and opened the research procedure on a plain question in 2 of 5 runs (fix1, [toolboxmd/agentsmd#184](https://github.com/toolboxmd/agentsmd/pull/184)).
- **Counter.** Keep a short session-start pointer that names the Skill and each new kind of action it governs, not only task start. See [Triggers](/docs/05-authoring/triggers), "When a description is not enough".

## Procedure read in the same call as the action

- **Definition.** The agent reads the procedure in the same shell call that performs the action (`cat procedure.md && <reproduce>`), so the action was chosen before the procedure was seen. The scorer can count the read, but the read changes nothing.
- **Evidence.** On the diagnosis row, Opus 5.5 read the procedure before reproducing in 8 of 10 runs on fix2; both misses were `cat` in the reproduction's shell call. "Read it as its own step, before any command for that action" gave 5 of 5 ([toolboxmd/agentsmd#182 results](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/182-routing-sweep/results.md), [toolboxmd/agentsmd#184](https://github.com/toolboxmd/agentsmd/pull/184)).
- **Counter.** Ask for the read as its own step, before any command for the action. See [Triggers](/docs/05-authoring/triggers), "Routing rows".

## Always-loaded text tuned on one host

- **Definition.** A pointer or routing row that every host loads is reworded and measured on one host only, and the change regresses another host.
- **Evidence.** The fix2 pointer, tuned on Claude Code, made OpenCode (Muse 1.3) open the research procedure on "What does add(2, 3) return? Answer from the code only." in 5 of 5 runs, against 0 of 5 on the released rows; the row exclusion "(not for a direct answer from the code at hand)" restored 5 of 5 clean ([case study](/case-studies/2026-09-29-agentsmd-routing-benchmarks), [toolboxmd/agentsmd#184](https://github.com/toolboxmd/agentsmd/pull/184)).
- **Counter.** Run negatives on every host the text reaches before shipping it. See [Triggers](/docs/05-authoring/triggers) and [Trigger benchmarks](/docs/06-testing/trigger-benchmarks).

## Refused read scored as a read

- **Definition.** A trigger benchmark counts the agent's attempt to read the procedure, although the host refused the read, so the agent never saw the text.
- **Evidence.** Before successful-read scoring, Opus 5.5 scored 17 of 20 on a #174 arm where every procedure read had been refused, and 10 of those 17 runs never edited ([`records-prefix.jsonl`](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/174-routing-injection/records-prefix.jsonl), [toolboxmd/agentsmd#179](https://github.com/toolboxmd/agentsmd/pull/179)). None of that batch's Claude Code cells are valid ([case study](/case-studies/2026-09-29-agentsmd-routing-benchmarks)).
- **Counter.** Count only successful reads: check permission denials, error results and host error parts. See [Trigger benchmarks](/docs/06-testing/trigger-benchmarks), "Make the instrument valid".

## Run without the action scored as a pass or a miss

- **Definition.** A run that reads the procedure and then stops has no moment to score against, and the scorer folds it into `fired` or into the misses.
- **Evidence.** The first scorer called such runs `fired`: 10 of the 17 hits above never edited ([toolboxmd/agentsmd#179](https://github.com/toolboxmd/agentsmd/pull/179)). In the #182 sweep, re-scoring every kept call list under the final rules, including the `read-noaction` verdict, changed 12 verdicts, 10 of them runs that read the procedure, took no action and had been scored as misses ([case study](/case-studies/2026-09-29-agentsmd-routing-benchmarks), [toolboxmd/agentsmd#184](https://github.com/toolboxmd/agentsmd/pull/184)).
- **Counter.** Give no-edit and no-action runs their own verdicts (`read-noedit`, `read-noaction`) and report them beside the fired count. See [Trigger benchmarks](/docs/06-testing/trigger-benchmarks), "Make the instrument valid".

## Green harness tests taken as a valid instrument

- **Definition.** A benchmark harness is trusted because its unit tests, self-checks and review pass, without checking that it observes the behavior it scores.
- **Evidence.** [toolboxmd/agentsmd#168](https://github.com/toolboxmd/agentsmd/pull/168) merged with 349 passing unit tests, guard and cleanup self-checks passing on all four hosts, and an independent APPROVE, while Claude Code could not read the plugin copy, OpenCode could not read through its Skill link, and the scorer counted both refusals as reads ([case study](/case-studies/2026-09-29-agentsmd-routing-benchmarks), [toolboxmd/agentsmd#179](https://github.com/toolboxmd/agentsmd/pull/179)).
- **Counter.** Read the call list of every miss, run a diagnostic canary with tool results visible, and suspect a result that jumps. See [Trigger benchmarks](/docs/06-testing/trigger-benchmarks), "Check the instrument, not only its tests".

## Unconfined harness shell

- **Definition.** A benchmark runs an agent with write access and a shell that can reach the real machine, guarded only by a snapshot of selected checkouts.
- **Evidence.** The first #164 pilot ran with the real HOME and skipped permissions; the model created a file in the canonical AgentsMD checkout, later runs edited it and two committed it, and the batch was discarded ([toolboxmd/agentsmd#164 results](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/164-trigger-audit/results.md)). Later, `--allowedTools Bash` let the shell reach any path, and the first Bash sandbox confined writes but left the real home and the keychain link readable; independent reviews flagged both as High ([toolboxmd/agentsmd#181](https://github.com/toolboxmd/agentsmd/pull/181), [toolboxmd/agentsmd#183](https://github.com/toolboxmd/agentsmd/pull/183)).
- **Counter.** Give each run a temporary HOME, a snapshot guard, and a shell sandbox that confines reads and writes, proven with real denials. See [Trigger benchmarks](/docs/06-testing/trigger-benchmarks), "Confine every run".

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
- [AgentsMD routing benchmarks case study](/case-studies/2026-09-29-agentsmd-routing-benchmarks), with records and results in toolboxmd/agentsmd at `06b7af6`, and PRs [#168](https://github.com/toolboxmd/agentsmd/pull/168), [#179](https://github.com/toolboxmd/agentsmd/pull/179), [#181](https://github.com/toolboxmd/agentsmd/pull/181), [#183](https://github.com/toolboxmd/agentsmd/pull/183) and [#184](https://github.com/toolboxmd/agentsmd/pull/184) (the routing and harness entries).

Cross-links: [Three questions](/docs/03-three-questions), [Mechanism vs decoration](/docs/07-mechanism-vs-decoration), [Provider-neutral runtime](/docs/05-authoring/provider-neutral-runtime), [Benchmark integrity](/docs/06-testing/benchmark-integrity), [Prose discipline](/docs/05-authoring/prose-discipline), [Unit tests](/docs/06-testing/unit-tests), [Tests that pass immediately](/docs/06-testing/tests-that-pass-immediately), [Triggers](/docs/05-authoring/triggers), [Trigger benchmarks](/docs/06-testing/trigger-benchmarks), [AgentsMD routing benchmarks](/case-studies/2026-09-29-agentsmd-routing-benchmarks), [v2.2 case study](/case-studies/2026-04-25-karpathy-wiki-v2.2).
