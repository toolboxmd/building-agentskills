# Frontmatter: the field-by-field reference

This is the exhaustive reference for SKILL.md frontmatter, organized as two columns: cross-platform-safe (Layer 1, agent-skills spec) and Claude Code extensions (Layer 1 spec compliance preserved; Layer 3 specifics added by Claude Code).

If you are writing a skill that must work on Codex, OpenCode, Cursor, Hermes, and Claude Code without modification, stay in the cross-platform-safe column. If you are targeting Claude Code only, you can use the extensions column for additional control.

## Cross-platform-safe fields (agent-skills spec)

Source: https://agentskills.io/specification.

### `name` (required)

Format constraints:

- Lowercase ASCII letters, digits, and hyphens only.
- Maximum 64 characters.
- No leading or trailing hyphens; no consecutive hyphens.
- Must match the parent directory name exactly.
- Reserved words: the strings `anthropic` and `claude` are forbidden (Claude Code constraint, surfaces here as a Layer 1 incompatibility).

### `description` (required)

- Maximum 1,024 characters per the spec.
- Plain text. The harness reads this on every turn to decide whether to activate the skill.
- See `docs/05-authoring/triggers.md` for the discipline of writing triggering descriptions.

### `license` (optional)

- A license name string. Common values: `Apache-2.0`, `MIT`, `proprietary`.
- Documents the license under which the skill ships. Some harnesses surface this in their UI; some do not.

### `compatibility` (optional)

- Maximum 500 characters.
- Per the spec: "intended product, system packages, network access."
- Example: `Designed for Claude Code (or similar products); requires python3, jq, git.`
- This is the canonical home for "this skill needs the following dependencies" notes. Do not put dependency lists in your README; put them here so the harness can surface them. (`REVIEWER` M4.)

### `metadata` (optional)

- Free-form key-value mapping. Harness-specific extensions can live here without breaking spec compliance.
- Example from karpathy-wiki:
  ```yaml
  metadata:
    hermes:
      config:
        - key: wiki.path
          description: Path to main wiki directory
          default: ~/wiki
  ```

### `allowed-tools` (optional, experimental in the spec)

- Per spec, marked experimental. Avoid for cross-platform; not honored uniformly.
- Claude Code's `allowed-tools` is more developed and lives in the extensions column.

## Claude Code extensions

Source: https://code.claude.com/docs/en/skills.

These fields are recognized by Claude Code only. Other harnesses ignore them silently (which is the correct cross-platform fallback behavior; your skill still loads, it just lacks the Claude Code-specific features).

### Activation control

- **`when_to_use`** (optional). Appended to `description` for triggering decisions. Counts toward the 1,536-char combined description + when_to_use truncation cap (see "Per-skill character budgets" below).
- **`disable-model-invocation`** (optional, default false). Set `true` to forbid the agent from auto-invoking. Use for side-effecting workflows (`/deploy`, `/release`).
- **`user-invocable`** (optional, default true). Set `false` to hide from the `/` slash-command menu. Combined with `disable-model-invocation: false` (the default), this is "agent-only background skill."
- **`paths`** (optional). Glob patterns limiting when the skill activates. Accepts a comma-separated string OR a YAML list. Example: `paths: ["**/*.md", "**/*.txt"]`. The skill only auto-loads when the agent is working with files matching the patterns. Source: `REVIEWER` G8.

### Argument handling

- **`argument-hint`** (optional). Hint string shown in the autocomplete UI when the user types `/skill-name`.
- **`arguments`** (optional). Named positional argument list. The skill's `$1`, `$2`, ... and `$<name>` substitutions resolve from these.

### Tool and runtime control

- **`allowed-tools`** (optional). Pre-approves tools while the skill is active. Example: `allowed-tools: Bash(git:*) Bash(jq:*) Read`.
- **`shell`** (optional). Override the shell used for backtick-bang command execution. Default depends on the platform.
- **`hooks`** (optional). Lifecycle hooks scoped to the skill's invocation. Format follows the harness hook schema.

### Model and effort overrides

- **`model`** (optional, default `inherit`). Per-skill model override. Example: `model: claude-opus-4-7` for a skill that demands deep reasoning. Source: `REVIEWER` G7.
- **`effort`** (optional, default `inherit`). Per-skill reasoning level. Example: `effort: high` for a thinking-heavy skill.

### Subagent fork

- **`context: fork`** (optional). Run the skill in a forked subagent context. Pair with `agent: Explore | Plan | general-purpose` to pick the subagent type.
- **`agent`** (optional, with `context: fork`). Names the subagent type to fork into.
- See `docs/02-mental-model.md` for when forking is the right primitive and the trap from `REVIEWER` M5 (fork without an actionable prompt returns nothing useful).

## Per-skill character budgets (Claude Code only)

Three distinct numbers, often confused. Source: `REVIEWER` B4. These constrain Claude Code-targeted skills; the cross-platform-safe spec only enforces the first.

- **1,024 characters.** Hard cap on the `description` field per the agent-skills spec. Required for cross-platform compatibility.
- **1,536 characters.** Truncation threshold on the combined `description` + `when_to_use` text in Claude Code's skill listing. Long descriptions ARE accepted but only the first 1,536 chars are visible to the agent on each turn.
- **8,000 characters (or 1% of context window).** Total budget across ALL skills' descriptions, governed by `SLASH_COMMAND_TOOL_CHAR_BUDGET`. Default is 1% of context window with an 8,000-character fallback.

Front-load triggers in the description; the bottom of a long description may never be read. See `docs/04-token-economics.md` for the budget arithmetic.

## Worked example: karpathy-wiki frontmatter

Cross-platform safe (the spec-compliant minimum):

```yaml
---
name: karpathy-wiki
description: |
  Load at the start of EVERY conversation. Entry is non-negotiable; once loaded,
  the skill's rules apply for the whole session.

  TRIGGER when (immediate capture): any research agent or research subagent
  completes or returns a file; new factual information is found...

  TRIGGER when (orientation + citation): the user asks "what do we know about X"...

  SKIP: routine file edits, syntax lookups, one-off debugging with trivial root
  causes, time-sensitive data that must be fetched fresh, or questions clearly
  outside any wiki's scope.

  Do NOT skip based on tone or shape...
metadata:
  hermes:
    config:
      - key: wiki.path
        description: Path to main wiki directory
        default: ~/wiki
---
```

This is the entire frontmatter for karpathy-wiki at v2.2 (lines 1-19 of `karpathy-wiki/skills/karpathy-wiki/SKILL.md`). It uses no Claude Code extensions; it works on every spec-compatible harness. The `metadata.hermes` block is harness-specific but lives inside the spec-compliant `metadata` field.

## Auditing your frontmatter

The cheapest validation is `skills-ref validate ./your-skill` (the agent-skills validator). Run it before merging any frontmatter change. See `docs/06-testing/unit-tests.md`.

For Claude Code-targeted skills, additionally:

- Verify `name` matches parent directory name exactly.
- Verify combined `description` + `when_to_use` fits 1,536 chars (Claude Code listing-truncation).
- Verify total across all your skills' descriptions fits 8,000 chars (or 1% of context window).
- If you use `paths`, verify your globs are correct in the actual environment (see `docs/07-mechanism-vs-decoration.md` for `paths` as activation gate in reverse).

## Sources

- `LANDSCAPE` 1.1 (agent-skills spec frontmatter fields).
- `LANDSCAPE` 1.3 (Claude Code frontmatter extensions).
- `LANDSCAPE` 3.1 (cross-platform compatibility analysis).
- `REVIEWER` G4 (name format constraints; "anthropic"/"claude" reserved).
- `REVIEWER` G7 (`model:` and `effort:` overrides).
- `REVIEWER` G8 (`paths:` glob field).
- `REVIEWER` B4 (per-skill character budget enumeration).
- `REVIEWER` M4 (`compatibility:` as documentation surface).

Cross-links: `docs/02-mental-model.md`, `docs/07-mechanism-vs-decoration.md` (paths as activation gate), `docs/04-token-economics.md`.
