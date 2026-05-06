# Case study: karpathy-wiki v2.2 ship

**Date:** 2026-04-25  
**Subject:** karpathy-wiki, branch `v2-rewrite`, tip `4f4c00d`  
**Plugin manifest:** v0.2.2  
**Audit input:** 16 findings (3 blockers / 5 highs / 6 mediums / 2 lows)  
**Plan:** 13 tasks across 4 phases, 2,029 lines  
**Output:** 19 commits on the v2-rewrite branch

This is the seed case study for `toolboxmd/building-agentskills`. It documents what one stateful, artifact-manipulating skill learned in shipping v2.2: what worked, what failed, what the existing canon missed, what we added.

The full retrospective lives in the document we cite as `LESSONS` (see [Overview → Sources](/docs/00-overview#sources)). This case study is the public-audience version, written for readers who landed here from a search.

## Ship summary

karpathy-wiki is an auto-capture-and-ingest LLM wiki, stateful and artifact-manipulating. v2.2 was a hardening ship: 16 audit findings, 13 implementation tasks, 19 commits over a few days. The audit named "decoration vs mechanism" as the strongest signal for what to fix; v2.2 wired three previously-decoration invariants to mechanism.

Net diff:

- 1 architectural cut (delete the `sources/` category entirely; collapsed three audit findings).
- 3 decoration-to-mechanism wirings (index-size threshold, manifest origin contract, validator-blocks-commit).
- 5 reviewer-driven fix-ups (each caught a real silent bug pre-merge).
- 1 self-flagged nit (Task 60 `mv -n` for archive rename).
- 1 release-plumbing commit (LICENSE + version bump + gitignore).
- Net SKILL.md change: +21 lines (455 to 476).

## The architectural cut

Source: `LESSONS` 3.

The audit listed Findings 02 (mistyped sources/), 05 (stub bodies), 09 (duplicate sources) as three separate findings to fix mechanically. The brainstorming step asked "are these symptoms or the disease?" and surfaced an architectural answer: the `sources/` category itself was the wrong abstraction. Deleting it collapsed three findings into one cut.

The architectural decision is documented in the [v2.2 spec doc, lines 30–65](https://github.com/toolboxmd/karpathy-wiki/blob/4f4c00d/docs/superpowers/specs/2026-04-24-karpathy-wiki-v2.2-design.md?plain=1#L30-L65), with an explicit "Architectural decision: kill `sources/`" section and a job-vs-replacement table. Without brainstorming, v2.2 would have shipped 7+ patches plus 31 stub-improvement passes; instead it shipped one architectural cut + 5 mechanism-wirings.

The pattern: brainstorming surfaces architectural decisions that audit findings cannot. The audit is shape-blind by design (it enumerates symptoms); brainstorming asks "what is the disease?" The deletion of `sources/` was not in the audit; it came from the brainstorming step.

For your own skills: when an audit lists multiple findings that share a category, ask whether the category itself is the right abstraction. If the answer is no, the brainstorming output is "delete the category" rather than "fix each finding." See [Mental model](/docs/02-mental-model) for the broader frame.

## The three decoration-to-mechanism wirings

Source: `LESSONS` 2.1; commits `dabf10a`, `36f0aa8`, `d325dda`, `0e0f815`, `f72bfc3`.

v2.2 converted three SKILL.md decorations into wired mechanisms:

1. **Index-size threshold** — pre-v2.2 prose said "split when `index.md` > 8KB" but the live wiki was 25 KB and 30+ ingests had never written a schema-proposal capture. v2.2 wired ingest step 7.6 to measure (`wc -c`) and emit a capture when over threshold.
2. **Manifest origin contract** — Iron Rule #7 enumerated valid `origin` values; two live entries had `"origin": ""` and the validator never checked. v2.2 added `wiki-manifest.py validate` with exit 1 on empty/typename/relative-path origins.
3. **Validator-blocks-commit** — partial wiring; SKILL.md prose strengthened, paired with `f72bfc3` to reduce false-positives. Honest evidence that the rule is a spectrum.

Full walkthrough with all five commits: [Mechanism vs decoration — three wirings](/docs/07-mechanism-vs-decoration).

## The five reviewer-driven fix-ups

Source: `LESSONS` 2.6; verified commit-by-commit in `REVIEWER` verification table.

19 commits on the v2-rewrite branch. 5 were reviewer-driven fix-ups, or 26.3 percent. (`REVIEWER` corrected the analyzer's earlier 28% figure to the precise 26.3%; both are within the healthy 25-40% band.)

### `42b24bf`: cross-script regression in `wiki-normalize-frontmatter.py`

Task 50 removed `type: source` from `wiki-validate-page.py:VALID_TYPES`. The implementer ran `test-validate-page.sh`, saw it pass, committed. They did not run `tests/run-all.sh`. The reviewer caught it: `wiki-normalize-frontmatter.py` mapped `sources/` → `type: source`, which the validator now rejects. Fix: map `sources/` → `type: concept` instead.

Lesson for the building-agentskills repo: contract-touching changes default to the full test suite scope. See [Unit tests](/docs/06-testing/unit-tests).

### `697318a`: 3 orphan `type: source` references in SKILL.md

Task 51 removed the `sources/` source-pointer rule prose. The implementer's grep was for `sources/<basename>`; they missed three lines mentioning `type: source` (the type-whitelist value, different pattern). The reviewer caught it.

Lesson: prose-deletion tasks need to enumerate ALL related patterns. See [Red-green for prose](/docs/06-testing/red-green-for-prose).

### `3dfc26b`: stale module-level docstring in `wiki-manifest.py`

Task 54 added a `validate` subcommand. The implementer updated `usage:` print in `main()`; missed the module-level docstring at lines 4-7 that also enumerates subcommands.

Lesson: when modifying a script's interface, the plan's modify set should include the script's own docstring, help string, and any READMEs that mention the interface. See [Anti-patterns](/docs/10-anti-patterns).

### `0e0f815`: heredoc indent + `wc -c` whitespace bugs

Task 56 prose half embedded a bash heredoc in SKILL.md. Two silent correctness bugs: 3-space indent leak (validator rejected the rendered captures) and macOS `wc -c` whitespace leak in trigger-field strings. Reviewer caught both; fix rehearses the snippet verbatim and adds a `head -1 file == '---'` assertion.

Lesson: snippets in SKILL.md prose are production code when a headless subprocess executes them. See [Prose discipline](/docs/05-authoring/prose-discipline).

### `ff12716`: `${wiki}` interpolation hardening in inline Python

Task 58 embedded Python inside bash with shell interpolation: `python3 -c "... open('${wiki}/...') ..."`. Unsafe if `$wiki` contains an apostrophe or backslash. Fix: use argv interpolation.

Lesson: when BEFORE/AFTER blocks embed inline languages, variable interpolation goes through argv, not string substitution. Plan self-review checks for this pattern.

## What worked (Layer 2 patterns we used and validated)

- The brainstorming-spec-plan-execute pipeline. Earned its overhead. The architectural cut alone paid for the brainstorming step.
- The two-stage review (spec compliance, then code quality). Caught all 5 fix-ups.
- "No placeholders" in the plan. Every task had verbatim test bodies, BEFORE/AFTER blocks, commit messages.
- Fresh-subagent-per-task dispatch. Zero context pollution between tasks.
- Iron Laws plus rationalization tables. Karpathy-wiki has 3 Iron Laws and a 16-row rationalization table; both are load-bearing.

These are Layer 2 patterns from [obra/superpowers](https://github.com/obra/superpowers). We did not invent them; we applied them and they worked. See [00 overview](/docs/00-overview) for the layer distinction.

## What failed (or what would have been better)

- Plan Task 50's test step said "run validator unit tests" with the singular example; should have said "run full suite for contract-touching changes." Lost a few minutes to the fix-up commit.
- Plan Task 56's heredoc was hand-cleaned in the test; should have been pasted verbatim. The two silent bugs slipped through to the first commit and required a fix-up.
- Plan Task 56's fixture used `range(90)` claiming "~9000 bytes"; each entry was actually ~70 bytes (= 6,300, below threshold). Caught at implementation time, not in plan self-review.
- The implementer for Task 62 reflowed all of TODO.md as part of a section-move commit; 230-line diff for a 10-line task. Documented as TODO.md item but not yet fixed in the implementer prompt template.

Each of these surfaces a pattern the existing canon does not cover, documented in [Anti-patterns](/docs/10-anti-patterns).

## What the existing canon missed (Layer 3 deltas)

Patterns from this ship that are not in agent-skills + superpowers + Anthropic docs:

- **Decoration vs mechanism.** Named in the audit (line 366); not in any existing meta-skill. See [Mechanism vs decoration](/docs/07-mechanism-vs-decoration).
- **Heredoc-in-prose silent correctness.** The class of bugs Task 56 surfaced. See [Prose discipline](/docs/05-authoring/prose-discipline).
- **TDD inversions (regression-pin and mechanism-rehearsal).** Tasks 56 and 59 used these legitimately; the existing TDD skill treats them as anti-patterns. See [Tests that pass immediately](/docs/06-testing/tests-that-pass-immediately).
- **Subagent reformatting hazard.** Task 62 surfaced this; the `subagent-driven-development` red-flag list does not include it. See [Anti-patterns](/docs/10-anti-patterns).
- **Cross-script regression as plan-shape rule.** Task 50 surfaced this; writing-plans does not name it. See [Unit tests](/docs/06-testing/unit-tests).
- **Spec arithmetic sanity-check.** Task 56's fixture math; writing-plans self-review does not check this. See [Anti-patterns](/docs/10-anti-patterns).
- **Reviewer fix-up rate as quality signal.** 26.3% on this ship; not named anywhere as a metric. See [Evolution](/docs/09-evolution).

## What we missed (honest list)

The v2.2 ship was good but not perfect. Two known imperfections shipped, documented in [karpathy-wiki TODO.md](https://github.com/toolboxmd/karpathy-wiki/blob/main/TODO.md) with `status: open / labels: [known-imperfection]`:

- **Migration-script regex misses inline-list.** The v2.2 migration script's regex for finding source-pointer references in SKILL.md missed inline-list mentions; manual cleanup would still be required for one specific case.
- **Subagent reformatting hazard.** Task 62's reformatting was caught and documented but the implementer-prompt.md fix has not been applied. The next ship will absorb this.

These are not failures of the framework; they are evidence that the framework surfaces what it cannot solve and labels it. Known imperfections are honest deliveries, not silent bugs.

## What this case study demonstrates

For Layer 1 (agent-skills foundation): a 476-line spec-compliant SKILL.md is feasible and useful. The 500-line cap is real and load-bearing; v2.2 stayed under it deliberately.

For Layer 2 (superpowers conventions): the brainstorming-spec-plan-execute pipeline plus two-stage review plus Iron-Laws-and-rationalization-tables plus TDD-for-prose all worked as advertised. We validated, we did not invent.

For Layer 3 (this repo's deltas): seven patterns from this ship are not in the existing canon. Each one cites a specific commit or failure mode. Each one is documented in this repo with a cross-link to the relevant doc.

The single most important pattern, if you read only one: **decoration vs mechanism**. Every threshold or invariant in your SKILL.md must answer "what fires on it?" If the answer is "the agent decides," wire it to a mechanism. The audit named this pattern; v2.2 wired three; the rule's authority is now evidenced.

## Cross-links

- [Three questions](/docs/03-three-questions) (the hero framework; karpathy-wiki's worked answers expanded)
- [Mechanism vs decoration](/docs/07-mechanism-vs-decoration) (the three v2.2 wirings in detail)
- [Prose discipline](/docs/05-authoring/prose-discipline) (the Task 56 heredoc bugs)
- [Update mechanism](/docs/12-update-mechanism) (per-ship retrospective format)
- [Anti-patterns](/docs/10-anti-patterns) (every fix-up commit corresponds to an anti-pattern)
- [Mental model](/docs/02-mental-model) (when a skill is the right primitive at all; karpathy-wiki is auto-trigger by design)
- [Evolution](/docs/09-evolution) (reviewer fix-up rate at 26.3% is healthy)

## Sources

- `LESSONS` (entire). The v2.2 lessons report.
- `REVIEWER` "What the analyzer got right" (verified-commits list; the 5 fix-ups all confirmed via `git show --stat`).
- `REVIEWER` verification table (the 26.3% precision; the 476 line count post-v2.2; the `skills/pdf` path correction).
