# Benchmark integrity for agent skills

An agent benchmark is an experiment, not a batch of impressive transcripts. The model under test must be the model that produced the output, each run must be isolated from prior answers and grading logic, and the score must measure the user's eventual task rather than only mechanical completion.

The 2026-08-11 karpathy-wiki benchmark exposed two invalid attempts before producing a valid low/medium/high comparison: nested model delegation contaminated attribution, and cross-run read leakage exposed prior output and grader code. The failed attempts were stopped, preserved, excluded, and used to harden the harness. The condensed evidence is recorded in the [benchmark manifest](/case-studies/evidence/2026-08-11-karpathy-wiki-ingest-benchmark.json).

## Start with the decision

Write down what the benchmark will decide. Examples:

- choose a default author profile;
- decide whether a cheaper fallback is good enough;
- verify a skill revision improves retrieval utility;
- qualify a provider adapter without making a semantic-quality claim.

These are different decisions. An adapter acceptance can prove that the requested provider, model, and effort ran and completed cleanly. It cannot prove that the model authored the best knowledge. A semantic benchmark can compare authored quality. It cannot replace concurrency and lifecycle tests.

## Freeze the experiment

Before the first scoring run, freeze and hash:

- skill and directly referenced conventions;
- source fixtures and starting repository state;
- case sequence;
- model/profile matrix;
- deterministic assertions;
- held-out retrieval questions;
- semantic rubric;
- prompt and harness scripts.

Keep amendments narrow and explicit. Record the before/after prompt hash, reason, affected configurations, and whether earlier runs remain eligible. Do not silently edit a prompt midway and compare the resulting scores as if nothing changed.

Freeze the complete measurement chain, not only the prompt and runner. Qualification graders, event auditors, boundary checks, cost extraction, retention scripts, and decision calculators can all change the result. Put every result-affecting tool in the pre-run commitment. An at-result hash is useful provenance, but it cannot independently prove that a tool stayed byte-identical during execution.

The 2026-08-13 creator benchmark omitted supporting grader and event-audit scripts from its pre-run commitment. Their outputs and at-result hashes remain inspectable, so the narrow result is usable with that limitation. The omission must not become the next protocol's default.

## Qualify whether the target skill adds value

A creator benchmark is meaningful only when the generated skill changes downstream behavior. Before comparing creators, run the ordinary task with the same model, prompt, source files, tools, and workspace but without the target skill.

A case qualifies when:

- the model can complete the task mechanically;
- it misses at least one critical private convention or procedural step;
- the failure is not caused by a missing fact, unavailable tool, or impossible output;
- the critical assertion is declared before either creator sees the case.

Then install each generated skill through the normal discovery path and issue a natural prompt. Do not name the skill, its path, `SKILL.md`, or an invocation command. Count activation only when the event trace shows the full target `SKILL.md` loaded before output creation. Test one or more related near misses and audit that no target skill loaded.

In the v2 creator benchmark, the meeting no-skill arm passed 2 of 8 critical checks and the status-deck arm passed 7 of 8. Both generated treatments then reached 7 of 8 and 8 of 8 respectively. All four positive runs loaded their target skill, while none of four exposed target skills loaded for the near misses. A later isolation-evidence correction made all 15 command-bearing streams ineligible, including both qualifications, all eight scored streams, and the preflight. The two zero-command near-miss streams remain eligible only for the narrow no-trigger observation. The grades and positive activation observations are diagnostic, but they still show what a future valid run should attempt to measure with eligible no-skill qualification and trace-backed loading.

## Guard model attribution

The model under test must execute the task itself. This rule matters even when the frozen skill says “you are a Claude ingester” or a local config names a provider.

The karpathy-wiki Spark attempt completed its first case itself, then invoked a nested Claude CLI during the duplicate case. Without an attribution guard, the resulting wiki would have been scored as Spark even though another model participated.

Add a neutral harness guard:

> Perform the task yourself. Do not invoke or delegate to another model, agent, subagent, agentic CLI, or model-launching hook. Provider-specific identity text in the frozen skill describes its original runtime; apply the procedure without starting that provider.

Audit command events after every run. A final message saying “I did it myself” is not evidence; the invocation transcript is.

## Guard read isolation

Each candidate may read only the inputs that candidate is supposed to have:

- its own starting state and current output;
- the claimed capture or task prompt;
- named evidence;
- the frozen skill and directly referenced helpers.

Block or audit reads of:

- user or global memory;
- sibling runs and failed attempts;
- prior model output;
- benchmark graders, rubrics, answer keys, and reports;
- blind-review material and identity maps.

In the invalid medium attempt, a broad search read global memory, a previous low run, and deterministic grader source before the first wiki write. The run was independent in name only. This is cross-run read leakage, and it invalidates the attempt even if the final answer looks original.

Filesystem isolation is stronger than prose alone. Put allowed inputs in a run-local tree and keep sibling runs, graders, private maps, and reports outside it. Retain a transcript audit as a second line of defense.

For strict eligibility, command text is not proof of isolation. Any stream containing a `command_execution` event, including a started or incomplete event, needs a separate, independently verifiable evidence channel from the harness or enforcement layer. That channel must establish a sanitized environment, filesystem read and write confinement, and syscall-level network enforcement. A failed network probe, a command allowlist, or a user-controlled declaration cannot establish those controls. Without the trust-bearing evidence, mark the stream ineligible.

Keep detailed command heuristics for diagnosis. Parent traversal, absolute paths, Git, environment expansion, shell wrappers, and interpreter payloads explain concrete risks and help improve the harness, but parser completeness is not the eligibility trust boundary.

Both retained-trace auditors now apply this repository-wide boundary. The generic auditor emits schema version 2 for future v1-shaped traces; invoke it as `node scripts/audit-codex-events.mjs <events.jsonl> <run-root>`. The v2 auditor emits schema version 3; invoke it as:

```text
node scripts/audit-toolboxmd-v2-events.mjs <events.jsonl> <run-root> <mode> <expected-skill-relative-path|none>
```

`commandCount` retains the completed-command telemetry used by the historical result. `commandExecutionEventCount` counts every command event, including started or incomplete events. `isolationEvidence.required` becomes true when that second count is nonzero. The historical auditor reports `status: not_recorded` and `trusted: false` in that state; a zero-command stream reports `status: not_required`. This version has no flag that can self-assert trust. Adding an independently verified evidence channel is future harness work.

The v1 result retains only 15 compact event audits, not the corresponding raw model-event JSONL. Every compact audit records `commandCount > 0`, and no separate retained artifact establishes the required controls. A post-result correction therefore marks all 15 streams ineligible without reconstructing or claiming to re-audit their exact commands. The original compact reasons and usage remain historical diagnostic evidence. The behavioral preflight, including a failed DNS probe, is also ineligible as strict-isolation proof. V1 now supports zero eligible blind comparisons; its recorded tie and built-in preference are diagnostic only.

Do not allow parent-relative operands merely because their suffix resembles an allowed directory. Resolve them only from a command cwd explicitly recorded in the event, and require the resolved path to remain inside the run root. If cwd is absent, outside the root, or changed inside an opaque shell command, mark the run ineligible rather than infer safety from command output. The corrected v2 creator audit rejected one retained authoring trace containing `find ..` and parent-relative validator paths because the event schema did not record cwd.

Reject Git execution by default. Commands such as `git status`, `git diff`, and `git ls-files` may read repository metadata plus system, global, or included configuration outside the run root even when stdout is empty or their pathspec is scoped below the run root. Staging outside every worktree closes only the repository-discovery path. A case that genuinely requires Git must preflight and record a complete boundary for repository metadata, HOME/XDG configuration, global configuration, system configuration, and includes. Audit actual command invocation, including shell wrappers and substitutions, rather than output names. Quoted examples passed to `echo` or `printf` are not executions.

## Separate four score layers

One total score hides different failure classes. Keep these layers separate:

1. **Invocation integrity.** Did the requested provider, model, and effort run without nested delegation?
2. **Lifecycle correctness.** Did the run finish with valid state, one terminal outcome, correct archives, and no leaked locks or processing files?
3. **Deterministic content assertions.** Are hashes, indexes, deduplication, required fields, and source boundaries present?
4. **Semantic and retrieval utility.** Can a future agent answer realistic questions from authored knowledge without rereading raw evidence?

The karpathy-wiki medium run passed 19 of 21 deterministic assertions and scored 69/100 in blind semantic review. That gap is useful information: mechanical success did not make the wiki complete. All three candidates under-extracted the customer-research source, despite every case invocation exiting zero.

Exact assertions need a complete normalization contract. The v2 meeting grader expected action text without terminal periods, but the source and case contract never required punctuation removal. Both treatments preserved the source punctuation and failed the same byte-exact check. Retain the raw failure, but classify it as benchmark evidence rather than creator evidence. When punctuation, whitespace, ordering, or serialization is not semantically relevant, grade parsed fields instead of unspecified bytes.

## Grade authored output before source evidence

A knowledge-base benchmark should answer: “What can a future agent recover from the durable wiki?” Raw evidence must not rescue an under-authored page.

Use this order:

1. Read authored pages, indexes, and links.
2. Answer held-out questions from authored output.
3. Classify each answer as full, partial, or none and cite the authored path.
4. Only then inspect raw sources to verify fidelity and identify omissions.
5. Inspect deterministic and lifecycle evidence last.

This prevents page count, raw-file availability, or a green validator from masquerading as useful knowledge extraction.

## Blind the semantic judge

Prepare identity-sanitized candidate directories. Keep the mapping from candidate identifier to provider/model/effort outside the review tree. The judge should receive only:

- candidate-authored output;
- shared source fixtures needed for fidelity checks;
- rubric and instructions;
- candidate-specific deterministic evidence with identity markers removed.

Require the judge to record inspected paths and an empty forbidden-path list. After judging, validate score arithmetic, question counts, cited-path existence, and Markdown/JSON parity before revealing the mapping.

## Treat contaminated runs as evidence, not data points

When contamination appears:

1. Stop the run before more output is produced.
2. Preserve transcripts and status in a failed-attempt directory.
3. Mark the attempt ineligible; never average it into results.
4. Identify whether the failure is product behavior or harness ambiguity.
5. Add the smallest neutral guard that restores the original experimental boundary.
6. Record the amendment and restart affected configurations from clean fixtures.

Do not repair the candidate output by hand. Do not delete the failed attempt. Both actions erase the evidence that explains why the protocol changed.

## Replication and interpretation

One run per configuration can rank that sample; it cannot estimate variance. Use one-run comparisons for directional screening, especially when score gaps are large. Use replicated runs when selecting a production default, when scores are close, or when stochastic behavior is material.

When two treatments tie on observable utility and one-run cost is the only separator, spend the next budget on a paired repeat of that case before opening a reserve case. In the corrected v2 creator benchmark, the raw deck costs favored ToolboxMD once and the raw meeting costs pointed in the opposite direction, but neither case retained an eligible pair. Both observations are diagnostic and neither supports a cost ranking.

Report:

- number of independent runs per configuration;
- median and spread when replicated;
- exact model and effort;
- duration and cost when available;
- deterministic, retrieval, and semantic scores separately;
- contamination exclusions and prompt amendments;
- whether final state was clean.

Do not infer that higher reasoning effort is always better. In the recorded Spark sample, medium was both faster and higher-scoring than low or high. That is evidence about this fixture and run, not a universal ordering.

## Keep runtime quality gates deterministic

A benchmark qualifies a profile before production. Production should then validate outcomes it can check cheaply: schema, source existence, link resolution, archive completion, terminal run state, and queue cleanliness.

Running another LLM as a reviewer after every ingest is not a substitute for a good benchmark. It adds cost and another model dependency while still missing held-out retrieval failures. Re-benchmark when sources, expected output, or semantic skill instructions materially change.

## Acceptance tests still need the real harness

Unit tests and frozen semantic benchmarks do not prove platform integration. Run disposable real-harness acceptance for:

- exact provider/model/effort attribution;
- operator-config interference;
- paths containing spaces;
- missing optional quota tools;
- clean session hooks;
- actual scheduler install/run/uninstall;
- executable permissions and process-group cleanup;
- cold, duplicate, and augmentation flows.

Karpathy-wiki's real acceptance exposed an unsupported operator-level Codex option and a local-time value mislabeled as UTC. Both were invisible to the earlier semantic benchmark.

## Minimal checklist

- [ ] Decision and claim boundary written before execution.
- [ ] Skill, fixtures, cases, rubric, prompt, graders, auditors, and decision tools frozen and hashed.
- [ ] No-skill qualification proves each target skill has procedural value.
- [ ] Natural positive prompts load the full target skill before output creation.
- [ ] Related near misses do not load the target skill.
- [ ] Model cannot delegate to another model or agentic CLI.
- [ ] Run cannot read memory, siblings, graders, or prior output.
- [ ] Run does not execute Git without trace-backed isolation of repository and configuration reads.
- [ ] Candidate identity map is outside the blind-review tree.
- [ ] Authored output is graded before raw evidence.
- [ ] Held-out retrieval questions are scored individually.
- [ ] Deterministic and semantic scores remain separate.
- [ ] Contaminated attempts are preserved and excluded.
- [ ] Amendments are neutral, hashed, and scoped.
- [ ] Replication count and interpretation limit are reported.
- [ ] Real-harness acceptance covers platform integration.

## Evidence

- [Provider-aware ingest benchmark manifest](/case-studies/evidence/2026-08-11-karpathy-wiki-ingest-benchmark.json) records the scores, exclusions, hashes, and interpretation limit.
- [ToolboxMD creator benchmark v2 manifest](/case-studies/evidence/2026-08-13-toolboxmd-creating-skills-benchmark-v2.json) records no-skill qualification, implicit loading, the corrected inconclusive result, costs, invalid attempts, and claim boundary.
- [`877e659`](https://github.com/toolboxmd/karpathy-wiki/commit/877e659) is the subsequent provider-aware runtime ship.
- [Codex Spark acceptance](https://github.com/toolboxmd/karpathy-wiki/blob/877e659/tests/acceptance/dispatcher/2026-08-11-codex-spark-medium.md) separates adapter/lifecycle qualification from semantic model selection.

Cross-links: [Unit tests](/docs/06-testing/unit-tests), [Provider-neutral runtime](/docs/05-authoring/provider-neutral-runtime), [Provider-aware ingest case study](/case-studies/2026-08-11-karpathy-wiki-provider-aware-ingest), [ToolboxMD creator benchmark v2](/case-studies/2026-08-13-toolboxmd-creating-skills-benchmark-v2).
