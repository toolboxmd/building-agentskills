# Case study: ToolboxMD creating-skills benchmark v2

- **Date:** 2026-08-13
- **Subject:** Codex built-in `skill-creator` versus the frozen `toolboxmd-creating-skills` candidate
- **Decision:** Inconclusive after stricter trace re-audit; no ToolboxMD promotion
- **Configuration:** Codex CLI 0.147.0, `gpt-5.6-sol`, medium reasoning
- **Evidence:** [Condensed machine-readable manifest](/case-studies/evidence/2026-08-13-toolboxmd-creating-skills-benchmark-v2.json)

The corrected v2 benchmark contains no eligible no-skill qualification and no eligible paired creator comparison. All 15 retained command-bearing event streams lack recorded trusted evidence for a sanitized environment, filesystem read and write confinement, and syscall-level network enforcement. This includes all eight scored streams, both qualification streams, the infrastructure preflight, and four discarded authoring streams. Only two zero-command near-miss streams remain eligible for the narrow no-trigger observation. The scores, positive activation observations, package differences, and costs are diagnostic only. The frozen ToolboxMD candidate remains evidence, not the recommended default.

The retained artifacts still expose hypotheses worth retesting. ToolboxMD produced shorter activation descriptions, larger activated cores, larger packages, and longer authoring runs. None of those differences is eligible comparative evidence in this benchmark.

## Why v2 was needed

The first creator benchmark used specialized production-oriented tasks. Downstream prompts named generated skill paths, so it did not test whether natural user language activated the skill. It also lacked a no-skill arm, making it impossible to distinguish creator value from tasks the model could solve unaided. One blind replay was invalidated by identity-bearing Python bytecode.

V2 changed the causal question. It held the model, effort, source material, ordinary workspace, prompt, sandbox, and runner constant, then varied only the creator used to author the target skill. Each generated skill was installed through normal Codex discovery. Positive prompts did not name a skill, `SKILL.md`, or an invocation command. Event traces, rather than model self-report, proved whether the full target skill loaded before output creation.

Each case first ran without a target skill. A case was intended to qualify only when an eligible no-skill run could perform the task mechanically but missed at least one critical private workflow convention. Both retained no-skill runs show such failures, but neither is eligible after the isolation-evidence correction. Their grades are diagnostic and neither case is formally qualified.

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
| Meeting follow-ups | 2/8, diagnostic and ineligible | 7/8, 18,550 runtime tokens | 7/8, 21,609 runtime tokens | Not scored: qualification and both pipelines are ineligible |
| Weekly status deck | 7/8, diagnostic and ineligible | 8/8, 30,228 runtime tokens | 8/8, 23,982 runtime tokens | Not scored: qualification and both pipelines are ineligible |

All four positive runs loaded the full target `SKILL.md` before writing output, but all four positive streams are ineligible. Two aggregate near-miss sessions exposed four generated target skills to related general-advice prompts and recorded no command execution or target load. Those two streams remain eligible only for that narrow no-trigger observation. No positive activation comparison or paired creator comparison remains eligible.

The frozen decision rule required ToolboxMD to win both primary cases with no critical regression, or win a deciding reserve. Both primary pairs are unavailable after re-audit. The reserve required five more sessions, but only one remained under the 17-session hard limit after a symmetric infrastructure retry. It was not opened.

The operational verdict is inconclusive. The built-in creator remains the current default because the challenger did not clear its promotion gate, not because this experiment proved general built-in superiority.

## Diagnostic creator measurements

### Compact-description hypothesis

ToolboxMD produced descriptions that were 29.5% shorter for meeting follow-ups and 39.2% shorter for the status deck. All four positive traces loaded their target, and all tested near misses stayed inactive. No paired pipeline remains eligible, so these measurements motivate a compact-description hypothesis but do not demonstrate a ToolboxMD advantage.

The next candidate should preserve the compact activation pattern, capability, concrete intents, and close exclusions without duplicating the workflow in always-listed metadata, then retest it in a clean benchmark. This run cannot establish a general optimization advantage.

### Package and authoring measurements

ToolboxMD's `SKILL.md` files were 11.6% and 14.1% larger. Its full packages were 29.7% and 53.9% larger. It also took longer to author both skills.

The extra files were mainly eval artifacts, focused script tests, and more explicit boundary prose. The raw scores show no downstream quality difference, but the ineligible pipelines prevent an attributable comparison. Comparative and repeated eval ownership should move to `toolboxmd-benchmarking-skills`; package-local tests should remain only when a bundled deterministic mechanism justifies them.

All four target skills immediately loaded their single reference. This is retained diagnostic trace evidence about the packages, not an eligible creator comparison. Required-on-every-run references still belonged to activated context, even though a file-count view might call them progressive disclosure.

### Runtime command portability

Both ToolboxMD cores showed commands such as `python3 scripts/validate_outputs.py` while the normal task current directory was the user's workspace. The downstream agents repaired those commands by using `.agents/skills/<name>/scripts/...`. The examples worked only because the model corrected the package.

The next creator must emit current-directory-independent commands or an explicit skill-directory resolution rule. A validator should warn on bare `python3 scripts/`, `node scripts/`, and `bash scripts/` examples without a preceding directory contract.

### Post-result trace-audit correction

The original event auditor removed parent-relative operands from consideration when their suffix started with a familiar run-local directory name. That could accept a path starting with two parent hops and ending in creator/SKILL.md from the run root even though it resolves outside the run root. It also missed a bare parent operand such as `find ..`.

The corrected auditor permits a parent-relative operand only when the event records an in-root command cwd and resolving the operand from that cwd remains inside the run root. It does not infer cwd from command output or later success. It also rejects literal POSIX and Windows absolute filesystem operands outside the run root, including operands inside shell-wrapper payloads and heredoc code.

The final correction uses a smaller evidence-honest invariant. Any `command_execution` event requires recorded trusted evidence for a sanitized environment, filesystem read and write confinement, and syscall-level network enforcement. Historical Codex JSONL contains no such evidence, so every command-bearing stream is ineligible. A started or incomplete command event also activates the rule. Detailed findings for Git, parent traversal, absolute paths, wrappers, and interpreter payloads remain useful diagnostic reasons, but parser completeness is not the eligibility trust boundary.

All 17 retained streams were re-audited without running another model session. Fifteen are ineligible: all eight scored streams, both no-skill qualification streams, the infrastructure preflight, and four discarded authoring streams. The two zero-command near-miss streams remain eligible for the narrow observation that no target skill load was recorded. No case qualifies or retains an eligible pair. The packages, downstream outputs, grades, and raw events remain retained as inspectable failure evidence. The verdict stays inconclusive and the release action remains: do not promote ToolboxMD.

### Conditional delivery behavior

The frozen ToolboxMD creator asks every handoff to distinguish validated, tested, committed, and pushed state. In disposable package-only authoring runs, that encouraged unscoped `git status` calls. Built-in and downstream streams also used scoped Git commands. Under the frozen read-isolation rule, all of these commands are ineligible because the traces proved neither in-root repository metadata nor isolation from system, global, and included Git configuration.

Validation and testing should always be reported. Git inspection, commit, and push reporting should be conditional on a Git destination and an explicit repository-delivery request.

## Infrastructure failure and protocol amendment

The first two built-in authoring attempts executed a creator helper that wrote Python bytecode under the protected creator tree. The boundary correctly rejected them. The complete four-run authoring batch was discarded before downstream use, including the two ToolboxMD arms that had not violated the boundary.

Protocol revision 2 disabled bytecode writes, redirected any Python cache under the run-local temporary directory, and repeated all four authoring arms. Cases, prompts, treatments, model, grader, and decision rule did not change. The failed batch remains inspectable and counts toward the hard session limit.

This exposed three harness requirements:

- isolate Python bytecode;
- provide a separate, independently verifiable evidence channel for environment sanitization plus filesystem and network enforcement before any command-bearing run can qualify;
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
- Require independently verifiable environment, filesystem, and network isolation evidence for every command-bearing stream.
- Keep detailed command heuristics as diagnostic reasons, not as a claim that command-text parsing proves strict isolation.
- Reject Git execution unless a future trust-bearing isolation channel also covers repository and configuration reads.
- Preserve invalid attempts and report neutral amendments without mixing them into scores.

These additions are incorporated into [Benchmark integrity for agent skills](/docs/06-testing/benchmark-integrity).

## Limitations

- Each treatment ran once per case, and all cost differences are diagnostic because no paired comparison remains eligible.
- Zero daily-use families retain an eligible paired comparison, so no creator or cost ranking is possible.
- The result covers Codex CLI 0.147.0 and one model-effort configuration only.
- Positive triggering is diagnostic because every positive stream is ineligible. The two zero-command near-miss streams support only the narrow no-trigger observation.
- The reserve spreadsheet case was frozen but not executed.
- Supporting grader and event-audit scripts have at-result hashes, not complete pre-run commitment evidence.
- The Codex JSONL schema did not record a sanitized environment or independently verifiable filesystem and syscall-level network enforcement. Command cwd was also absent for one meeting authoring trace.

## Sources

- [Machine-readable v2 evidence](/case-studies/evidence/2026-08-13-toolboxmd-creating-skills-benchmark-v2.json)
- [Benchmark integrity doctrine](/docs/06-testing/benchmark-integrity)
- [Agent Skills evaluation guidance](https://agentskills.io/skill-creation/evaluating-skills)
- [Agent Skills description optimization](https://agentskills.io/skill-creation/optimizing-descriptions)
- [OpenAI skill-building guidance](https://learn.chatgpt.com/docs/build-skills)

Cross-links: [Trigger contracts](/docs/05-authoring/triggers), [Token economics](/docs/04-token-economics), [Mechanism vs decoration](/docs/07-mechanism-vs-decoration), [Update mechanism](/docs/12-update-mechanism).
