# Case study: ToolboxMD creating-skills benchmark v2

- **Date:** 2026-08-13
- **Subject:** Codex built-in `skill-creator` versus the frozen `toolboxmd-creating-skills` candidate
- **Decision:** Inconclusive after stricter trace re-audit; no ToolboxMD promotion
- **Configuration:** Codex CLI 0.147.0, `gpt-5.6-sol`, medium reasoning
- **Evidence:** [Condensed machine-readable manifest](/case-studies/evidence/2026-08-13-toolboxmd-creating-skills-benchmark-v2.json)

The corrected v2 benchmark found no eligible downstream quality winner. Both creators produced skills that triggered naturally and completed the declared daily-use tasks at the same deterministic quality, but a stricter post-result command audit made the ToolboxMD meeting-followups authoring trace ineligible. Only the status-deck pair remains eligible, where ToolboxMD won on a low-confidence one-run cost tie-break. The frozen ToolboxMD candidate therefore remains evidence, not the recommended default.

The retained artifacts still expose useful product differences. The eligible deck pair supports a much shorter ToolboxMD activation description with no observed trigger regression, while the packages also show larger activated cores, larger packages, and longer authoring runs. Meeting differences remain diagnostic rather than comparative evidence.

## Why v2 was needed

The first creator benchmark used specialized production-oriented tasks. Downstream prompts named generated skill paths, so it did not test whether natural user language activated the skill. It also lacked a no-skill arm, making it impossible to distinguish creator value from tasks the model could solve unaided. One blind replay was invalidated by identity-bearing Python bytecode.

V2 changed the causal question. It held the model, effort, source material, ordinary workspace, prompt, sandbox, and runner constant, then varied only the creator used to author the target skill. Each generated skill was installed through normal Codex discovery. Positive prompts did not name a skill, `SKILL.md`, or an invocation command. Event traces, rather than model self-report, proved whether the full target skill loaded before output creation.

Each case first ran without a target skill. A case qualified only when the same model could perform the task mechanically but missed at least one critical private workflow convention. This filtered out tasks that needed no skill.

## Daily-use cases

### Meeting notes to follow-ups

The task turned tagged meeting notes into a structured follow-up, an appended CSV tracker, and a QA receipt. Private conventions covered explicit classification tags, owner aliases, `TBD` behavior, preserved source order, exact headings, and deterministic validation.

The no-skill run passed only 2 of 8 critical checks. It wrote plausible files but ignored the private contract. Both generated skills then passed 7 of 8 checks and produced byte-identical output trees.

The shared failure was not diagnostic. Both treatments preserved source terminal periods in action text, while the exact CSV fixture expected the periods to disappear. The contract had not specified punctuation removal. The raw scores remain 7 of 8, but the failure cannot support a creator preference.

### Weekly notes to a status deck

The task turned weekly notes into a fixed five-slide Marp leadership deck plus a JSON validation receipt. Private conventions covered status labels, source identifiers, claim boundaries, unsupported ideas, exact slide order, and receipt structure.

The no-skill run passed 7 of 8 critical checks. It produced a strong deck but used the wrong receipt schema. Both generated skills passed all 8 checks. Their outputs differed only in harmless whitespace and reporting-range phrasing.

Marp Markdown was deliberate. It tested a common presentation workflow without allowing another installed presentation skill to confound the creator comparison.

## Result

| Case | No skill | Built-in | ToolboxMD | Frozen outcome |
|---|---:|---:|---:|---|
| Meeting follow-ups | 2/8 | 7/8, 18,550 runtime tokens | 7/8, 21,609 runtime tokens | Not scored: ToolboxMD authoring trace is ineligible |
| Weekly status deck | 7/8 | 8/8, 30,228 runtime tokens | 8/8, 23,982 runtime tokens | ToolboxMD cost tie-break, low confidence |

All four positive runs loaded the full target `SKILL.md` before writing output. Two aggregate near-miss sessions exposed four generated target skills to related general-advice prompts. None loaded. Those observations remain inspectable, but only the two status-deck pipelines form an eligible creator pair.

The frozen decision rule required ToolboxMD to win both primary cases with no critical regression, or win a deciding reserve. The meeting pair became unavailable after re-audit. The reserve required five more sessions, but only one remained under the 17-session hard limit after a symmetric infrastructure retry. It was not opened.

The operational verdict is inconclusive. The built-in creator remains the current default because the challenger did not clear its promotion gate, not because this experiment proved general built-in superiority.

## Direct creator comparison

### ToolboxMD's demonstrated strength

ToolboxMD produced descriptions that were 29.5% shorter for meeting follow-ups and 39.2% shorter for the status deck. Both positive prompts still triggered, and all tested near misses stayed inactive. Only the 39.2% deck comparison belongs to an eligible paired pipeline; the meeting reduction is diagnostic.

This is useful evidence for a compact activation contract: capability, concrete intents, and close exclusions without duplicating the workflow in always-listed metadata. The eligible sample is too small to claim a general optimization advantage, but compact activation metadata is still the clearest property worth preserving.

### ToolboxMD's demonstrated cost

ToolboxMD's `SKILL.md` files were 11.6% and 14.1% larger. Its full packages were 29.7% and 53.9% larger. It also took longer to author both skills.

The extra files were mainly eval artifacts, focused script tests, and more explicit boundary prose. They did not create a measured downstream quality advantage here. Comparative and repeated eval ownership should move to `toolboxmd-benchmarking-skills`; package-local tests should remain only when a bundled deterministic mechanism justifies them.

All four target skills immediately loaded their single reference. This is retained trace evidence about the packages, though only the deck pair is eligible for creator comparison. Required-on-every-run references therefore belonged to activated context, even though a file-count view might call them progressive disclosure.

### Runtime command portability

Both ToolboxMD cores showed commands such as `python3 scripts/validate_outputs.py` while the normal task current directory was the user's workspace. The downstream agents repaired those commands by using `.agents/skills/<name>/scripts/...`. The examples worked only because the model corrected the package.

The next creator must emit current-directory-independent commands or an explicit skill-directory resolution rule. A validator should warn on bare `python3 scripts/`, `node scripts/`, and `bash scripts/` examples without a preceding directory contract.

### Post-result trace-audit correction

The original event auditor removed parent-relative operands from consideration when their suffix started with a familiar run-local directory name. That could accept a path starting with two parent hops and ending in creator/SKILL.md from the run root even though it resolves outside the run root. It also missed a bare parent operand such as `find ..`.

The corrected auditor permits a parent-relative operand only when the event records an in-root command cwd and resolving the operand from that cwd remains inside the run root. It does not infer cwd from command output or later success. It also rejects literal POSIX and Windows absolute filesystem operands outside the run root, including operands inside shell-wrapper payloads and heredoc code. All 17 retained streams were re-audited without running another model session. ToolboxMD meeting-followups authoring became ineligible because it used `find ..` and parent-relative validator paths while its events did not record cwd. Some validator paths likely ran from the generated skill directory, but the trace cannot prove that boundary, so the comparison is excluded conservatively. One previously discarded built-in authoring stream also became ineligible because `/usr/bin/python3` appeared as a loop operand; this has no effect on the scored comparison.

The package, downstream output, grades, and raw events remain retained as inspectable failure evidence. The correction changes the verdict from mixed to inconclusive but does not change the release action: do not promote ToolboxMD.

### Conditional delivery behavior

The frozen ToolboxMD creator asks every handoff to distinguish validated, tested, committed, and pushed state. In disposable package-only authoring runs, that encouraged unscoped `git status` calls. Two traces listed names from the ancestor worktree. The weekly trace did not expose outside file contents, another treatment, or grader data; the meeting trace is independently ineligible because its parent-relative operands lack a recorded cwd.

Validation and testing should always be reported. Git inspection, commit, and push reporting should be conditional on a Git destination and an explicit repository-delivery request.

## Infrastructure failure and protocol amendment

The first two built-in authoring attempts executed a creator helper that wrote Python bytecode under the protected creator tree. The boundary correctly rejected them. The complete four-run authoring batch was discarded before downstream use, including the two ToolboxMD arms that had not violated the boundary.

Protocol revision 2 disabled bytecode writes, redirected any Python cache under the run-local temporary directory, and repeated all four authoring arms. Cases, prompts, treatments, model, grader, and decision rule did not change. The failed batch remains inspectable and counts toward the hard session limit.

This exposed two harness requirements:

- isolate Python bytecode and Git repository discovery before the first model run;
- give infrastructure repair a small explicit allowance separate from the semantic decision budget.

The pre-run commitment also omitted hashes for the supporting grader and event-audit scripts. Their at-result hashes and outputs are retained, but that is weaker than a pre-run commitment. Future runs must freeze every tool that can affect qualification, eligibility, score, cost, retention, or decision.

## What changes in the product

The next `toolboxmd-creating-skills` candidate should:

1. preserve the compact description pattern and trace-based trigger evaluation;
2. emit current-directory-independent script commands;
3. make comparative eval artifacts opt-in and delegate repeated benchmarking to `toolboxmd-benchmarking-skills`;
4. count always-read references as activated core;
5. make Git delivery checks conditional;
6. enforce a final artifact-budget deletion pass;
7. remain a new frozen candidate instead of mutating the old benchmark snapshot.

No change is made to an active ToolboxMD creator in this ship because the repository has no promoted `skills/toolboxmd-creating-skills` package. The benchmark result defines the next revision rather than silently turning an unpromoted artifact into doctrine.

## What changes in benchmark doctrine

- Run the ordinary task without the target skill before comparing creators.
- Use natural positive prompts and prove full skill loading from the trace.
- Test related near misses without turning every authoring task into a large description campaign.
- Specify every normalization rule behind an exact-text assertion.
- Separate observable utility from one-run cost.
- Repeat a paired case when cost alone decides it before spending the budget on another case.
- Freeze the complete scoring and eligibility toolchain.
- Reject parent-relative reads unless a recorded command cwd proves the resolved path remains inside the run root.
- Preserve invalid attempts and report neutral amendments without mixing them into scores.

These additions are incorporated into [Benchmark integrity for agent skills](/docs/06-testing/benchmark-integrity).

## Limitations

- Each treatment ran once per case, so cost differences are directional.
- Only one daily-use family retains an eligible paired comparison, so no general creator ranking is possible.
- The result covers Codex CLI 0.147.0 and one model-effort configuration only.
- Trigger precision was observed on one positive and one related near miss per generated skill.
- The reserve spreadsheet case was frozen but not executed.
- Supporting grader and event-audit scripts have at-result hashes, not complete pre-run commitment evidence.
- The Codex JSONL schema did not record command cwd for the ineligible meeting authoring trace, so its parent-relative reads cannot be located reliably after the fact.

## Sources

- [Machine-readable v2 evidence](/case-studies/evidence/2026-08-13-toolboxmd-creating-skills-benchmark-v2.json)
- [Benchmark integrity doctrine](/docs/06-testing/benchmark-integrity)
- [Agent Skills evaluation guidance](https://agentskills.io/skill-creation/evaluating-skills)
- [Agent Skills description optimization](https://agentskills.io/skill-creation/optimizing-descriptions)
- [OpenAI skill-building guidance](https://learn.chatgpt.com/docs/build-skills)

Cross-links: [Trigger contracts](/docs/05-authoring/triggers), [Token economics](/docs/04-token-economics), [Mechanism vs decoration](/docs/07-mechanism-vs-decoration), [Update mechanism](/docs/12-update-mechanism).
