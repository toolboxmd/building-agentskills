# Other harnesses: Grok Build, OpenCode, Cursor, Hermes, Continue.dev, Copilot CLI

This page covers the harnesses without their own page. Grok Build and OpenCode were re-checked on 2026-09-29 against their source, docs and installed CLIs. Cursor, Hermes, Continue.dev and Copilot CLI were last checked 2026-04 (`LANDSCAPE` 1.4, 2.5, 2.6) and may be out of date.

## Grok Build (`xai-org/grok-build`)

Checked against `grok 1.0.44 (5b807183dd79) [stable]` (`grok --version` and `--help`, 2026-09-29) and the `xai-org/grok-build` repository at [`97f190f`](https://github.com/xai-org/grok-build/tree/97f190f644ae1ba07fd6ee185ef54c650e142666) (2026-09-29), which ships the user guide bundled with the CLI. Links below abbreviate `crates/codegen/xai-grok-pager/docs/user-guide/` as the user guide.

### Skills

Grok reads `SKILL.md` directories from `.grok/skills/`, `.agents/skills/`, `.claude/skills/` and `.cursor/skills/` at the working directory, every directory up to the repository root, and the matching user directories under `~` ([user guide, Skills](https://github.com/xai-org/grok-build/blob/97f190f644ae1ba07fd6ee185ef54c650e142666/crates/codegen/xai-grok-pager/docs/user-guide/08-skills.md)). A higher-priority location overrides a same-named Skill. A plugin Skill never overrides a native one; it stays available as `/plugin-name:skill-name`. Grok reads the Claude Code fields `when-to-use`, `disable-model-invocation`, `user-invocable`, `allowed-tools`, `model` and `effort`.

Project Skills, project `AGENTS.md`, project hooks and project MCP servers load only in a trusted folder. Without trust, `grok -p` skips them silently; an interactive session asks first. `grok --trust inspect` records the grant without a model call, and one grant covers the repository's subdirectories and worktrees. Source: [user guide, Hooks](https://github.com/xai-org/grok-build/blob/97f190f644ae1ba07fd6ee185ef54c650e142666/crates/codegen/xai-grok-pager/docs/user-guide/10-hooks.md#L79-L81) and [Project rules](https://github.com/xai-org/grok-build/blob/97f190f644ae1ba07fd6ee185ef54c650e142666/crates/codegen/xai-grok-pager/docs/user-guide/12-project-rules.md#L3); observed on Grok 1.0.44 in [toolboxmd/agentsmd#167](https://github.com/toolboxmd/agentsmd/issues/167), fixed in [toolboxmd/agentsmd#188](https://github.com/toolboxmd/agentsmd/pull/188).

### The Skill listing

Grok delivers the Skill listing as a `<system-reminder>` ([`listing.rs`](https://github.com/xai-org/grok-build/blob/97f190f644ae1ba07fd6ee185ef54c650e142666/crates/codegen/xai-grok-tools/src/types/skill_discovery_tracker/listing.rs#L1-L22)):

- The listing may use 50% of the context window (800,000 characters when the window is unknown).
- Each entry's `description` plus `when-to-use` is capped at 400 bytes, split between the two fields.
- If the budget still overflows, Grok shortens descriptions, then falls back to names only (below 20 characters per description), then drops entries.

So a Grok description has a much smaller per-entry cap than Claude Code's 1,536 characters: put the trigger in the first 400 bytes.

### `paths:` conditional Skills

A Skill with `paths:` globs is held out of the listing until a tool touches a matching file, then activated for the rest of the session ([`conditional.rs`](https://github.com/xai-org/grok-build/blob/97f190f644ae1ba07fd6ee185ef54c650e142666/crates/codegen/xai-grok-tools/src/types/skill_discovery_tracker/conditional.rs#L10-L60)). This matches Claude Code's `paths:` behavior; `paths:` is not Claude Code-only.

### Plugins

A Grok plugin holds any of `skills/`, `commands/`, `agents/`, `hooks/hooks.json`, `.mcp.json` and `.lsp.json`, with an optional `plugin.json` manifest. A marketplace indexes plugins in `.grok-plugin/marketplace.json`; Grok also accepts the `.claude-plugin/` equivalents ([user guide, Plugins](https://github.com/xai-org/grok-build/blob/97f190f644ae1ba07fd6ee185ef54c650e142666/crates/codegen/xai-grok-pager/docs/user-guide/09-plugins.md#L185)).

```sh
grok plugin marketplace add <owner/repo>
grok plugin install <name> --trust
```

Without `--trust`, `grok plugin install` shows the source, warns that it activates the plugin's hooks, MCP servers and Skills, and stops.

### Hooks

Hooks use Claude Code's event names and output vocabulary, and Grok also reads `~/.claude/settings.json` and project `.claude/settings.json` hooks ([user guide, Hooks](https://github.com/xai-org/grok-build/blob/97f190f644ae1ba07fd6ee185ef54c650e142666/crates/codegen/xai-grok-pager/docs/user-guide/10-hooks.md)). What reaches the model differs:

- `SessionStart` and `Notification` stdout is ignored (:505). An allowing `UserPromptSubmit` hook's output is discarded.
- A `PreToolUse` hook's `additionalContext` reaches the model after the tool call has run, with that batch's results, never before (:312).
- `PostToolUse` can add `additionalContext` or replace the tool output the model sees.
- `additionalContext` is clipped at 10,000 characters.

The user guide lists plugin hooks as a source once the plugin is trusted (:75). AgentsMD found that Grok 1.0.34 did not run plugin-provided hooks and has not retested later versions, so it installs a global `~/.grok/hooks/` file that delivers context on `PreToolUse` ([AgentsMD README at `06b7af6`](https://github.com/toolboxmd/agentsmd/blob/06b7af6233322bc14eaa15b0cf2981d55e0575d0/README.md)). Test plugin hooks on the Grok version you target.

### Headless runs

`grok -p "<prompt>"` runs one turn. `--always-approve` auto-approves every tool call. `--sandbox workspace` lets the agent read everywhere and write only to the working directory, `~/.grok/` and temporary directories ([user guide, Sandbox](https://github.com/xai-org/grok-build/blob/97f190f644ae1ba07fd6ee185ef54c650e142666/crates/codegen/xai-grok-pager/docs/user-guide/18-sandbox.md)). The AgentsMD trigger harness ran Grok with `--always-approve --sandbox workspace` ([`trigger_test.py` at `06b7af6`](https://github.com/toolboxmd/agentsmd/blob/06b7af6233322bc14eaa15b0cf2981d55e0575d0/docs/work/164-trigger-audit/trigger_test.py)).

## OpenCode (`anomalyco/opencode`, formerly `sst/opencode`)

Checked against OpenCode `1.18.33` (`opencode --version`, 2026-09-29), its source and docs at tag `v1.18.33` ([`51ef4be`](https://github.com/anomalyco/opencode/tree/51ef4be1d3c122f18fefb510dca8d778571f4f18)), and [opencode.ai/docs/skills](https://opencode.ai/docs/skills), read 2026-09-29.

### Skills

OpenCode reads Skills from ([`skills.mdx`](https://github.com/anomalyco/opencode/blob/51ef4be1d3c122f18fefb510dca8d778571f4f18/packages/web/src/content/docs/skills.mdx)):

- `.opencode/skills/`, `.claude/skills/` and `.agents/skills/`, walking up from the working directory to the git worktree root;
- the global config directory's `skills/`, which is `$XDG_CONFIG_HOME/opencode/skills` (default `~/.config/opencode/skills`; [`global.ts`](https://github.com/anomalyco/opencode/blob/51ef4be1d3c122f18fefb510dca8d778571f4f18/packages/core/src/global.ts#L13));
- `~/.claude/skills/` and `~/.agents/skills/`;
- directories listed in `skills.paths` in `opencode.json`.

OpenCode recognizes only `name`, `description`, `license`, `compatibility` and `metadata`; it ignores other fields. `name` must match the directory name.

### The `skill` tool lists every Skill

OpenCode puts every available Skill's name and description into the description of its native `skill` tool, as an `<available_skills>` block. The model loads one by calling `skill({ name: "..." })`. So the model sees each description before it decides to call, as on the other hosts; the earlier claim that OpenCode reads the description only after the call was wrong. Skills denied by `permission.skill` are left out of the list.

### Permissions

Most permissions default to `allow`; `external_directory` and `doom_loop` default to `ask` ([`permissions.mdx`](https://github.com/anomalyco/opencode/blob/51ef4be1d3c122f18fefb510dca8d778571f4f18/packages/web/src/content/docs/permissions.mdx)). `external_directory` covers any tool call that touches a path outside the working directory, including a read of a Skill's bundled files.

A Skill installed as a symlink in the config directory is read through the link's path, not its target. The AgentsMD harness denied external directories except the plugin copy, and OpenCode's reads of Skill procedures through the config-directory link were refused until the config directory was allowed too ([toolboxmd/agentsmd#179](https://github.com/toolboxmd/agentsmd/pull/179)). Allow both the link location and its target.

### Plugins

OpenCode plugins are JavaScript or TypeScript modules in `.opencode/plugins/` or `~/.config/opencode/plugins/`, or npm packages listed under `plugin` in `opencode.json` ([`plugins.mdx`](https://github.com/anomalyco/opencode/blob/51ef4be1d3c122f18fefb510dca8d778571f4f18/packages/web/src/content/docs/plugins.mdx)). The hooks relevant to Skills ([`index.ts`](https://github.com/anomalyco/opencode/blob/51ef4be1d3c122f18fefb510dca8d778571f4f18/packages/plugin/src/index.ts#L266-L296)):

- `experimental.chat.system.transform` edits the system prompt of each request. AgentsMD uses it to append Project Direction and its routing pointer ([`agentsmd-project-direction.js` at `06b7af6`](https://github.com/toolboxmd/agentsmd/blob/06b7af6233322bc14eaa15b0cf2981d55e0575d0/opencode/agentsmd-project-direction.js)). It is not in the published plugin docs.
- `experimental.chat.messages.transform` edits the message list.
- `tool.execute.before` sees and can change a tool call's arguments, or throw to block it; `tool.execute.after` sees the result.

OpenCode has no Skill-scoped hooks; hook-shaped behavior lives in plugins.

## Cursor (last checked 2026-04)

Cursor supports Agent Skills natively, plus a plugin model that bundles Skills, rules, commands, hooks and MCP servers.

The plugin manifest is `.cursor-plugin/plugin.json` with explicit per-component paths:

```json
{
  "skills": "./skills/",
  "agents": "./agents/",
  "commands": "./commands/",
  "hooks": "./hooks/hooks-cursor.json"
}
```

Cursor's hook events: SessionStart, beforeSubmitPrompt, PreToolUse, PostToolUse, Stop. Each hook config has a `matcher` regex and shell commands.

Invocation is implicit (description match) and explicit (`/skill-name`, `$skill-name`). A spec-compliant `SKILL.md` works without changes.

## Hermes Agent (last checked 2026-04)

Hermes is agentskills.io-compatible. Skills live at `~/.hermes/skills/[<category>/]<name>/`. Discovery is through the `skills_list` and `skill_view` tools.

Hermes hooks live in a plugin system at `~/.hermes/plugins/<name>/plugin.yaml`, with Python callbacks for events such as `pre_tool_call`, `post_tool_call`, `pre_llm_call`, `post_llm_call`, `on_session_start` and `on_session_end`.

## Continue.dev (last checked 2026-04)

Continue.dev uses `~/.continue/config.json` with custom commands. It was not Agent Skills-compatible when checked; a Skill had to be rewritten as a Continue command.

## GitHub Copilot CLI (last checked 2026-04)

As of v1.0.11, Copilot CLI supported `additionalContext` injection through a SessionStart hook (per superpowers v5.0.7 release notes) and read superpowers' marketplace through `copilot plugin marketplace add`. It had no native Agent Skills support when checked; the SessionStart bridge paid the full injected body every session.

## Convergence and divergence

Portable across Claude Code, Codex, Grok Build, OpenCode and Gemini CLI:

- A `SKILL.md` with the spec's frontmatter (`name`, `description`, optional `license`, `compatibility`, `metadata`).
- A plain Markdown body, with one-level `references/`, `scripts/` and `assets/` siblings.
- `.agents/skills/` as a project directory read by Codex, Grok Build, OpenCode and Gemini CLI; Claude Code reads `.claude/skills/`, which Grok Build and OpenCode also read.
- Description-based activation: every host shows the model each Skill's description before the model decides to load it. Listing caps differ per host (see each host's section).

Per host:

- Hooks: event names, which events reach the model, and output caps.
- Plugin manifests: Claude Code `.claude-plugin/plugin.json`, Codex `.codex-plugin/plugin.json`, Grok Build optional `plugin.json` with `.grok-plugin/marketplace.json`, OpenCode JavaScript modules, Gemini CLI `gemini-extension.json`, Cursor `.cursor-plugin/plugin.json`.
- Install paths, trust gates, and subagent semantics.
- Always-on context files (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`).

## Sources

- Grok Build: `grok` 1.0.44 CLI help; `xai-org/grok-build` at [`97f190f`](https://github.com/xai-org/grok-build/tree/97f190f644ae1ba07fd6ee185ef54c650e142666); [toolboxmd/agentsmd#167](https://github.com/toolboxmd/agentsmd/issues/167), [#188](https://github.com/toolboxmd/agentsmd/pull/188); read 2026-09-29.
- OpenCode: `opencode` 1.18.33; `anomalyco/opencode` at `v1.18.33` ([`51ef4be`](https://github.com/anomalyco/opencode/tree/51ef4be1d3c122f18fefb510dca8d778571f4f18)); [opencode.ai/docs/skills](https://opencode.ai/docs/skills); [toolboxmd/agentsmd#179](https://github.com/toolboxmd/agentsmd/pull/179); read 2026-09-29.
- AgentsMD harness and README at [`06b7af6`](https://github.com/toolboxmd/agentsmd/tree/06b7af6233322bc14eaa15b0cf2981d55e0575d0).
- Cursor, Hermes, Continue.dev, Copilot CLI: `LANDSCAPE` 1.4, 2.5, 2.6 (2026-04), not re-verified.

Cross-links: [Claude Code](/docs/11-cross-platform/claude-code), [Codex](/docs/11-cross-platform/codex), [Gemini CLI](/docs/11-cross-platform/gemini-cli).
