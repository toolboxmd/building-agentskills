# Gemini CLI: Agent Skills, hooks and extensions

Google's Gemini CLI (`google-gemini/gemini-cli`) supports Agent Skills natively. A spec-compliant `SKILL.md` loads without changes. This page covers how Gemini discovers and activates Skills, its hook system, how extensions package both, and where it differs from the [Agent Skills spec](https://agentskills.io).

Source: Gemini CLI docs at release `v0.61.0`, commit [`bb52374`](https://github.com/google-gemini/gemini-cli/tree/bb523741c7429a44d03e964bc124c7c92df59d5f) (tagged 2026-09-23), read 2026-09-29. Gemini CLI was not installed on the checking machine, so nothing on this page was run.

## Skill discovery

Gemini CLI reads Skills from four tiers, lowest precedence first ([`docs/cli/skills.md`](https://github.com/google-gemini/gemini-cli/blob/bb523741c7429a44d03e964bc124c7c92df59d5f/docs/cli/skills.md)):

1. **Built-in.** Skills shipped with Gemini CLI.
2. **Extension.** `skills/<name>/SKILL.md` inside an installed extension.
3. **User.** `~/.gemini/skills/` or the `~/.agents/skills/` alias.
4. **Workspace.** `.gemini/skills/` or the `.agents/skills/` alias.

When two Skills share a name, the higher tier wins. Within the user or workspace tier, `.agents/skills/` wins over `.gemini/skills/`. The `.agents/skills/` alias is the same path Codex and OpenCode read, so one checked-in Skill directory serves all three.

`gemini skills install <git-url-or-path>`, `gemini skills list` and the `/skills` slash command manage them.

## Activation

The lifecycle from [`docs/cli/skills.md`](https://github.com/google-gemini/gemini-cli/blob/bb523741c7429a44d03e964bc124c7c92df59d5f/docs/cli/skills.md):

1. **Discovery.** At session start, Gemini CLI puts the name and description of every enabled Skill into the system prompt.
2. **Activation.** When the model matches a task to a description, it calls the `activate_skill` tool with the Skill's name. Only the model calls this tool; the user cannot ([`docs/tools/activate-skill.md`](https://github.com/google-gemini/gemini-cli/blob/bb523741c7429a44d03e964bc124c7c92df59d5f/docs/tools/activate-skill.md)).
3. **Consent.** The user sees a confirmation prompt naming the Skill and the directory it will gain access to.
4. **Injection.** On approval, the `SKILL.md` body and the Skill's folder structure enter the conversation, and the Skill directory is added to the agent's allowed file paths.

Progressive disclosure therefore works as the spec describes: descriptions are always in context, bodies load on activation, and bundled `scripts/`, `references/` and `assets/` are read on demand ([`docs/cli/creating-skills.md`](https://github.com/google-gemini/gemini-cli/blob/bb523741c7429a44d03e964bc124c7c92df59d5f/docs/cli/creating-skills.md)).

## Differences from the Agent Skills spec

- **Only `name` and `description` are read.** The loader parses those two fields and ignores the rest ([`skillLoader.ts`](https://github.com/google-gemini/gemini-cli/blob/bb523741c7429a44d03e964bc124c7c92df59d5f/packages/core/src/skills/skillLoader.ts#L41-L61)). `license`, `compatibility`, `metadata` and every Claude Code extension field (`paths`, `disable-model-invocation`, `allowed-tools`) have no effect.
- **Activation needs user consent.** In an interactive session each activation asks the user first. A Skill that must load unattended needs that prompt accounted for.
- **No listing budget is documented.** The docs state that every enabled Skill's name and description is injected; they give no cap.

For description-writing guidance from Google, see [`docs/cli/skills-best-practices.md`](https://github.com/google-gemini/gemini-cli/blob/bb523741c7429a44d03e964bc124c7c92df59d5f/docs/cli/skills-best-practices.md).

## Hooks

Gemini CLI runs command hooks configured in `settings.json` at project (`.gemini/settings.json`), user, system and extension level ([`docs/hooks/index.md`](https://github.com/google-gemini/gemini-cli/blob/bb523741c7429a44d03e964bc124c7c92df59d5f/docs/hooks/index.md)). The event names differ from Claude Code's:

| Gemini CLI event | Nearest Claude Code event | Can add model context |
|---|---|---|
| `SessionStart` | `SessionStart` | Yes: interactive sessions get it as the first history turn; non-interactive runs get it prepended to the prompt |
| `BeforeAgent` | `UserPromptSubmit` | Yes: appended to the prompt for that turn |
| `BeforeTool` | `PreToolUse` | No: it can block or rewrite the call |
| `AfterTool` | `PostToolUse` | Yes: appended to the tool result |
| `AfterAgent`, `BeforeModel`, `AfterModel`, `BeforeToolSelection`, `PreCompress`, `SessionEnd`, `Notification` | Various | See the reference |

The context column comes from [`docs/hooks/reference.md`](https://github.com/google-gemini/gemini-cli/blob/bb523741c7429a44d03e964bc124c7c92df59d5f/docs/hooks/reference.md). Hooks return JSON on stdout; any other stdout text breaks parsing, and the CLI then allows the action and shows the text as a system message. Timeouts are in milliseconds (default 60,000).

## Extensions

An extension is a directory under `~/.gemini/extensions/<name>/` with a required `gemini-extension.json` manifest ([`docs/extensions/reference.md`](https://github.com/google-gemini/gemini-cli/blob/bb523741c7429a44d03e964bc124c7c92df59d5f/docs/extensions/reference.md)). It can bundle:

- a context file (`GEMINI.md` by default, named by `contextFileName`), loaded every session;
- custom commands in `commands/*.toml` (`commands/gcs/sync.toml` becomes `/gcs:sync`);
- Skills in `skills/<name>/SKILL.md`;
- hooks in `hooks/hooks.json` (not in the manifest);
- subagents in `agents/`, MCP servers and themes.

An extension is Gemini's plugin: it is the unit a user installs, and Skills inside it load through the extension tier above.

## Always-on context costs every session

`GEMINI.md`, including files it pulls in with `@file.md` imports ([`docs/cli/gemini-md.md`](https://github.com/google-gemini/gemini-cli/blob/bb523741c7429a44d03e964bc124c7c92df59d5f/docs/cli/gemini-md.md)), is always-on context, like `CLAUDE.md` or `AGENTS.md`. Put procedures in a Skill, where only the description is paid every session, and keep `GEMINI.md` for rules that apply to every turn. See [Token economics](/docs/04-token-economics) for the arithmetic.

## Sources

- Gemini CLI docs and source at `v0.61.0` ([`bb52374`](https://github.com/google-gemini/gemini-cli/tree/bb523741c7429a44d03e964bc124c7c92df59d5f)), read 2026-09-29: Skills, `activate_skill`, creating Skills, hooks index and reference, extensions reference, `GEMINI.md`, `skillLoader.ts`.

Cross-links: [Other harnesses](/docs/11-cross-platform/others), [Codex](/docs/11-cross-platform/codex), [Token economics](/docs/04-token-economics).
