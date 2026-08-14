---
name: "toolboxmd-creating-skills"
description: "Create portable Agent Skills from needs, trigger/near-miss examples, artifacts, and failures. Use for reusable packages and proportional validation. Do not update or compare skills; route to updating or benchmarking workflows."
---

# Creating Skills

## Boundaries

- Route existing skills to `toolboxmd-updating-skills` and comparisons to `toolboxmd-benchmarking-skills`.
- Use examples to discover; verify claims with primary sources or evidence.

## Default path

### 1. Choose the primitive

Read project instructions, then choose the smallest mechanism:

| Need | Prefer |
|---|---|
| Reusable judgment on demand | Skill |
| Always-on project facts | Project instructions |
| Event enforcement | Hook or CI gate |
| Deterministic work | Script or program |
| User-started operation | Command or user-invoked skill |
| Installation/lifecycle wiring | Plugin or extension |

Skills may coordinate them; prose cannot fire them.

### 2. Build an evidence brief

Record value, triggers/near misses, I/O, artifacts, mistakes, constraints, gaps, and hypotheses. Resolve critical gaps with questions or a representative task.

### 3. Answer three independent questions

1. **Who invokes?** Record agent, user, or both, plus mechanism.
2. **What fires on each invariant?** Mark advisory, or name its mechanism and checked artifact.
3. **What is the token budget?** Cap description, activated core, files, and package.

### 4. Draft the package

Draft `SKILL.md` first. Inline core rules; use `references/` for conditional knowledge, `scripts/` for deterministic work, `assets/` for output inputs, sidecars for metadata, and keep evals outside.

JSON-quote every top-level string, including exact `name`, and portable metadata keys/values; omit empty `metadata`. Use literal Unicode, not surrogate escapes. Keep capability, triggers, exclusions, load-bearing decisions, procedure, I/O, and gotchas in `SKILL.md`; reserve rigid terms for mechanisms.

Generated Codex sidecars require nonempty `display_name` and `short_description`; existing sidecars may use any supported nonempty interface subset.

For non-portable `metadata.hermes.config`, pass `--allow-hermes-metadata`. Keep schema keys unquoted, start items with `- key: "..."`, and JSON-quote values.

### 5. Make scripts portable

Resolve `<skill-dir>` from loaded `SKILL.md` to an absolute path independent of cwd or shell expansion; `<target-skill-dir>` is the new package.

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -B "<skill-dir>/scripts/validate_skill.py" --creation-mode --warnings-as-errors "<target-skill-dir>"
```

Pass custom budgets. Fence executable examples as `sh`, `bash`, or `shell`; use `<skill-dir>/scripts/<helper>`. Other task- or parent-relative helper paths fail in code. The lexical check treats non-whitespace after `scripts/` as a child; directory mentions and whitespace-leading names are out of scope.

Checker scope is ToolboxMD policy, not general YAML, CommonMark, shell, or helper syntax. Keep executable/shebang helpers in `scripts/`; Python uses AST. For others, run/report a syntax check, hash bytes, and pass `--script-syntax-checked '<helper-path>=<lowercase-sha256>'`; this binds bytes, not execution. Do not install `skills-ref`: portable mode uses a local copy; Hermes reports `skipped_extension`.

### 6. Test, delete, and deliver

- Validate structure/budgets and test bundled scripts.
- Smoke-check a realistic task when possible. Add pressure only for observed variance, risk, or strong claims.
- Route comparisons to benchmarking.
- Record description, core/reference/package bytes and line/file/script/eval counts. Delete unsupported files; rerun.

Inspect Git state only when the user requests Git delivery. Do not search ancestors for package-only work.

Report canonical/official results and skips; report committed/pushed only for requested Git delivery.

## Gotchas

- A validator proves mechanics, not usefulness or triggering.
- An always-read reference belongs in activated-core cost even when stored in another file.
- Sidecars are metadata, not portable invocation guarantees.
- Rehearse executable snippets exactly after the final deletion pass.
