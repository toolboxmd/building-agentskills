# Codex: agents/openai.yaml sidecar

OpenAI's Codex CLI (`openai/codex`) supports the agent-skills format natively, plus an optional Codex-specific sidecar manifest for OpenAI-side extensions. This page covers what is portable and what is Codex-specific.

Source: `LANDSCAPE` 1.4, 2.2.

## Native Agent Skills support

Codex scans for skills in three locations, in this priority order:

1. `.agents/skills/<skill-name>/SKILL.md` (project scope).
2. `$HOME/.agents/skills/<skill-name>/SKILL.md` (user scope).
3. `/etc/codex/skills/<skill-name>/SKILL.md` (admin scope).

Plus built-in skills shipped with Codex itself.

A spec-compliant SKILL.md (cross-platform-safe frontmatter; see `docs/05-authoring/frontmatter.md`) loads in Codex without modification. Discovery is at startup; progressive disclosure follows the spec.

## Invocation

Codex supports both implicit (description-based auto-trigger) and explicit invocation (`/skills`, `$prefix`).

The `policy.allow_implicit_invocation` field in the optional `agents/openai.yaml` sidecar (see below) defaults to `true`, matching Claude Code's auto-trigger behavior. Set to `false` to require explicit invocation.

## The optional sidecar: `agents/openai.yaml`

Codex-specific extensions live in a sibling YAML file at `agents/openai.yaml` next to the SKILL.md. The sidecar is optional; a skill works without it.

What the sidecar provides:

- **`interface`.** Display name, icon, brand color, default prompt. Codex UI surfaces these in its skill picker.
- **`policy.allow_implicit_invocation`.** Boolean; default `true`. When `false`, the agent cannot auto-fire the skill.
- **`dependencies`.** MCP servers the skill depends on. Codex resolves and ensures availability before the skill activates.

Example sidecar:

```yaml
interface:
  display_name: My Wiki Skill
  icon: book
  brand_color: "#3366cc"
  default_prompt: "Use the wiki to answer this question."

policy:
  allow_implicit_invocation: true

dependencies:
  mcp_servers:
    - filesystem
```

Other harnesses ignore the sidecar silently. Your skill remains portable.

## Multi-agent / subagent semantics

Codex's subagent support is opt-in via TOML config:

```toml
[features]
multi_agent = true
```

Without this flag, `context: fork`-style skills (Claude Code pattern) do not work in Codex; the skill loads but the fork primitive is unavailable. Authors targeting both harnesses should test the fork path on Codex with `multi_agent = true` enabled.

## Persistent context

Where Claude Code uses `CLAUDE.md` and Codex uses `AGENTS.md` for persistent always-on context, the convention is "vendor-neutral file in the repo root, vendor-specific symlink as needed." Codex reads `AGENTS.md`; Claude Code reads `CLAUDE.md`. Some authors symlink one to the other for cross-vendor compatibility; others maintain both.

`AGENTS.md` is NOT a skill; it is the always-on memory equivalent. See `docs/02-mental-model.md` for the mental model.

## What Codex does NOT support (vs Claude Code)

- **No skill-side hooks.** Codex does not run hooks scoped to a skill's invocation. Use the harness's own hook system (config-level, not skill-level) if you need event handling.
- **No `${CLAUDE_PLUGIN_ROOT}` substitution.** Codex has its own path semantics; the Claude Code substitution token does not apply here.
- **No Claude Code-extension frontmatter fields.** `when_to_use`, `disable-model-invocation`, `user-invocable`, `model`, `effort`, `paths`, etc. are silently ignored. Stay in the cross-platform-safe column for portability; use the optional sidecar for Codex-specific behavior.

## Sources

- `LANDSCAPE` 1.4 (cross-platform comparison; Codex section).
- `LANDSCAPE` 2.2 (Codex CLI: native Agent Skills, agents/openai.yaml sidecar, multi-agent opt-in, AGENTS.md).

Cross-links: `docs/11-cross-platform/others.md`.
