---
name: toolboxmd-creating-skills
description: "Create portable Agent Skills from needs, trigger and near-miss examples, artifacts, and failures. Use for new reusable packages and proportional validation. Do not update or compare skills; route those to updating or benchmarking workflows."
---

# Creating Skills

## Boundaries

- For new skills. Route existing skills to `toolboxmd-updating-skills` and comparisons to `toolboxmd-benchmarking-skills`.
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

A skill may coordinate these; prose does not fire them.

### 2. Build an evidence brief

Record job and value, triggers and close near misses, inputs and outputs, observed mistakes, constraints, and evidence gaps. Ask questions or do a representative task to close load-bearing gaps. Label hypotheses.

### 3. Answer three independent questions

1. **Who invokes?** Record agent, user, or both and the mechanism.
2. **What fires on each invariant?** Mark it advisory or name its mechanism and checked artifact.
3. **What is the token budget?** Cap description, activated core, files, and package.

### 4. Plan and draft the package

Start with `SKILL.md`. Add only evidenced support: always-needed rules inline; conditional knowledge in `references/`; repeated deterministic work or gates in `scripts/`; output inputs in `assets/`; sidecars for a stated target. Keep comparative evals outside. Add package tests only for a bundled script or distribution contract. Never add speculative directories.

Use portable frontmatter with matching directory and `name`. Describe capability, triggers, and exclusions, not workflow. Keep decisions, evidence, three answers, procedure, inputs, outputs, and load-bearing gotchas in `SKILL.md`. Reserve rigid language for mechanized rules.

### 5. Make scripts portable

Resolve `<skill-dir>` from loaded `SKILL.md` as an absolute argument, never from cwd or shell expansion. Use `<target-skill-dir>` for the created package.

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/validate_skill.py" "<target-skill-dir>"
```

Pass budget flags when defaults differ. Rewrite examples that address only `scripts/`.

### 6. Test, delete, and deliver

- Validate structure and budgets. Test bundled scripts.
- Smoke-check one realistic task when possible. Add pressure or repetition only for observed variance, high risk, or a strong claim.
- Hand comparisons to the benchmarking workflow.
- Record description, core/reference bytes, line/file/script/eval counts, and package bytes. Delete unsupported files and rerun checks.

Inspect Git state only when the user requested Git delivery. Do not search ancestors for package-only work.

Report validated command/result and tested checks/skips. Report committed/pushed only when Git delivery was requested.

## Gotchas

- A passing validator proves mechanics, not usefulness or triggering.
- An always-read reference belongs in activated-core cost even when stored in another file.
- Sidecars are platform metadata, not portable invocation guarantees.
- Rehearse executable snippets exactly as written and rerun checks after the final deletion pass.
