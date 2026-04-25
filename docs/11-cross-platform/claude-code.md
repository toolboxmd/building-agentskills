# Claude Code: harness-specific frontmatter and hooks

This page covers Claude Code-specific behaviors, frontmatter extensions, and patterns that do not apply to other harnesses. The cross-platform-safe core lives in the rest of the docs; this page is for authors targeting Claude Code specifically.

Source: https://code.claude.com/docs/en/skills (Anthropic's official Claude Code docs); `LANDSCAPE` 2.1; `REVIEWER` G3, G4, G10.

## Per-scope priority

Claude Code resolves skill names from four scopes in this order:

1. **Enterprise.** Managed settings deployed organization-wide.
2. **Personal.** `~/.claude/skills/<skill-name>/SKILL.md`.
3. **Project.** `.claude/skills/<skill-name>/SKILL.md` in the project root.
4. **Plugin.** `<plugin>/skills/<skill-name>/SKILL.md` (namespaced as `<plugin-name>:<skill-name>`).

Higher priority shadows lower. A skill at `~/.claude/skills/wiki/` (personal) shadows a skill at `.claude/skills/wiki/` (project) and any plugin-provided `wiki` skill.

Plugin skills are namespaced (`plugin-name:skill-name`); they cannot shadow each other across plugins, but they CAN be shadowed by personal or project skills with the same bare name (the personal/project name resolves before the plugin namespace).

The plugin-skill-shadowed-by-personal-skill case is the karpathy-wiki development pattern: the personal `~/.claude/skills/karpathy-wiki/` is a symlink to the plugin's checked-out directory. Edits to the plugin source land immediately for the personal scope without going through plugin reinstall.

## SessionStart-hook injection pattern

Source: `LANDSCAPE` 2.1; `REVIEWER` G2; superpowers issue #1220.

The SessionStart hook reads SKILL.md, escapes for JSON, and emits the body as `hookSpecificOutput.additionalContext`. The agent receives the entire body before its first turn. This guarantees the iron laws are in context every turn but costs the full SKILL.md size in input tokens every session.

The empirical anchor: superpowers issue #1220 measured ~17.8k tokens of SessionStart-hook injection over 57 hours across 13 firings of `using-superpowers`. That is ~1,370 tokens per firing on average; the skill body is the floor.

The pattern is justified for the bootstrap skill (`using-superpowers` is the canonical exception), where the iron laws of the entire ceremony must be in context from turn 1. It is rarely justified elsewhere; description-triggered loading is the cheaper default for most skills.

When you do use SessionStart-hook injection:

- Keep the injected body small. The cost is paid every session whether the skill is invoked or not.
- Document the injection in the skill's prose so users know the cost.
- Measure the injection cost on a representative session sample. The 17.8k / 57 hours / 13 firings number is the right shape; substitute your own.

## `${CLAUDE_PLUGIN_ROOT}` substitution gotcha

Source: `REVIEWER` G3; `/Users/lukaszmaj/wiki/concepts/claude-code-plugin-root-substitution.md`.

The token `${CLAUDE_PLUGIN_ROOT}` is a config-time substitution in `plugin.json` and `hooks.json`; Claude Code expands it to the plugin's installed path when reading those files.

The token does NOT propagate to the Bash tool. A SKILL.md that says `bash "${CLAUDE_PLUGIN_ROOT}/scripts/foo.sh"` fails for personal-symlink installs (the literal string reaches Bash, expands to empty, command becomes `bash /scripts/foo.sh` which does not exist).

Three workarounds:

1. **Use `${CLAUDE_SKILL_DIR}` instead.** This token IS available in bash injection commands.
2. **Use a relative path.** `bash scripts/foo.sh` works if the skill's working directory is the skill's base directory.
3. **Compute the path explicitly.** Read the base directory from the harness preamble at the top of the skill's body, `cd` into it, then invoke. Karpathy-wiki uses this pattern.

See `docs/08-packaging-as-plugin.md` for the full discussion.

## Invocation taxonomy: `disable-model-invocation` and `user-invocable`

Source: `REVIEWER` G10.

Claude Code documents a clean dichotomy on these two frontmatter fields:

- **`disable-model-invocation: true`**: only the user can invoke. The agent cannot auto-fire. Use for side-effecting workflows: `/deploy`, `/release`, `/commit`.
- **`user-invocable: false`**: only the agent can invoke. The user cannot type `/skill-name`. Use for background knowledge / discipline skills the user should not need to think about.

The four combinations:

| disable-model-invocation | user-invocable | Behavior | Example |
|---|---|---|---|
| false (default) | true (default) | Both agent and user can invoke | The default; karpathy-wiki uses this combination implicitly |
| true | true (default) | User only | `/deploy`, `/release` |
| false (default) | false | Agent only | Background discipline skills users should not directly invoke |
| true | false | Neither | Effectively disabled; rarely useful |

Most skills should leave both at default (auto-trigger AND user-invocable). Set explicit values only when you want one of the constrained combinations.

This taxonomy is the foundational design question for any new skill (Question 1 of the hero framework, `docs/03-three-questions.md`). Decide explicitly; do not let the defaults answer for you.

## `paths:` glob as activation gate

The `paths:` field accepts glob patterns that limit when a skill auto-loads. From Anthropic's docs: "Glob patterns that limit when this skill is activated. Accepts a comma-separated string or a YAML list. When set, Claude loads the skill automatically only when working with files matching the patterns."

Example:

```yaml
paths: ["**/*.md"]
```

The skill only auto-loads when the agent is working with markdown files. This is decoration-vs-mechanism in reverse: a more reliable gate than description-keyword matching, with the trade-off that it is Claude Code only.

See `docs/05-authoring/frontmatter.md` for the field reference; `docs/07-mechanism-vs-decoration.md` for the broader pattern.

## Sources

- `LANDSCAPE` 2.1 (Claude Code skill loading mechanisms; SessionStart hook).
- `LANDSCAPE` 1.3 (Anthropic Claude Code docs).
- `REVIEWER` G3 (`${CLAUDE_PLUGIN_ROOT}` substitution gotcha; the three workarounds).
- `REVIEWER` G4 (per-scope priority).
- `REVIEWER` G10 (`disable-model-invocation` / `user-invocable` taxonomy).

Cross-links: `docs/04-token-economics.md` (the SessionStart-hook injection cost), `docs/08-packaging-as-plugin.md` (the plugin manifest and the substitution gotcha).
