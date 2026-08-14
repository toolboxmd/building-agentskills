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

Record job/value, triggers/near misses, inputs/outputs, mistakes, constraints, and evidence gaps. Close load-bearing gaps with questions or a representative task. Label hypotheses.

### 3. Answer three independent questions

1. **Who invokes?** Record agent, user, or both and the mechanism.
2. **What fires on each invariant?** Mark it advisory or name its mechanism and checked artifact.
3. **What is the token budget?** Cap description, activated core, files, and package.

### 4. Plan and draft the package

Start with `SKILL.md`. Keep core rules inline. Put conditional knowledge in `references/`, deterministic work in `scripts/`, output inputs in `assets/`, and target metadata in sidecars. Keep evals external. Test scripts and distribution contracts. Delete speculative files.

JSON-quote all top-level strings, including exact `name`, and all portable `metadata` keys/values. Omit empty `metadata`. Description states capability, triggers, and exclusions. Keep decisions, evidence, procedure, inputs, outputs, and load-bearing gotchas in `SKILL.md`. Use rigid language only for mechanized rules.

Generated Codex sidecars require nonempty `display_name` and `short_description`; existing sidecars may use any supported nonempty interface subset.

For explicit `metadata.hermes.config`, pass `--allow-hermes-metadata`. Keep its schema keys unquoted, start items with `- key: "..."`, and JSON-quote values. This is not portable core.

### 5. Make scripts portable

Resolve `<skill-dir>` from loaded `SKILL.md` to an absolute argument independent of cwd and shell expansion. Use `<target-skill-dir>` for the new package.

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/validate_skill.py" --warnings-as-errors "<target-skill-dir>"
```

Pass nondefault budgets. Fence executable examples as `sh`, `bash`, or `shell`; use `<skill-dir>/scripts/<helper>`. Task-relative helpers fail in single-line inline, indented, or other fences. The lexical check treats immediate non-whitespace content after `scripts/` as a child; directory-only mentions and whitespace-leading child names are outside it.

The checker covers ToolboxMD policy, not arbitrary YAML, CommonMark, shell, or helper syntax. Executable/shebang helpers belong in `scripts/`. Python uses AST. For each other helper, run and report a syntax command, hash current bytes, and pass `--script-syntax-checked '<helper-path>=<lowercase-sha256>'`. This binds path to digest, not execution. It runs installed `skills-ref validate <target-skill-dir>` but never installs it. Report that result separately; external behavior is outside ToolboxMD.

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
