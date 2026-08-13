# ToolboxMD creating-skills benchmark v2 design

**Status:** Protocol revision 2 frozen before eligible treatment runs

**Date:** 2026-08-13

## Decision to make

Determine whether the frozen `toolboxmd-creating-skills` candidate or the frozen Codex built-in `skill-creator` produces more useful daily-use skills under one Codex configuration. The result must also identify concrete improvements for this repository or for the ToolboxMD creator product.

The benchmark may conclude `toolboxmd`, `builtin`, `mixed`, or `inconclusive`. It must not force a winner when the evidence does not distinguish the treatments.

## Why v1 is insufficient

Benchmark v1 remains inspectable directional evidence for its three declared archetypes. It does not answer the present question because:

- its downstream prompts explicitly directed the agent to a generated `SKILL.md`, so it did not measure implicit triggering;
- it had no no-skill qualification arm, so it could not reject tasks the model already handled without a skill;
- its cases emphasized production and security boundaries more than common personal workflows;
- one blind replay leaked treatment identity and was correctly invalidated;
- a direct review found both creators produced similarly sized cores and nearly identical safety guidance, while one downstream omission could plausibly be model variance rather than a creator effect.

V2 therefore measures activation, workflow completion, deterministic utility, and runtime cost directly. Blind semantic review is optional diagnostic evidence, not a release gate.

## Frozen treatments

Both treatments existed before the exact v2 cases were authored.

- `builtin`: the inspectable Codex 0.147.0 built-in creator snapshot already retained by v1.
- `toolboxmd`: the failed but inspectable v1 candidate snapshot. Its v1 failure prevents promotion, but does not prevent a new benchmark from testing a different claim.

The exact hashes and paths are recorded in `benchmarks/toolboxmd-creating-skills/v2/run-config.json` and `commitments.json`. Generated target skills are never repaired after a treatment run.

## Causal comparison

The benchmark changes one authoring input: the creator package.

All other authoring conditions are held constant:

- Codex CLI version;
- model and reasoning effort;
- prompt and source files;
- sandbox and network policy;
- disabled plugins, apps, memories, and unrelated skills;
- output boundary;
- session freshness.

Each authored skill is then evaluated in a new downstream session. The positive downstream prompt is natural and does not name a skill, a creator, `SKILL.md`, or a skill path. The generated skill is installed through the normal repository `.agents/skills/` discovery path.

A skill counts as triggered only when the event trace proves that the agent loaded the generated `SKILL.md`. Agent self-report does not establish triggering.

## The ordinary-workspace counterfactual

The benchmark is not allowed to make the no-skill arm fail merely by withholding necessary facts.

For a given case, every downstream arm receives byte-identical ordinary workspace files:

- the task data;
- the user's private conventions and templates;
- the same natural prompt;
- the same write boundary.

The no-skill arm receives no target skill listing. A treatment arm receives one generated target skill in addition to the same ordinary files. The generated package may duplicate or organize knowledge from the ordinary files because package design is part of what the creator produced.

This tests the user's practical hypothesis: an ordinary note can contain enough information, but a well-authored skill should cause the agent to discover and execute the right procedure reliably.

## Case qualification

A case qualifies before creator authoring only when:

1. the no-skill run is eligible and mechanically capable of performing the task;
2. at least one declared critical downstream assertion fails;
3. the failure is not caused by missing facts, unavailable tools, network access, or an impossible output contract;
4. the exact failed run and grade remain inspectable.

If the no-skill arm passes all critical assertions, the case is invalid for this benchmark. It may still be a useful product example, but it cannot distinguish a skill creator from normal model competence.

## Daily-use cases

### Primary 1: meeting notes to follow-ups

The user asks for a follow-up and tracker update from meeting notes. Private team conventions define what counts as a decision, action, question, or deferred idea, how owners and missing dates are represented, the tracker schema, and the QA receipt.

The case tests:

- implicit activation from a normal request;
- reading and applying user-specific conventions;
- completing both the visible summary and the less salient tracker and QA steps;
- not promoting ideas into actions;
- preserving evidence identifiers;
- deterministic file updates.

### Primary 2: weekly notes to status deck

The user asks for a leadership status deck from weekly notes. Private conventions define a five-slide Marp structure, status vocabulary, evidence citations, unsupported-claim boundaries, and a validation receipt.

The case tests:

- implicit activation for a common document workflow;
- use of a supplied template and terminology;
- full artifact completion rather than a prose summary;
- evidence fidelity and qualifier preservation;
- progressive disclosure without relying on another presentation skill.

### Conditional reserve: personal expense rollup

The user asks to update a personal expense tracker from extracted CSV transactions. Private rules define categories, duplicate handling, excluded transfers, output ordering, monthly totals, and QA.

The reserve avoids OCR and image quality so it measures procedure and validation. It runs only when the two primary cases split, one primary case is invalid, or the primary evidence cannot produce a decision.

## Trigger precision

Positive triggering is evaluated in every valid case. False-positive behavior is evaluated after the positive runs with one short, fresh near-miss session per treatment. That session exposes all target skills authored by that treatment and asks for a related but non-procedural answer.

Loading any target `SKILL.md` during the near miss is a false positive. The near miss cannot rescue a treatment that failed the positive workflow, but it breaks a utility tie in favor of the more precise treatment.

## Evidence layers

Each run records separate evidence for:

1. **Integrity:** exact model, CLI, isolation, paths, input hashes, exit state, network result, and forbidden command audit.
2. **Activation:** target skill load, unexpected skill loads, load order, and near-miss false positives.
3. **Utility:** deterministic output assertions and protected-input boundary.
4. **Package quality:** official Agent Skills validation, tree hash, file count, core lines, core words, and package bytes.
5. **Cost:** duration, input tokens, cached input tokens, uncached input tokens, output tokens, and total runtime tokens.

Authoring cost and downstream runtime cost are reported separately. Runtime cost is the tie-break because a target skill may be used many times after it is authored.

## Harness correction before eligible treatment runs

The first four authoring attempts exposed a runner defect before any package became eligible for downstream use. Both built-in runs executed the creator's Python sidecar generator, which created a `creator/scripts/__pycache__/...pyc` cache file outside `output/`. Source bytes did not change, but the protected-input boundary correctly rejected both runs.

Protocol revision 2 adds a v2-only runner that sets `PYTHONDONTWRITEBYTECODE=1` and routes any Python cache prefix under the run's ignored `.tmp/` directory. It leaves the cases, prompts, treatments, grader, model, effort, sandbox, and decision rule unchanged. All four initial attempts remain evidence. All four treatments are repeated symmetrically so an environment difference cannot favor either creator. The four discarded attempts count toward the 17-session hard maximum.

## Per-case winner

A treatment is ineligible for a case if its authoring run is contaminated, its generated package is invalid, its positive run is contaminated, or the target skill is not loaded.

Among eligible treatments, compare in this order:

1. critical deterministic assertions passed;
2. all deterministic assertions passed;
3. downstream artifact completeness;
4. positive trigger evidence;
5. uncached downstream runtime tokens when utility is equal.

Equal utility with higher uncached runtime cost loses. If utility and runtime cost are equal, the case is a tie. Small stylistic differences do not determine a winner.

## Overall decision

- Recommend `toolboxmd` when it wins both valid primary cases with no critical regression.
- Recommend `builtin` under the mirror rule.
- If the primary cases split, replace an invalid primary case, or otherwise leave a decision tie, run the reserve case.
- After a reserve run, recommend a treatment only when it has at least two case wins and no critical regression.
- Otherwise report `mixed` or `inconclusive`.

The operational recommendation is bounded to Codex CLI 0.147.0, `gpt-5.6-sol`, medium reasoning, the frozen creator versions, and these case families. A one-run result does not establish universal creator superiority or cross-provider portability.

## Session budget and stopping

The clean path uses 12 decision sessions:

- 2 no-skill qualifications;
- 4 authoring sessions;
- 4 positive downstream sessions;
- 2 treatment-level near-miss sessions.

The reserve adds 5 sessions: one qualification, two authoring runs, and two positive downstream runs. The hard maximum is 17 sessions. A paired repeat is allowed only when it can change the decision and only if it stays inside the same hard maximum. A reserve and a repeat cannot silently expand the ceiling.

The infrastructure preflight is outside the decision-session count and must pass before qualification. It verifies real implicit discovery, absence of unrelated skills, and blocked outbound network access under the exact runner configuration.

## Result to repository changes

The benchmark does not end with a score. The final analysis must compare the generated packages and traces one to one, then map every material difference to one of:

- creator instructions that should change;
- validation or evaluation mechanisms that should change;
- documentation doctrine that should change;
- benchmark limitations that require no product change.

No recommendation is implemented automatically. A failed result remains committed with a non-promotion statement. A passing result still requires a separate product patch, relevant checks, and review.

## External basis

The design follows current primary guidance that recommends two or three realistic cases, with-skill versus without-skill or previous-version comparison, clean contexts, deterministic assertions, trace inspection, and token and duration recording:

- https://agentskills.io/skill-creation/evaluating-skills
- https://agentskills.io/skill-creation/optimizing-descriptions
- https://learn.chatgpt.com/docs/build-skills

An independent Grok Build audit, session `019ffb04-7efd-7333-aec2-778fdf65477f`, returned `GO WITH CHANGES`. Its accepted changes were daily-use cases, a conditional reserve, deterministic evidence as the core judge, a bounded session budget, and a Codex-only claim. Its proposed status-deck case was adjusted to Marp Markdown so a preinstalled presentation skill cannot confound the creator comparison.
