---
title: ToolboxMD skill suite and first creator benchmark
status: EXECUTED, BENCHMARK FAILED
date: 2026-08-12
owner: lukemaj
scope: building-agentskills general repository
execution_authorization: user approved conditional tranche 1 execution on 2026-08-12
execution_result: benchmarks/toolboxmd-creating-skills/v1/results/2026-08-12/manifest.json
related:
  - docs/03-three-questions.md
  - docs/06-testing/benchmark-integrity.md
  - docs/12-update-mechanism.md
  - docs/superpowers/plans/2026-08-12-continuous-learning-handoff.md
---

# ToolboxMD skill suite and first creator benchmark

## Execution result

Tranche 1 reached its benchmark gate on 2026-08-12 and stopped. The frozen creator candidate passed all three mechanical and deterministic cases but recorded no valid blind wins. It was retained as benchmark evidence and removed from the active skill path. The updater, benchmark skill, watcher, and automation remain unimplemented.

## Outcome

Turn this repository's evidence-backed authoring doctrine into three clearly separated ToolboxMD skills:

1. `toolboxmd-creating-skills` creates a new skill.
2. `toolboxmd-updating-skills` updates an existing skill without silently changing its contract.
3. `toolboxmd-benchmarking-skills` compares two skill versions or two authoring approaches.

The first vertical tranche ships only `toolboxmd-creating-skills` and a small directional benchmark. The benchmark asks whether it creates more useful skills than the current built-in `skill-creator` under the same model, prompt, fixtures, and execution constraints for three declared skill archetypes.

The updater, reusable benchmark skill, source watcher, scheduler, and automatic draft generation remain later tranches. A passing creator benchmark is the gate for proceeding to them.

## Why three skills

Creating, updating, and benchmarking have different inputs, risks, and stopping conditions.

- Creation begins with an empty skill contract and must decide whether a skill is the right primitive.
- Updating begins with a shipped contract and must preserve behavior unless a change is explicit and evidenced.
- Benchmarking begins with two frozen candidates and must protect attribution, isolation, and claim boundaries.

Combining them would load irrelevant procedure on most invocations and make triggering less precise. The three skills share doctrine through this repository, but they do not share one oversized `SKILL.md`.

## Source hierarchy

The suite uses four source classes. Higher classes can establish doctrine. Lower classes can suggest candidates only.

1. **Normative format and authoring guidance**
   - Agent Skills specification and skill-creation documentation at `agentskills.io`.
   - Frozen repository snapshot: `agentskills/agentskills@69ef37e9424c0a7ea9dd2293b559e43ec8176379`.
2. **Harness-specific primary documentation and shipped examples**
   - OpenAI documentation for Codex skills and the public `openai/plugins` repository.
   - Frozen OpenAI examples snapshot: `openai/plugins@11c74d6ba24d3a6d48f54a194cd00ef3beea18f9`.
   - Anthropic documentation and the public `anthropics/skills` repository.
   - Frozen Anthropic examples snapshot: `anthropics/skills@f17010c9bb483898c1d9c9f42dde2b3a98889434`.
3. **Process conventions with shipped behavior**
   - Superpowers authoring and pressure-test practices.
   - Frozen snapshot: `obra/superpowers@44c9b2d6e889982ac18c27d05a19fefe335194e1`.
   - This repository's cited case studies and accepted doctrine.
4. **Discovery-only catalogs and community examples**
   - `agent-skills.md` and similar directories may identify examples.
   - A catalog entry cannot become doctrine until its original repository, commit, evidence, and claim boundary are inspected.

Source snapshots are discovery inputs, not automatic doctrine updates. New external guidance can create a candidate lesson. It cannot silently rewrite the docs or the skills.

The older `openai/skills` repository is deprecated and is not the current OpenAI example corpus for this design. The benchmark baseline is the actually installed system skill, not a public repository approximation.

## Product and doctrine delivery model

The Mintlify documentation is the canonical human-readable doctrine. `toolboxmd-creating-skills` is a self-contained operational projection of that doctrine for agents.

- The creator contains the minimum procedure and bundled references needed to work without network access or a checkout of this repository.
- It cites canonical docs and source snapshots for provenance, but it does not fetch the live website during ordinary execution.
- It does not duplicate the full documentation corpus. Detailed explanation remains on the site; the skill carries decisions, gates, templates, and operational gotchas.
- A future doctrine change can propose a creator update, but the update remains reviewed and benchmarked. Website publication does not mutate an installed skill automatically.

The current `skills/building-agentskills/` thin loader remains available beside the new creator. Tranche 1 does not replace, deprecate, or rename it. That public migration requires its own compatibility decision and benchmark evidence.

The skill name supplies the ToolboxMD identity in Codex. The existing Claude plugin is still named `building-agentskills`, so its eventual Claude invocation would be namespaced as `building-agentskills:toolboxmd-creating-skills`. Renaming the plugin or moving the suite into a separate `toolboxmd` marketplace package is a later distribution decision. It does not enter the quality benchmark.

The current Claude plugin manifest also fails `claude plugin validate .` because `author` is a string where Claude Code 2.1.220 expects an object. This pre-existing distribution failure is recorded, not repaired in tranche 1. It blocks a claim that Claude plugin distribution works. It does not block explicit-path Codex benchmarking.

## Tranche 1 scope

### Included

- A new cross-platform-safe skill at `skills/toolboxmd-creating-skills/`.
- Optional Codex UI metadata in `agents/openai.yaml`.
- A frozen three-case benchmark protocol and synthetic fixtures.
- The exact current built-in `skill-creator` as the baseline treatment.
- An Apache-2.0 licensed, inspectable snapshot of that baseline treatment.
- Mechanical validation of generated skill packages.
- One downstream use check for each generated skill.
- Blind A/B semantic grading and a machine-readable evidence manifest.
- A project-wiki update for the durable architecture and benchmark decision.

### Excluded

- Implementing `toolboxmd-updating-skills`.
- Implementing `toolboxmd-benchmarking-skills` as a reusable skill.
- Replacing or deleting `skills/building-agentskills/`.
- Renaming the existing Claude plugin or repairing its manifest.
- Updating the continuous-learning watcher design.
- Adding `last_seen`, `last_absorbed`, schedules, GitHub Actions, pull requests, or auto-merge.
- Running a 20-query trigger optimization suite.
- Repeated trials for variance unless the directional result is ambiguous.
- Claiming cross-provider superiority from a single Codex run.

## Creator contract

### Invocation

`toolboxmd-creating-skills` is both explicitly invocable and eligible for description-based activation. Its description names creation signals and excludes updates, audits, and comparative benchmarks.

The portable frontmatter contains only the Agent Skills fields required by the cross-platform contract. Provider-specific presentation metadata stays in sidecars.

### Workflow

The skill guides an agent through these gates:

1. **Choose the primitive.** Decide whether the request belongs in a skill, project instructions, a hook, a command, a deterministic script, an MCP server, or a plugin. Do not create a skill when another primitive owns the requirement more reliably.
2. **Capture real use.** Establish concrete trigger prompts, near-misses, expected outputs, required inputs, and failure evidence. Prefer real artifacts and shipped behavior over generic advice.
3. **Answer the three questions.** Record who invokes, what fires on each invariant, and the token budget.
4. **Plan the package.** Keep essential procedure in `SKILL.md`; add `references/`, `scripts/`, `assets/`, and `evals/` only when the examples justify them.
5. **Draft the smallest coherent skill.** Provide defaults, explicit inputs and outputs, conditional reference loading, and concrete gotchas. Do not include process-history files or duplicate documentation.
6. **Validate mechanics.** Validate frontmatter, name, directory shape, description length, referenced paths, scripts, and any deterministic output contract.
7. **Prepare proportionate evidence.** For a non-trivial skill, create two or three realistic eval prompts and run at least one downstream smoke check. Comparative benchmarking belongs to `toolboxmd-benchmarking-skills`, not to the creator.
8. **Report state separately.** State what was validated, tested, committed, and pushed.

### Separation from the future skills

- If the target skill already exists and the requested work changes it, hand off to `toolboxmd-updating-skills` when available.
- If the user asks whether one version is better, hand off to `toolboxmd-benchmarking-skills` when available.
- Until those skills ship, explain the boundary and use a narrow manual workflow only when the user explicitly requests it.

## First benchmark decision

The benchmark decides one question:

> Under one frozen Codex configuration and three precommitted skill archetypes instantiated as held-out authoring briefs, does `toolboxmd-creating-skills` produce skill packages whose downstream use is clearly better than packages produced with the frozen built-in `skill-creator`?

It does not decide:

- which model is universally best for skill authoring;
- whether the candidate triggers perfectly across all phrasings;
- whether the result generalizes to Claude Code, Grok, Gemini, or other harnesses;
- whether the future updater and benchmarker are good;
- whether a watcher may update doctrine automatically.

## Frozen treatments

### Baseline

- Label before blinding: `builtin`.
- Source: current system `skill-creator` discovered by Codex on 2026-08-12.
- `SKILL.md` SHA-256: `da44c88f6b3845a8fa8c60792ec9a722110a55a9793c279757b48fefb11f819c`.
- Whole-package manifest SHA-256: `473b9dd5ff3df1d352b499d83e00864290bd2874ac3f9243e33f09ab7e9e835c`.
- Size at freeze: 416 lines, 22,047 bytes.
- The Apache-2.0 licensed package is copied unchanged into the tracked benchmark baseline directory with its license, per-file manifest, installed-product provenance, and aggregate hash.
- The tracked snapshot is copied into each run-local workspace. The evidence manifest records its relative source path, hash, and observed metadata.

### Candidate

- Label before blinding: `toolboxmd`.
- Source: the exact tracked `skills/toolboxmd-creating-skills/` tree after implementation.
- Freeze: hash every file in the candidate tree before the first run.
- No candidate edit is allowed after the first run unless the entire affected comparison is marked as a new iteration.

### Harness

- Codex CLI version at design time: `0.147.0`.
- Model: `gpt-5.6-sol`.
- Reasoning effort: `medium`, selected to bound the first benchmark's cost.
- Runs use ephemeral sessions, ignored user configuration, ignored project rules, a `workspace-write` sandbox, and separate run roots. An outbound request preflight must fail before scoring because Codex 0.147.0 JSONL does not expose the effective network-policy field.
- Each run uses a temporary task-specific `CODEX_HOME` with linked authentication and an explicit `skills.config` deny-list for all discovered system and user skills.
- The assigned creator is copied into the run root and read by exact path. It is not selected through implicit skill discovery.
- Each under-test agent receives an attribution guard forbidding model, subagent, or agentic-CLI delegation.
- The evidence manifest records the actual model and CLI metadata observed in run events.

The harness preflight on 2026-08-12 first showed two visible skills named `skill-creator`, then showed `NONE` after the task-specific home and deny-list were applied. This establishes the one-creator activation boundary for Codex 0.147.0. A final task-specific-home preflight returned `SKILLS: NONE`; its only outbound `curl` attempt failed DNS resolution and returned exit 6. The behavioral network check is retained because the JSONL event stream did not expose an effective network-policy field. The benchmark still has prose-backed filesystem read isolation plus separate run roots, not a proven operating-system read jail. That limitation is recorded. Any observed sibling, memory, grader, or repository read invalidates the run.

## Precommitted families and held-out instances

The case-family contracts, score rubric, critical failures, output shapes, harness settings, and acceptance rule are frozen before candidate implementation. They define the scope of the claim, so this is not a claim of general superiority across arbitrary skill types. The exact prompts and synthetic instances remain hidden from the candidate author.

1. **Reference-heavy incident triage.** Create a skill from a synthetic webhook runbook and API excerpt. The downstream task asks the generated skill to diagnose a new failure payload.
2. **Deterministic data workflow.** Create a skill for sanitizing a synthetic customer-export CSV while preserving the input and emitting an audit record. The downstream task uses a held-out malformed CSV.
3. **Evidence-gated discipline.** Create a skill for drafting release notes from shipped commits without promoting plans or unsupported claims. The downstream task contains a mixed bundle of shipped commits, plans, and rejected work.

These families are inspired by official reference, workflow, and discipline patterns. Their domains and fixtures are not copied from upstream example skills.

The candidate is authored by a fresh-context agent that may read the creator contract and authoritative doctrine sources, but may not read the benchmark contracts, rubric, case-family section, or benchmark outputs. The orchestrator limits its pre-freeze candidate review to the general creator contract, source fidelity, mechanics, and package validity. It does not revise the candidate in response to benchmark-specific criteria.

After the candidate tree is frozen, a different independent fresh-context agent generates the exact authoring prompts, downstream prompts, and fixtures from the precommitted family contracts. That agent may not inspect either creator or any candidate output. Its file reads are audited. The exact cases are hashed before either treatment sees them and cannot change between arms. This keeps the exact instances held out while acknowledging that the public comparison covers three declared archetypes.

## Run shape

For each case:

1. Create two independent run roots from the same frozen case fixture.
2. Copy only the assigned creator treatment and case inputs into each root.
3. Run both authoring arms from clean ephemeral sessions.
4. Validate the produced package mechanically.
5. Freeze and hash the produced package.
6. Run one fresh downstream task with each generated skill.
7. Copy byte-identical authored packages and downstream outputs under neutral `A` and `B` parent directories. Do not redact or rewrite file contents.
8. Grade deterministic assertions first, then conduct one blind pairwise semantic review.
9. Preserve failures and invalid attempts. Do not repair generated packages by hand.

The initial run count is six authoring runs, six downstream-use runs, and one blind judging run. There are no repetitions. If exactly one case is ambiguous, repeat only that case as a new recorded iteration.

Before judging, a deterministic scan checks review copies for creator names, treatment labels, source paths, and identity-map content. The scan may reject a pair, but it may not alter semantic content. If neutral parent-directory renaming is insufficient to blind a pair, preserve the originals and mark that pair invalid rather than redacting it.

## Score layers

Keep separate results for:

1. **Invocation integrity.** Correct model, no nested delegation, no observed forbidden reads.
2. **Package validity.** Valid frontmatter, matching name and directory, resolved references, executable scripts where required, and no extraneous files.
3. **Authoring quality.** Correct primitive, coherent scope, trigger boundaries, progressive disclosure, sensible defaults, grounded details, and proportionate validation.
4. **Downstream utility.** Whether a fresh agent using the generated skill completes the held-out task accurately and leaves the required artifacts.
5. **Cost metadata.** Duration and token usage when exposed by the harness. Missing telemetry is reported as missing, not estimated.

## Acceptance rule

Tranche 1 passes when all of the following hold:

- The candidate package itself validates.
- All three candidate-generated packages pass their critical mechanical contracts.
- `toolboxmd` wins at least two of three blind pairwise downstream comparisons.
- The remaining case has no critical candidate regression.
- No candidate win depends on leaked identity, prior output, grader logic, or manual repair.
- The result is reported as one-run directional evidence.

If the result is tied or one case is ambiguous, repeat only the ambiguous pair. If the candidate loses two cases or has a critical regression, stop. Preserve the artifacts, do not promote the candidate as superior, and return to the user with the observed failure.

## Evidence and repository shape

Tracked inputs and compact outputs live under:

```text
benchmarks/toolboxmd-creating-skills/v1/
├── README.md
├── baselines/
├── case-contracts/
├── commitments.json
├── rubric.md
├── run-config.json
└── results/
```

Exact case instances are generated only after the candidate freeze and first live in an ignored benchmark workspace. They may enter the tracked results after the benchmark, once their hashes prove they were unchanged across treatments. The results directory retains generated skill packages, downstream final artifacts, per-case grading, and an identity map revealed only after grading. Full model transcripts are retained only when the harness can export them without leaking unrelated user state.

The summary manifest lives at:

```text
case-studies/evidence/2026-08-12-toolboxmd-creating-skills-benchmark.json
```

If the benchmark passes, a concise case study may be added in the same evidence ship. If it fails, the manifest and failed-attempt evidence remain inspectable, but no doctrine claim is promoted. A failed result has its own recommended evidence-only commit path so the recorded failure does not disappear merely because the candidate was not promoted.

## Relationship to the continuous-learning handoff

This design does not supersede `2026-08-12-continuous-learning-handoff.md`. It establishes the consumer that the future continuous-learning loop may update.

The two pre-existing untracked drafts remain untouched:

- `TODO.md`
- `docs/superpowers/specs/2026-05-06-drift-prevention-and-check-sources-design.md`

Their watcher, loader, versioning, and checkpoint proposals are not implementation instructions for this tranche. In particular, this tranche creates no checkpoint state and does not revive the older single-`lastseen` design.

## Rollout after tranche 1

If the benchmark passes:

1. Review whether the benchmark procedure is stable enough to become `toolboxmd-benchmarking-skills`.
2. Build `toolboxmd-updating-skills` around old-versus-new contract preservation.
3. Run cross-harness discovery and invocation smoke tests.
4. Reconcile the loader and plugin distribution design.
5. Resume the evidence-gated watcher plan with the creator as an explicit downstream consumer.

Each later step gets its own implementation gate. A passing creator benchmark does not authorize automatic doctrine mutation or merge.

## Sources

- [Agent Skills specification](https://agentskills.io/specification)
- [Agent Skills best practices](https://agentskills.io/skill-creation/best-practices)
- [Agent Skills evaluation guidance](https://agentskills.io/skill-creation/evaluating-skills)
- [OpenAI documentation: Build skills](https://learn.chatgpt.com/docs/build-skills)
- [Anthropic public skill examples](https://github.com/anthropics/skills/tree/f17010c9bb483898c1d9c9f42dde2b3a98889434/skills)
- [OpenAI public plugin skill examples](https://github.com/openai/plugins/tree/11c74d6ba24d3a6d48f54a194cd00ef3beea18f9/plugins)
- [Superpowers writing-skills](https://github.com/obra/superpowers/tree/44c9b2d6e889982ac18c27d05a19fefe335194e1/skills/writing-skills)
- [Three-question framework](/docs/03-three-questions)
- [Benchmark integrity](/docs/06-testing/benchmark-integrity)
- [Continuous-learning handoff](../plans/2026-08-12-continuous-learning-handoff.md)
