---
name: "toolboxmd-creating-skills"
description: "Create portable Agent Skills from needs, trigger/near-miss examples, artifacts, and failures. Use for reusable packages and proportional validation. Do not update or compare skills; route to updating or benchmarking workflows."
---

# Creating Skills

## Boundaries

- Route existing skills to `toolboxmd-updating-skills` and comparisons to `toolboxmd-benchmarking-skills`.
- Use examples to discover; confirm with primary sources or evidence.

## Default path

### 1. Choose the primitive

Read project instructions; choose the smallest mechanism:

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

Record job/value, triggers/near misses, I/O, mistakes, constraints, evidence gaps, and hypotheses. Close critical gaps with questions or a representative task.

### 3. Answer three independent questions

1. **Who invokes?** Record agent, user, or both and the mechanism.
2. **What fires on each invariant?** Mark it advisory or name its mechanism and checked artifact.
3. **What is the token budget?** Cap description, activated core, files, and package.

### 4. Plan and draft the package

Draft `SKILL.md` first. Inline core rules; put conditional knowledge in `references/`, deterministic work in `scripts/`, output inputs in `assets/`, metadata in sidecars, and evals outside.

JSON-quote all top-level strings, exact `name`, and portable `metadata` keys/values; omit empty `metadata`. Use literal Unicode, not surrogate escapes. Describe capability, triggers, and exclusions. Keep load-bearing decisions, evidence, procedure, I/O, and gotchas in `SKILL.md`; reserve rigid terms for mechanized rules.

Generated Codex sidecars require nonempty `display_name` and `short_description`; existing sidecars may use any supported nonempty interface subset.

For `metadata.hermes.config`, pass `--allow-hermes-metadata`. Keep schema keys unquoted, start items with `- key: "..."`, and JSON-quote values. It is outside portable core.

### 5. Make scripts portable

Resolve `<skill-dir>` from loaded `SKILL.md` to an absolute argument independent of cwd and shell expansion; `<target-skill-dir>` names the new package.

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/validate_skill.py" --creation-mode --warnings-as-errors "<target-skill-dir>"
```

Pass custom budgets. Fence executable examples as `sh`, `bash`, or `shell`; use `<skill-dir>/scripts/<helper>`. Other task- or parent-relative helper paths fail in code. The lexical check treats non-whitespace after `scripts/` as a child; directory mentions and whitespace-leading names are outside scope.

Checker scope is ToolboxMD policy, not general YAML, CommonMark, shell, or helper syntax. Put executable/shebang helpers in `scripts/`; Python uses AST. For others, run/report a syntax check, hash bytes, and pass `--script-syntax-checked '<helper-path>=<lowercase-sha256>'`; this binds bytes, not execution. No `skills-ref` install: portable mode uses a local copy; Hermes reports `skipped_extension`.

### 6. Test, delete, and deliver

- Validate structure and budgets. Test bundled scripts.
- Smoke-check one realistic task when possible. Add pressure only for observed variance, risk, or a strong claim.
- Hand comparisons to the benchmarking workflow.
- Record description, core/reference and package bytes, plus line/file/script/eval counts. Delete unsupported files; rerun checks.

Inspect Git state only when the user requests Git delivery. Do not search ancestors for package-only work.

Report canonical and official results, checks/skips, and committed/pushed only for requested Git delivery.

## Gotchas

- A passing validator proves mechanics, not usefulness or triggering.
- An always-read reference belongs in activated-core cost even when stored in another file.
- Sidecars are platform metadata, not portable invocation guarantees.
- Rehearse executable snippets exactly; rerun after the final deletion pass.
