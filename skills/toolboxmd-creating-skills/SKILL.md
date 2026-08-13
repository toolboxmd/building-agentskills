---
name: toolboxmd-creating-skills
description: "Create a new portable Agent Skill from user needs, trigger examples, artifacts, and observed failures. Use for new reusable skill packages and proportional validation. Do not use to update an existing skill or compare versions; route those to updating or benchmarking workflows."
---

# Creating Skills

Create the smallest evidenced package for a reusable task.

## Boundaries

- Route existing skills to `toolboxmd-updating-skills`.
- Route comparisons to `toolboxmd-benchmarking-skills`.
- Use examples for discovery; confirm rules with authoritative sources and evidence.

## Default path

### 1. Choose the primitive

Read project instructions and choose the smallest mechanism:

| Need | Prefer |
|---|---|
| Reusable judgment loaded when relevant | Skill |
| Always-on project facts | Project instructions |
| Deterministic event enforcement | Hook or CI gate |
| Deterministic transformation | Script or program |
| Explicit user-started operation | Command or user-invoked skill |
| Installation and lifecycle wiring | Plugin or extension |

A skill may coordinate mechanisms; prose does not fire them.

### 2. Build an evidence brief

Record before drafting:

- job, value, inputs, outputs, and artifacts;
- realistic triggers and close near misses;
- observed mistakes, corrections, traces, or review evidence;
- platform, safety, dependency, and delivery constraints;
- evidence gaps and how to close them.

Ask or perform one representative task to close evidence gaps. Label hypotheses.

### 3. Answer three independent questions

1. **Who invokes?** Record agent, user, or both and the mechanism.
2. **What fires on each invariant?** Mark each rigid rule as advisory or name its script, validator, hook, gate, or checked artifact.
3. **What is the token budget?** Cap description, `SKILL.md`, always-read, file, and package sizes.

### 4. Plan the smallest package

Start with `SKILL.md`. Add support only for an evidenced benefit:

- inline short rules needed on every invocation;
- use `references/` for conditional knowledge;
- use `scripts/` for repeated deterministic work or a mechanical gate;
- use `assets/` only for files consumed in outputs;
- keep comparative and trace-based evals outside the package by default;
- keep package tests only for a bundled script or distribution contract;
- add sidecars only for a stated target.

Do not add process documents or speculative directories.

### 5. Draft the activation and default path

Use portable frontmatter with matching directory and `name`. Describe capability, triggers, and exclusions, not workflow.

Keep the decision, evidence, three answers, procedure, inputs, outputs, and load-bearing gotchas in `SKILL.md`. Use rigid language only for mechanized rules.

### 6. Make script commands portable

Resolve `<skill-dir>` from loaded `SKILL.md` as an absolute argument, never from cwd or shell expansion. Use `<target-skill-dir>` for the created package.

Run this creator's validator from any working directory:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/validate_skill.py" "<target-skill-dir>"
```

Pass budget flags when defaults differ. Rewrite examples that address only `scripts/`.

### 7. Test in proportion to the claim

- Validate structure and budgets for every package.
- Syntax-check and behavior-test bundled deterministic scripts.
- Smoke-check one realistic task for a nontrivial skill when possible.
- Add pressure or repeated tests only for observed variance, high risk, or a strong claim.
- Hand comparative claims to the benchmarking workflow.

### 8. Delete, validate, and deliver

Record description, core/reference bytes, line/file/script/eval counts, and package bytes. Delete unsupported files, then rerun checks.

Inspect Git state only when the user requested Git delivery. Do not search ancestors for package-only work.

Report separately:

- **Validated:** command and result;
- **Tested:** checks and justified skips;
- **Committed:** commit only when Git delivery was requested;
- **Pushed:** remote and ref only when Git delivery was requested.

## Gotchas

- A passing validator proves mechanics, not usefulness or triggering.
- An always-read reference belongs in activated-core cost even when stored in another file.
- Sidecars are platform metadata, not portable invocation guarantees.
- Rehearse executable snippets exactly as written and rerun checks after the final deletion pass.
