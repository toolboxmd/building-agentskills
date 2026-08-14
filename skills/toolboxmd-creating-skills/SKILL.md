---
name: toolboxmd-creating-skills
description: "Create portable Agent Skills from needs, trigger and near-miss examples, artifacts, and failures. Use for new reusable packages and proportional validation. Do not update or compare skills; route those to updating or benchmarking workflows."
---

# Creating Skills

## Boundaries

- Route existing skills to `toolboxmd-updating-skills` and comparisons to `toolboxmd-benchmarking-skills`.
- Use examples to discover; confirm rules with primary sources or evidence.

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

Record job and value, triggers and near misses, inputs and outputs, mistakes, constraints, and evidence gaps. Close load-bearing gaps with questions or a representative task. Label hypotheses.

### 3. Answer three independent questions

1. **Who invokes?** Record agent, user, or both and the mechanism.
2. **What fires on each invariant?** Mark it advisory or name its mechanism and checked artifact.
3. **What is the token budget?** Cap description, activated core, files, and package.

### 4. Plan and draft the package

Start with `SKILL.md`. Keep always-needed rules inline; put conditional knowledge in `references/`, deterministic work in `scripts/`, output inputs in `assets/`, and target metadata in sidecars. Keep evals external. Test scripts and distribution contracts. Do not add speculative files.

Leave only the exact `name` slug unquoted. JSON-quote other top-level strings and portable `metadata` keys and values; omit empty `metadata`. Description states capability, triggers, and exclusions. `SKILL.md` holds decisions, evidence, procedure, inputs, outputs, and load-bearing gotchas. Use rigid language only for mechanized rules.

Generated Codex sidecars require nonempty `display_name` and `short_description`; existing sidecars may use any supported nonempty interface subset.

For explicit `metadata.hermes.config`, pass `--allow-hermes-metadata`. Keep its schema keys unquoted, start items with `- key: "..."`, and JSON-quote values. This is not portable core.

### 5. Make scripts portable

Resolve `<skill-dir>` from loaded `SKILL.md` as an absolute argument, not from cwd or shell expansion. Use `<target-skill-dir>` for the new package.

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/validate_skill.py" --warnings-as-errors "<target-skill-dir>"
```

Pass budget flags when defaults differ. Fence executable examples as `sh`, `bash`, or `shell` and use `<skill-dir>/scripts/<helper>`. Task-relative helpers fail in single-line inline, indented, or other fenced code. The lexical check treats immediate non-whitespace content after `scripts/` as a child. Directory-only mentions and child names starting with whitespace are outside it.

The checker covers the ToolboxMD subset and policy, not arbitrary YAML, CommonMark, or shell. It checks Python with AST. For each non-Python helper, run and report a syntax command, hash current bytes, and pass `--script-syntax-checked '<helper-path>=<lowercase-sha256>'`. This binds path to digest; it does not prove execution. If installed, external `skills-ref validate <target-skill-dir>` runs without an install fallback. Report its result separately; ToolboxMD does not constrain its behavior.

### 6. Test, delete, and deliver

- Validate structure and budgets. Test bundled scripts.
- Smoke-check one realistic task when possible. Add pressure only for observed variance, high risk, or a strong claim.
- Hand comparisons to the benchmarking workflow.
- Record description, core/reference bytes, line/file/script/eval counts, and package bytes. Delete unsupported files and rerun checks.

Inspect Git state only when the user requested Git delivery. Do not search ancestors for package-only work.

Report canonical and official results, tested checks/skips, and committed/pushed only for requested Git delivery.

## Gotchas

- A passing validator proves mechanics, not usefulness or triggering.
- An always-read reference belongs in activated-core cost even when stored in another file.
- Sidecars are platform metadata, not portable invocation guarantees.
- Rehearse executable snippets exactly; rerun after the final deletion pass.
