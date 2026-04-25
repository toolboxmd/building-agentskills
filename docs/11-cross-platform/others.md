# Other harnesses: OpenCode, Cursor, Hermes, Continue.dev, Copilot CLI

This page covers the remaining harnesses in the agent-skill ecosystem as of mid-2026. Each gets one paragraph: what it supports, what it does not, and where it diverges from the cross-platform-safe core.

Source: `LANDSCAPE` 1.4, 2.4 through 2.6.

## OpenCode (`sst/opencode`)

OpenCode supports the agent-skills format natively. Skills are read from `.opencode/skills/`, `.claude/skills/`, and `.agents/skills/` (intentional cross-CLI compatibility; OpenCode is the most portable of the agent-skills harnesses for that reason).

Invocation is **explicit** via OpenCode's native `skill` tool: the agent decides when to call `skill({name: "wiki"})` rather than auto-firing on description match. This is a meaningful divergence from Claude Code's auto-trigger behavior; an OpenCode-targeted skill description should describe what the skill does, since the agent reads it and chooses to call rather than the harness deciding.

OpenCode plugins are JavaScript modules in `.opencode/plugins/<name>.js`. They can register the skills directory at startup and prepend bootstrap context to the first user message via `experimental.chat.messages.transform`. Per `LANDSCAPE` 2.4, this is how superpowers' `.opencode/plugins/superpowers.js` provides its bootstrap: prepending to the first user message rather than via SystemMessage (which broke Qwen and other models per superpowers-packaging-study).

OpenCode does NOT support skill-side hooks. Hook-shaped behavior must live in the JS plugin layer or in OpenCode's config-level hook system.

## Cursor

Cursor supports Agent Skills natively, plus a richer plugin model. Cursor Plugins bundle skills + rules + commands + hooks + MCP servers in one installable unit.

The plugin manifest is `.cursor-plugin/plugin.json` with explicit per-component paths:

```json
{
  "skills": "./skills/",
  "agents": "./agents/",
  "commands": "./commands/",
  "hooks": "./hooks/hooks-cursor.json"
}
```

Cursor's hook event set: SessionStart, beforeSubmitPrompt, PreToolUse, PostToolUse, Stop. Each hook config has a `matcher` regex + shell commands. The events are similar to Claude Code's but with Cursor-specific matcher semantics.

Invocation is implicit (description-based auto-trigger) plus explicit (`/skill-name`, `$skill-name` in prompt). Both work.

A spec-compliant SKILL.md works in Cursor without modification. The Cursor-specific extensions (hook events, plugin manifest format) only matter if you ship a Cursor-targeted plugin.

## Hermes Agent

Hermes is agentskills.io-compatible. Skills live at `~/.hermes/skills/[<category>/]<name>/`. Discovery is via the `skills_list` and `skill_view` tools.

Hermes hooks live in a separate plugin system at `~/.hermes/plugins/<name>/plugin.yaml`, with Python callbacks for events: `pre_tool_call`, `post_tool_call`, `pre_llm_call`, `post_llm_call`, `on_session_start`, `on_session_end`, etc. The hook system is more granular than most other harnesses.

Hermes is a less-known harness but worth supporting if you target the broader agent ecosystem; it adopted the agent-skills format specifically for cross-compatibility, so a spec-compliant skill works without modification.

## Continue.dev

Continue.dev uses `~/.continue/config.json` with custom commands. It is NOT directly Agent Skills-compatible; the prompt-augmentation model is conceptually similar (markdown-based) but the file format and discovery mechanism differ.

Authors targeting Continue.dev must rewrite their skill as a Continue command. There is no automatic port. For most ecosystem-targeted skill authors, Continue.dev support is out of scope unless explicitly required.

## GitHub Copilot CLI

As of v1.0.11, Copilot CLI supports `additionalContext` injection via SessionStart hook (per superpowers v5.0.7 release notes). It reads superpowers' marketplace via `copilot plugin marketplace add`.

Copilot CLI does NOT have native Agent Skills support. The SessionStart hook bridge gives skill-shaped behavior (always-on context injection from a SKILL.md), but with the same cost trade-off as Gemini: the body is paid every session regardless of need.

If you are shipping for Copilot CLI, the SessionStart hook injection pattern is your only path. Document the cost (full SKILL.md per session) and consider whether a slimmer always-on snippet would suffice.

## Convergence and divergence summary

What is portable across all spec-compatible harnesses (Claude Code, Codex, OpenCode, Cursor, Hermes):

- The `SKILL.md` file with cross-platform-safe frontmatter (`name`, `description`, optional `license`, `compatibility`, `metadata`).
- The body in plain markdown, under 500 lines.
- One-level-deep `references/`, `scripts/`, `assets/` siblings.
- Description-as-trigger discipline (though OpenCode reads the description AFTER the agent decides to call, not before).

What is per-harness:

- Hooks (every harness has its own format and event set).
- Plugin manifests (Claude Code `.claude-plugin/plugin.json`, Cursor `.cursor-plugin/plugin.json`, OpenCode JS plugin, Codex `agents/openai.yaml`, Gemini `gemini-extension.json`).
- Per-platform install paths.
- Subagent / fork semantics.
- Always-on context format (`CLAUDE.md` vs `AGENTS.md` vs `GEMINI.md`).

The cross-platform-safe core is most of what matters for skill authoring. The harness-specific layer only matters if you publish for a specific harness with its specific extensions.

## Sources

- `LANDSCAPE` 1.4 (cross-platform comparison overview).
- `LANDSCAPE` 2.4 (OpenCode native Agent Skills, JS plugin model, explicit `skill` tool invocation).
- `LANDSCAPE` 2.5 (Cursor full plugin bundle, `.cursor-plugin/plugin.json`, hook events).
- `LANDSCAPE` 2.6 (Continue.dev as not directly Agent Skills compatible).
- `LANDSCAPE` 1.4 (Hermes agent, GitHub Copilot CLI v1.0.11+).

Cross-links: `docs/11-cross-platform/codex.md`, `docs/11-cross-platform/gemini-cli.md`.
