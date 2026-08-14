---
name: "toolboxmd-creating-skills"
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

Record job/value, triggers/near misses, inputs/outputs, mistakes, constraints, and evidence gaps. Close critical gaps with questions or a representative task. Label hypotheses.

### 3. Answer three independent questions

1. **Who invokes?** Record agent, user, or both and the mechanism.
2. **What fires on each invariant?** Mark it advisory or name its mechanism and checked artifact.
3. **What is the token budget?** Cap description, activated core, files, and package.

### 4. Plan and draft the package

Draft `SKILL.md` first. Keep core rules inline, conditional knowledge in `references/`, deterministic work in `scripts/`, output inputs in `assets/`, target metadata in sidecars, and evals external.

JSON-quote every top-level string, including exact `name`, and every portable `metadata` key/value; omit empty `metadata`. Use literal Unicode, not surrogate escapes. Description states capability, triggers, exclusions. Keep decisions, evidence, procedure, I/O, and load-bearing gotchas in `SKILL.md`. Reserve rigid language for mechanized rules.

Generated Codex sidecars require nonempty `display_name` and `short_description`; existing sidecars may use any supported nonempty interface subset.

For `metadata.hermes.config`, pass `--allow-hermes-metadata`. Keep schema keys unquoted, start items with `- key: "..."`, and JSON-quote values. It is outside portable core.

### 5. Make scripts portable

Resolve `<skill-dir>` from loaded `SKILL.md` to an absolute argument, independent of cwd and shell expansion. `<target-skill-dir>` names the new package.

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/validate_skill.py" --creation-mode --warnings-as-errors "<target-skill-dir>"
```

Pass nondefault budgets. Fence executable examples as `sh`, `bash`, or `shell` and use `<skill-dir>/scripts/<helper>`. Task- and parent-relative helpers fail in inline, indented, and other fences. The lexical check treats non-whitespace immediately after `scripts/` as a child; directory mentions and whitespace-leading child names are outside it.

The checker covers ToolboxMD policy, not general YAML, CommonMark, shell, or helper syntax. Executable/shebang helpers belong in `scripts/`. Python uses AST. For other helpers, run and report a syntax command, hash current bytes, and pass `--script-syntax-checked '<helper-path>=<lowercase-sha256>'`. This binds path and digest, not execution. It runs but never installs `skills-ref validate <target-skill-dir>`; report it separately because external behavior is outside ToolboxMD.

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
