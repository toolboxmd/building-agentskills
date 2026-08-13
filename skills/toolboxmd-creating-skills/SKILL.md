---
name: toolboxmd-creating-skills
description: "Create a new portable Agent Skill from user needs, trigger examples, artifacts, and observed failures. Use for new reusable skill packages and proportional validation. Do not use to update an existing skill or compare versions; route those to updating or benchmarking workflows."
---

# Creating Skills

Create the smallest evidence-backed package that makes a reusable task more reliable. Start from the user's real job and observed failures, not a generic template.

## Boundaries

- If a target skill already exists, use `toolboxmd-updating-skills` when available. Do not turn creation into an updater.
- If the user asks which version is better, use `toolboxmd-benchmarking-skills` when available. Do not build a comparative benchmark here.
- Treat catalogs and examples as discovery evidence. Confirm format rules with authoritative sources and behavior claims with inspected evidence.

## Default path

### 1. Choose the primitive

Inspect applicable project instructions, then choose the smallest mechanism that matches the job:

| Need | Prefer |
|---|---|
| Reusable judgment or procedure loaded when relevant | Skill |
| Always-on project facts | Project instructions |
| Deterministic event enforcement | Hook or CI gate |
| Repeated deterministic transformation | Script or program |
| Explicit user-started operation | Command or user-invoked skill |
| Installation and lifecycle wiring | Plugin or extension |

A skill may coordinate mechanisms, but its prose does not make them fire. Explain when a smaller primitive is enough.

### 2. Build an evidence brief

Record before drafting:

- reusable job and user value;
- realistic prompts that should trigger and close near misses that should not;
- required inputs, outputs, and representative artifacts;
- observed mistakes, corrections, traces, or review evidence;
- platform, safety, dependency, destination, and delivery constraints;
- unresolved evidence gaps and how to close them.

Ask focused questions or perform one representative task when load-bearing evidence is missing. Label hypotheses instead of presenting them as established rules.

### 3. Answer three independent questions

1. **Who invokes?** Record agent, user, or both, plus any platform-specific mechanism.
2. **What fires on each invariant?** Classify every rigid rule or threshold as advisory judgment or name the script, validator, hook, CI gate, or checked artifact that enforces it.
3. **What is the token budget?** Set caps for description characters, `SKILL.md` lines and bytes, always-read reference bytes, file count, and package bytes.

Correct invocation does not enforce rules, and a small package does not guarantee discovery.

### 4. Plan the smallest package

Start with `SKILL.md`. Add a support file only when inspected evidence names its benefit:

- inline short rules needed on every invocation;
- use `references/` only for substantial knowledge loaded under a real condition;
- use `scripts/` for repeated deterministic work or a justified mechanical gate;
- use `assets/` only for files consumed in outputs;
- keep comparative, repeated, and trace-based evals outside the distributed skill by default;
- keep package-local tests only for a bundled deterministic script or explicit distribution contract;
- add platform sidecars only for a stated delivery target.

Do not add a README, changelog, design diary, status file, or speculative support directory.

### 5. Draft the activation and default path

Use portable frontmatter with matching directory and `name`. Write a compact description that names capability, concrete trigger situations, and important exclusions without summarizing the workflow.

Keep the primitive decision, evidence brief, three answers, default procedure, inputs, outputs, and load-bearing gotchas in `SKILL.md`. Explain why where judgment is required. Reserve rigid language for rules with a named mechanism.

### 6. Make script commands portable

For any installed skill, resolve `<skill-dir>` from the loaded `SKILL.md` path before executing a bundled script. Treat it as an absolute directory passed as an argument, never as the task working directory and never as shell-expanded text. Use the equivalent `<target-skill-dir>` for the package being created.

Run this creator's validator from any working directory:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/validate_skill.py" "<target-skill-dir>"
```

Pass explicit budget flags matching the design record when its defaults are not the intended contract. A generated example that addresses only `scripts/` is fragile and should be rewritten before delivery.

### 7. Test in proportion to the claim

- Validate structure and budgets for every package.
- Syntax-check and behavior-test bundled deterministic scripts.
- Run one realistic downstream smoke check for a nontrivial skill when the harness permits it.
- Add pressure or repeated tests only for observed variance, discipline rules, high-risk behavior, or a strong reliability claim.
- Hand comparative claims to the benchmarking workflow.

Keep test fixtures and comparative evidence outside the distributed package unless their runtime or maintenance benefit is explicit.

### 8. Delete, validate, and deliver

Inspect the complete tree. Record description characters, core lines and bytes, always-read and conditional reference bytes, file count, script count, eval count, and package bytes. Name the evidence for every support file, delete files with only hypothetical benefit, then rerun validation and focused tests.

Inspect Git state only when the destination is a repository and the user requested Git delivery. Do not search ancestor repositories for a package-only task.

Report separately:

- **Validated:** command and result;
- **Tested:** checks run and any justified skips;
- **Committed:** commit only when Git delivery was requested;
- **Pushed:** remote and ref only when Git delivery was requested.

## Gotchas

- A passing validator proves package mechanics, not usefulness or triggering.
- An always-read reference belongs in activated-core cost even when stored in another file.
- Optional sidecars are platform metadata, not portable invocation guarantees.
- Rehearse executable snippets exactly as written and rerun checks after the final deletion pass.
