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
- See [Triggers](/docs/05-authoring/triggers) for the discipline of writing triggering descriptions.

### `license` (optional)

- A license name string. Common values: `Apache-2.0`, `MIT`, `proprietary`.
- Documents the license under which the skill ships. Some harnesses surface this in their UI; some do not.

### `compatibility` (optional)

- Maximum 500 characters.
- Per the spec: "intended product, system packages, network access."
- Example: `Designed for Claude Code (or similar products); requires python3, jq, git.`
- This is the canonical home for "this skill needs the following dependencies" notes. Do not put dependency lists in your README; put them here so the harness can surface them. (`REVIEWER` M4.)

### `metadata` (optional)

- The portable Agent Skills field is a map from string keys to string values.
- Nested vendor data is not portable core. For example, Hermes documents this optional extension for Hermes-targeted packages:
  ```yaml
  metadata:
    hermes:
      config:
        - key: wiki.path
          description: Path to main wiki directory
          default: ~/wiki
  ```

Hermes extension source: [Hermes Agent, Creating Skills](https://github.com/NousResearch/hermes-agent/blob/main/website/docs/developer-guide/creating-skills.md#config-settings-configyaml).

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
- See [Mental model](/docs/02-mental-model) for when forking is the right primitive and the trap from `REVIEWER` M5 (fork without an actionable prompt returns nothing useful).

## Per-skill character budgets (Claude Code only)

Three distinct numbers (1,024 / 1,536 / 8,000) constrain Claude Code-targeted skills. Front-load triggers in the description; the bottom of a long description may never be read. Full numbers and arithmetic in [Token economics — The description listing budget](/docs/04-token-economics).

## Worked example: karpathy-wiki frontmatter

This example combines portable core fields with a Hermes vendor extension. It shows field shape only; the full TRIGGER/SKIP body is in [Karpathy-wiki description triggers](/docs/05-authoring/triggers).

```yaml
---
name: karpathy-wiki
description: |
  Load at the start of EVERY conversation. Entry is non-negotiable...
  TRIGGER when (immediate capture): ...
  TRIGGER when (orientation + citation): ...
  SKIP: ...
metadata:
  hermes:
    config:
      - key: wiki.path
        description: Path to main wiki directory
        default: ~/wiki
---
```

Source: [v2.2 SKILL.md lines 1–19](https://github.com/toolboxmd/karpathy-wiki/blob/4f4c00d/skills/karpathy-wiki/SKILL.md?plain=1#L1-L19). The `name` and `description` are portable core. The nested `metadata.hermes` block is a Hermes extension and must not be presented as string-to-string Agent Skills metadata.

## Auditing your frontmatter

The cheapest validation is `skills-ref validate ./your-skill` (the agent-skills validator). Run it before merging any frontmatter change. See [Unit tests](/docs/06-testing/unit-tests).

For Claude Code-targeted skills, additionally:

- Verify `name` matches parent directory name exactly.
- Verify combined `description` + `when_to_use` fits 1,536 chars (Claude Code listing-truncation).
- Verify total across all your skills' descriptions fits 8,000 chars (or 1% of context window).
- If you use `paths`, verify your globs are correct in the actual environment (see [Mechanism vs decoration](/docs/07-mechanism-vs-decoration) for `paths` as activation gate in reverse).

## Sources

- `LANDSCAPE` 1.1 (agent-skills spec frontmatter fields).
- `LANDSCAPE` 1.3 (Claude Code frontmatter extensions).
- `LANDSCAPE` 3.1 (cross-platform compatibility analysis).
- `REVIEWER` G4 (name format constraints; "anthropic"/"claude" reserved).
- `REVIEWER` G7 (`model:` and `effort:` overrides).
- `REVIEWER` G8 (`paths:` glob field).
- `REVIEWER` B4 (per-skill character budget enumeration).
- `REVIEWER` M4 (`compatibility:` as documentation surface).

Cross-links: [Mental model](/docs/02-mental-model), [Mechanism vs decoration](/docs/07-mechanism-vs-decoration) (paths as activation gate), [Token economics](/docs/04-token-economics).
