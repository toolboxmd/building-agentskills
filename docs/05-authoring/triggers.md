# Triggers: description as activation contract

The description is the only part of your SKILL.md the agent reads on every turn. It is the activation contract. If the description does not name a trigger, the skill never fires for that trigger. This page covers writing a description that triggers correctly, the description shapes in the wild, when a description is not enough, how to write routing rows that send the agent to a reference file before an action, and how to test a trigger.

## The Layer 2 rule (superpowers convention)

Source: `LANDSCAPE` 1.2; [obra/superpowers `skills/writing-skills/SKILL.md`, Skill Discovery Optimization, lines 140-172](https://github.com/obra/superpowers/blob/8ca22db/skills/writing-skills/SKILL.md?plain=1#L140-L172), at commit `8ca22db`. The section was called Claude Search Optimization until superpowers renamed it ([`RELEASE-NOTES.md` line 264](https://github.com/obra/superpowers/blob/8ca22db/RELEASE-NOTES.md?plain=1#L264)).

Verbatim from [lines 152-154](https://github.com/obra/superpowers/blob/8ca22db/skills/writing-skills/SKILL.md?plain=1#L152-L154):

> The description should ONLY describe triggering conditions. Do NOT summarize the skill's process or workflow in the description.
>
> **Why this matters:** Testing revealed that when a description summarizes the skill's workflow, an agent may follow the description instead of reading the full skill content.

The rule rests on one reported case, not on measured rates: a description saying "code review between tasks" made an agent do one review although the body's flowchart specified two. With the description changed to "Use when executing implementation plans with independent tasks", the agent followed the two-stage review. The summary leaked the wrong contract.

The superpowers shape is "Use when" followed by triggering conditions, often ending with the moment just before the agent would break the rule:

> Use when implementing any feature or bugfix, before writing implementation code

That example is in [line 171](https://github.com/obra/superpowers/blob/8ca22db/skills/writing-skills/SKILL.md?plain=1#L171) and [546-552](https://github.com/obra/superpowers/blob/8ca22db/skills/writing-skills/SKILL.md?plain=1#L546-L552), which tell authors to add "symptoms of when you're ABOUT to violate the rule". No superpowers description has a SKIP clause or an anti-rationalization clause: at `8ca22db`, searching the repository for "SKIP when", "Do NOT skip" and "forbidden rationali" finds nothing. That longer shape is karpathy-wiki's, shown below.

Superpowers asks for descriptions under 500 characters if possible ([line 103](https://github.com/obra/superpowers/blob/8ca22db/skills/writing-skills/SKILL.md?plain=1#L103)). Its 15 descriptions at `8ca22db` run from 79 to 375 characters.

This "Use when..." format is convention, not specification (per `REVIEWER` B3); the spec only requires that the description "describes what the skill does and when to use it." The convention is a strong default but not the only valid shape.

## The contrasting shape: Anthropic's PDF skill

Source: `REVIEWER` "Failed-URL re-fetches"; `https://raw.githubusercontent.com/anthropics/skills/main/skills/pdf/SKILL.md`.

Anthropic's `skills/pdf` (NOT `document-skills/pdf`; that path does not exist; the analyzer's earlier reports had it wrong, the reviewer corrected to `skills/pdf`) is the canonical "long enumerative trigger inventory" shape. Its description is approximately:

> Use this skill whenever the user wants to do anything with PDF files. This includes reading or extracting text/tables from PDFs, combining or merging multiple PDFs into one, splitting PDFs apart, rotating pages, adding watermarks, creating new PDFs, filling PDF forms, encrypting/decrypting PDFs, extracting images, and OCR on scanned PDFs.

This is a comma-separated trigger inventory. No "Use when..." enumeration; no SKIP list; no anti-rationalization clause. The description IS the trigger map, expressed as natural prose.

All three shapes on this page work and are spec-compliant. The choice is convention. This repo presents them without mandating one (per `LANDSCAPE` B3 / `REVIEWER` B3).

The trade-off:

- **Superpowers "Use when..." shape.** Short and easy to scan; a closing clause such as "before writing implementation code" names the moment the skill must load. Cost: no explicit anti-triggers.
- **Karpathy-wiki's TRIGGER, SKIP and anti-rationalization shape.** SKIP and anti-rationalization clauses tell the agent when not to fire and which excuses not to accept. Cost: longer (about 750 characters for karpathy-wiki), harder to keep under the 1,024-character spec cap when triggers are many.
- **Anthropic enumerative shape.** Compact; flows as natural prose; easy for authors who do not know the spec. Cost: no anti-trigger clauses; the agent may over-fire when an adjacent topic comes up.

Over-firing is a failure, not a harmless cost. Superpowers' evals test it directly with `skill-not-called` checks ([scenario authoring](https://github.com/prime-radiant-inc/superpowers-evals/blob/e64684c/docs/scenario-authoring.md?plain=1#L520-L524)). In the `cost-checkbox-over-trigger` case, a user asks for "Just a basic checkbox with on/off state, nothing fancy", and invoking brainstorming is the failure. Opus 5 invoked it in 2 of 5 runs on superpowers main and 7 of 20 in an earlier sweep, about 35-40%; Opus 4.8 never did (0 of 51) ([Opus 5 signature experiment, lines 311-320](https://github.com/prime-radiant-inc/superpowers-evals/blob/e64684c/docs/experiments/2026-09-02-opus5-signature.md?plain=1#L311-L320)). An over-firing skill costs tokens and time on every task it wrongly claims, so test negatives for every shape (see [Test a trigger](#test-a-trigger)).

## Karpathy-wiki's description

The TRIGGER, SKIP and anti-rationalization shape comes from karpathy-wiki, not superpowers. From [the v2.2 SKILL.md, lines 3–12](https://github.com/toolboxmd/karpathy-wiki/blob/4f4c00d/skills/karpathy-wiki/SKILL.md?plain=1#L3-L12):

```yaml
description: |
  Load at the start of EVERY conversation. Entry is non-negotiable; once loaded, the skill's rules apply for the whole session.

  TRIGGER when (immediate capture): any research agent or research subagent completes or returns a file; new factual information is found (web search result, docs, external fact surfaced in conversation); session resolves a confusion; a gotcha, quirk, or non-obvious behavior is observed; a pattern is validated (approaches compared, one picked with reasons); an architectural decision is made with rationale; user pastes a URL or document to study; `raw/` has unprocessed files; user says "add to wiki" / "remember this" / "wiki it" / "save this"; two claims contradict each other.

  TRIGGER when (orientation + citation): the user asks "what do we know about X" / "how do we handle Y" / "what did we decide about Z" / "have we seen this before", or any question the wiki might cover.

  SKIP: routine file edits, syntax lookups, one-off debugging with trivial root causes, time-sensitive data that must be fetched fresh, or questions clearly outside any wiki's scope.

  Do NOT skip based on tone or shape. "this looks like casual chat", "there's no code here", "this isn't a wiki context" are forbidden rationalizations. If new factual info appeared, capture. Tone is not the trigger.
```

Notable elements:

- Eight event-shaped triggers (research agent returns a file, new factual info, etc.).
- Three question-shaped triggers ("what do we know about X").
- Five SKIP conditions.
- Anti-rationalization clause naming three specific forbidden rationalizations.
- ~750 characters total, under the 1,024 spec cap and the 1,536 Claude Code listing cap.

The description is the contract. If it does not name a trigger, the agent will not pick up the skill for that case.

## When a description is not enough

A description decides whether the agent may load a Skill. It does not make the agent load it at the moment the work needs it. The [AgentsMD routing benchmarks](/case-studies/2026-09-29-agentsmd-routing-benchmarks) measured this on Claude Code:

- Opus 5.5 never loaded the AgentsMD `operations` Skill from its description on naive README, glossary, test or `SKILL.md` prompts: 0 of 40 runs, although an always-loaded instruction also told it to invoke the Skill. It loaded the Skill on 15 of 40 negative prompts, all plain code edits ([toolboxmd/agentsmd#164 results](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/164-trigger-audit/results.md)).
- A session-start pointer of 417 characters (about 105 tokens) naming the Skill and the actions it governs took naive prompts from 3 of 20 to 20 of 20 ([toolboxmd/agentsmd#174 results](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/174-routing-injection/results.md)).

Codex and Grok Build loaded the same Skill without a pointer in 20 of 20 naive runs, so the gap is host- and model-specific. Superpowers reaches the same conclusion by design: its bootstrap loads at session start, and "The bootstrap is what causes skills to auto-trigger at the right moments" ([`AGENTS.md` line 76](https://github.com/obra/superpowers/blob/8ca22db/AGENTS.md?plain=1#L76)).

When a Skill must load before an action on a host that does not load Skills on its own, add a session-start pointer and keep it short: it costs tokens in every session. Name the Skill and the kinds of action, as the AgentsMD pointer does: "at the start of every task, and again before each new kind of action (researching, an experiment, reproducing a defect, the first file edit, a commit, a GitHub Issue or a pull request)" ([PR #184](https://github.com/toolboxmd/agentsmd/pull/184)).

## Routing rows

A Skill that sends the agent to reference files needs a routing table: each routing row names a trigger and the files to read for it. The same rules as for descriptions apply, with measured additions from the [AgentsMD routing benchmarks](/case-studies/2026-09-29-agentsmd-routing-benchmarks). Unless marked, the numbers are Opus 5.5 on Claude Code.

- **Name the action as a before-clause.** "Before opening or updating a PR, claiming readiness, or choosing or running proof or review" made Opus read the verification procedure before `gh pr create` in 5 of 5 runs; the earlier "Choose or run proof, review, or claim readiness" never names opening a PR and fired in 0 of 5 ([PR #184](https://github.com/toolboxmd/agentsmd/pull/184)).
- **Give each required file its own before-clause.** A bare conjunct is optional to Opus. In the row "Writing for agents and prose; SKILL-MECHANICS.md before editing a SKILL.md or a Skill description", Opus attempted to read SKILL-MECHANICS.md in 15 of 15 runs of the first #174 batch and prose.md in 4 of 15 ([`records-prefix.jsonl`](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/174-routing-injection/records-prefix.jsonl), arms A, B and C; read attempts, since that batch predates successful-read scoring). With prose.md in its own before-clause it read both in 5 of 5 ([PR #179](https://github.com/toolboxmd/agentsmd/pull/179)). Codex and Grok read every link in the row either way.
- **Name the next required file inside the file the model reliably reads.** AgentsMD's SKILL-MECHANICS.md now opens by naming the prose file; with that and the separate before-clause, writing-for-agents read both files in 5 of 5 runs on all four hosts ([PR #179](https://github.com/toolboxmd/agentsmd/pull/179)). The opening was not measured alone.
- **Ask for the read as its own step, before any command for the action.** On the diagnosis row, Opus read the procedure before reproducing in 8 of 10 runs; both misses ran `cat` on the procedure in the same shell call as the reproduction, so the reproduction was already chosen. Adding "Read it as its own step, before any command for that action" and naming reproduction in the row gave 5 of 5 ([toolboxmd/agentsmd#182 results](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/182-routing-sweep/results.md)).
- **Cover every new kind of action, not only task start.** An abstract "invoke at task start" rule did not fire: that is the 0 of 40 above. A pointer worded as a one-time check at the first tool call fixed research, prototype and grilling but dropped verification to 3 of 5 and opened the research procedure on a plain question in 2 of 5 runs. Naming each new kind of action restored both ([PR #184](https://github.com/toolboxmd/agentsmd/pull/184)).
- **Test a change to always-loaded text on every host it reaches.** The pointer tuned on Claude Code made OpenCode (Muse 1.3) open the research procedure on "What does add(2, 3) return? Answer from the code only." in 5 of 5 runs, so 0 of 5 clean. A row-level exclusion, "(not for a direct answer from the code at hand)", brought it back to 5 of 5 clean. Negatives on the tuning host alone would have shipped the regression ([case study](/case-studies/2026-09-29-agentsmd-routing-benchmarks)).

## Test a trigger

Source: `REVIEWER` M2; superpowers' [micro-test rules](https://github.com/obra/superpowers/blob/8ca22db/skills/writing-skills/SKILL.md?plain=1#L576-L587) and [transcript checks](https://github.com/prime-radiant-inc/superpowers-evals/blob/e64684c/docs/scenario-authoring.md?plain=1#L520-L524); the [AgentsMD routing benchmarks](/case-studies/2026-09-29-agentsmd-routing-benchmarks).

Writing a description or routing row without testing it is shipping unvalidated code. A trigger test needs:

1. **Naive prompts** that need the Skill or row but never name the Skill or the procedure. "The Installation section of README.md is wordy and hard to follow. Rewrite it so it is clear and short." tests a writing row; "use the technical-writing Skill" tests nothing.
2. **Negative prompts**: similar work that needs no procedure, such as fixing a typo or answering a question from the code. The procedure must stay unopened.
3. **Deterministic transcript checks**, not a judgment of the transcript: the required file was read successfully before the action (the first edit, the commit, `gh pr create`), and on negatives it was never read. A "read before the action" check passes vacuously when the action never happens, so pair it with a check that the action happened; superpowers-evals documents the same trap for its `skill-before-tool` verbs ([scenario authoring](https://github.com/prime-radiant-inc/superpowers-evals/blob/e64684c/docs/scenario-authoring.md?plain=1#L660-L666)).
4. **A no-guidance control.** Run the prompts without the new wording first. If the control already behaves, there is nothing to fix ([superpowers, line 582](https://github.com/obra/superpowers/blob/8ca22db/skills/writing-skills/SKILL.md?plain=1#L582)).
5. **At least 5 runs per prompt and arm.** Single samples lie (same source, line 583).
6. **The models users run, on every host the text reaches.** Opus skipped a bare conjunct that Codex and Grok read; OpenCode over-read where Opus did not.

For skills that gate on `paths:` glob patterns, also test that the skill does NOT fire outside the path scope. A skill with `paths: ["**/*.md"]` should not load when the agent is editing `.py` files.

A single fresh session per prompt is a smoke test. A result you will act on needs a harness; the harness is where most errors were found. See [Trigger benchmarks](/docs/06-testing/trigger-benchmarks) for the method.

## Common description failure modes

- **Workflow summary instead of triggers.** "Use when executing plans; performs code review between tasks." The agent may follow the description and skip the body. Replace with triggers: "Use when you have a written implementation plan to execute."
- **Single-keyword trigger.** "Use when working with files." Matches every conversation; over-fires constantly. Replace with specific keywords.
- **Triggers in the wrong column.** Action verbs ("performs," "executes," "creates") are workflow words, not trigger words. Trigger words are observation words ("the user types X," "Y just happened," "Z was just observed").
- **No SKIP clause when the domain is ambiguous.** A skill that triggers on "what do we know about X" should explicitly NOT trigger on "what does X mean in general" (the second is a definition request, not a wiki query).
- **Over-broad anti-trigger.** "DO NOT trigger on routine file edits" is fine; "DO NOT trigger if the user is busy" is meaningless. Anti-triggers must be specific.

See [Anti-patterns](/docs/10-anti-patterns) for the catalog of failure modes; [Unit tests](/docs/06-testing/unit-tests) for the harness-side validation.

## Sources

- `LANDSCAPE` 1.2 (superpowers' description-as-trigger discipline).
- obra/superpowers at `8ca22db`: [`skills/writing-skills/SKILL.md`](https://github.com/obra/superpowers/blob/8ca22db/skills/writing-skills/SKILL.md) lines 103, 140-172, 546-552 and 576-587; [`RELEASE-NOTES.md`](https://github.com/obra/superpowers/blob/8ca22db/RELEASE-NOTES.md?plain=1#L264) line 264; [`AGENTS.md`](https://github.com/obra/superpowers/blob/8ca22db/AGENTS.md?plain=1#L76) line 76.
- prime-radiant-inc/superpowers-evals at `e64684c`: [`docs/scenario-authoring.md`](https://github.com/prime-radiant-inc/superpowers-evals/blob/e64684c/docs/scenario-authoring.md) lines 520-524 and 660-666; [`docs/experiments/2026-09-02-opus5-signature.md`](https://github.com/prime-radiant-inc/superpowers-evals/blob/e64684c/docs/experiments/2026-09-02-opus5-signature.md?plain=1#L311-L320) lines 311-320.
- [AgentsMD routing benchmarks case study](/case-studies/2026-09-29-agentsmd-routing-benchmarks), with records and results in toolboxmd/agentsmd at `06b7af6`.
- `LANDSCAPE` 3.3 (description format conventions across the ecosystem).
- `REVIEWER` M1 (skill discoverability mechanics).
- `REVIEWER` M2 (the description-pressure-test loop, now [Test a trigger](#test-a-trigger)).
- `REVIEWER` "Failed-URL re-fetches" (the path correction: `skills/pdf` not `document-skills/pdf`; the PDF skill's enumerative trigger inventory shape).
- `REVIEWER` B3 (Claude Code-specific patterns claimed as harness-neutral; the "use when..." format is convention, not spec rule).

Cross-links: [Mental model](/docs/02-mental-model) (when a skill is the right primitive at all), [Unit tests](/docs/06-testing/unit-tests) (harness-side validation including pressure scenarios), [Trigger benchmarks](/docs/06-testing/trigger-benchmarks) (the full trigger-benchmark method).
