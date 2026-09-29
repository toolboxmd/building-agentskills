# Codex: Skills, plugins, hooks and the agents/openai.yaml sidecar

OpenAI's Codex CLI (`openai/codex`) supports the Agent Skills format natively, adds an optional Codex-specific sidecar, and packages Skills and hooks in plugins. This page covers what is portable and what is Codex-specific.

Checked against Codex CLI `0.159.0` (`codex --version` and `--help` on 2026-09-29), its source at tag `rust-v0.159.0` ([`687a119`](https://github.com/openai/codex/tree/687a119f0fcaace47e1f1abcc77cec6c813fd6da)), and the Codex docs at [developers.openai.com/codex/skills](https://developers.openai.com/codex/skills) and [developers.openai.com/codex/hooks](https://developers.openai.com/codex/hooks), read 2026-09-29.

## Where Codex reads Skills

From the [Skills docs](https://developers.openai.com/codex/skills):

| Scope | Location |
|---|---|
| Repository | `.agents/skills/` in every directory from the working directory up to the repository root |
| User | `$HOME/.agents/skills/` |
| Admin | `/etc/codex/skills/` |
| System | Bundled with Codex |

Plugins add their own `skills/` directories (see [Plugins](#plugins-and-marketplaces)). When two Skills share a name, Codex does not merge them; both can appear in Skill selectors.

A spec-compliant `SKILL.md` (see [Frontmatter reference](/docs/05-authoring/frontmatter)) loads without changes. The Codex docs define `name` and `description` as the frontmatter fields; Claude Code extension fields such as `paths` and `disable-model-invocation` are not part of Codex's Skill format.

## The Skill listing budget

Codex starts each session with a list of every Skill's name, description and file path. The list uses at most 2% of the model's context window, or 8,000 characters when the window is unknown. When Skills do not fit, Codex shortens descriptions first, then omits Skills from the list and shows a warning ([Skills docs](https://developers.openai.com/codex/skills); constants in [`render.rs`](https://github.com/openai/codex/blob/687a119f0fcaace47e1f1abcc77cec6c813fd6da/codex-rs/ext/skills/src/render.rs#L19-L23)). Each description is also cut at 1,024 characters in the list. `[skills] max_context_tokens` in `config.toml` overrides the budget, capped at 10,000 tokens.

The budget covers only the initial list. A selected Skill's body loads in full.

## Invocation

Codex supports implicit invocation (the model matches the task to a description) and explicit invocation (`/skills`, or `$skill-name` in the prompt).

`policy.allow_implicit_invocation` in the optional `agents/openai.yaml` sidecar defaults to `true`. Set it to `false` to stop implicit invocation; explicit `$skill-name` still works.

## The optional sidecar: `agents/openai.yaml`

Codex-specific metadata lives in `agents/openai.yaml` inside the Skill directory. It is optional; a Skill works without it. The [Skills docs](https://developers.openai.com/codex/skills) list three sections:

- **`interface`.** `display_name`, `short_description`, `icon_small`, `icon_large`, `brand_color`, `default_prompt`. Codex and the ChatGPT desktop app show these.
- **`policy.allow_implicit_invocation`.** Boolean, default `true`.
- **`dependencies.tools`.** Tools the Skill depends on, such as an MCP server.

Example, following the documented shape:

```yaml
interface:
  display_name: "My Wiki Skill"
  short_description: "Answer questions from the project wiki"
  brand_color: "#3366cc"
  default_prompt: "Use the wiki to answer this question."

policy:
  allow_implicit_invocation: true

dependencies:
  tools:
    - type: "mcp"
      value: "openaiDeveloperDocs"
      description: "OpenAI Docs MCP server"
      transport: "streamable_http"
      url: "https://developers.openai.com/mcp"
```

Other harnesses do not read this file, so the Skill stays portable.

## Plugins and marketplaces

A Codex plugin bundles Skills, hooks and MCP configuration. Its manifest is `.codex-plugin/plugin.json`; a marketplace lists plugins in `.agents/plugins/marketplace.json` ([`loader.rs`](https://github.com/openai/codex/blob/687a119f0fcaace47e1f1abcc77cec6c813fd6da/codex-rs/core-plugins/src/loader.rs#L471)). From `codex plugin --help` (0.159.0):

```sh
codex plugin marketplace add <local-path-or-git-source>
codex plugin add <plugin>@<marketplace>
codex plugin list
codex plugin remove <plugin>
```

## Hooks

Codex runs lifecycle hooks from `hooks.json` or inline `[hooks]` tables next to each config layer (`~/.codex/`, `<repo>/.codex/`) and from enabled plugins ([Hooks docs](https://developers.openai.com/codex/hooks)).

**Trust review.** Before a non-managed hook runs, the user must review and trust its exact definition in `/hooks`. Codex records trust against the hook's hash, so a new or changed hook, including one shipped in a plugin update, is skipped until trusted again. Project hooks load only when the project's `.codex/` layer is trusted. `--dangerously-bypass-hook-trust` runs enabled hooks without stored trust for one invocation.

**Model-visible context.** `hookSpecificOutput.additionalContext` reaches the model as extra developer context on `SessionStart`, `UserPromptSubmit`, `SubagentStart`, `PreToolUse` and `PostToolUse`. PreToolUse context was requested in [openai/codex#19385](https://github.com/openai/codex/issues/19385) (closed as completed 2026-08-04) and is documented and implemented in 0.159.0.

**Output limit.** By default Codex limits each model-visible hook-output message to about 2,500 tokens ([`output_spill.rs`](https://github.com/openai/codex/blob/687a119f0fcaace47e1f1abcc77cec6c813fd6da/codex-rs/hooks/src/output_spill.rs#L12)). Longer output is saved under a temporary `hook_outputs/` directory and the model gets a head-and-tail preview with the file path. A command hook's `additionalContextLimit` changes the threshold; `0` passes the full text.

Hooks are configured per harness or per plugin, not per Skill.

## Subagents

Subagents are on by default in 0.159.0: `multi_agent` is a stable feature with `default_enabled: true` ([`features/src/lib.rs`](https://github.com/openai/codex/blob/687a119f0fcaace47e1f1abcc77cec6c813fd6da/codex-rs/features/src/lib.rs#L1328-L1331); `codex features list` shows `multi_agent stable true`). The older advice to set `[features] multi_agent = true` is no longer needed. Claude Code's `context: fork` Skill field has no documented Codex equivalent, so test a Skill that relies on it on Codex before claiming support.

## Persistent context

Codex reads `AGENTS.md`; Claude Code reads `CLAUDE.md`. Some authors symlink one to the other; others keep both. `AGENTS.md` is not a Skill; it is always-on memory. See [Mental model](/docs/02-mental-model).

## What Codex does not share with Claude Code

- **No `${CLAUDE_PLUGIN_ROOT}` or `${CLAUDE_SKILL_DIR}` substitution in Skill bodies.** Codex sets `CLAUDE_PLUGIN_ROOT` only in the environment of plugin hooks ([`discovery.rs`](https://github.com/openai/codex/blob/687a119f0fcaace47e1f1abcc77cec6c813fd6da/codex-rs/hooks/src/engine/discovery.rs#L267)). In a Skill, refer to bundled files by paths relative to the Skill directory; the listing gives the model each Skill's file path.
- **No Claude Code frontmatter extensions.** `when_to_use`, `disable-model-invocation`, `user-invocable`, `paths`, `model` and `effort` are Claude Code fields. Use `agents/openai.yaml` for Codex-specific behavior.

## Sources

- Codex CLI 0.159.0: `codex --version`, `codex plugin --help`, `codex plugin marketplace --help`, `codex plugin add --help`, `codex features list`, run 2026-09-29.
- `openai/codex` at `rust-v0.159.0` ([`687a119`](https://github.com/openai/codex/tree/687a119f0fcaace47e1f1abcc77cec6c813fd6da)): Skill listing budget, hook output limit, plugin manifest paths, feature defaults.
- [Codex Skills docs](https://developers.openai.com/codex/skills) and [Codex hooks docs](https://developers.openai.com/codex/hooks), read 2026-09-29.

Cross-links: [Other harnesses](/docs/11-cross-platform/others), [Claude Code](/docs/11-cross-platform/claude-code).
