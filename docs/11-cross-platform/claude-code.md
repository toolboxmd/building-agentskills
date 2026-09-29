# Claude Code: Skill scopes, listing budget, hooks and headless runs

This page covers Claude Code behavior that other harnesses do not share: where Skills load, how the Skill listing is budgeted, which hook output reaches the model, and the permission and sandbox settings that matter for headless runs. The cross-platform core lives in the rest of the docs.

Checked against Claude Code `2.1.284` (`claude --version` and `claude plugin --help`, 2026-09-29) and the Claude Code docs at code.claude.com, read 2026-09-29: [Skills](https://code.claude.com/docs/en/skills), [Hooks](https://code.claude.com/docs/en/hooks), [Permission modes](https://code.claude.com/docs/en/permission-modes), [Permissions](https://code.claude.com/docs/en/permissions), [Headless](https://code.claude.com/docs/en/headless), [Sandboxing](https://code.claude.com/docs/en/sandboxing), [Plugins reference](https://code.claude.com/docs/en/plugins-reference).

## Where Skills load and which one wins

From the [Skills docs](https://code.claude.com/docs/en/skills):

| Location | Path |
|---|---|
| Enterprise | `.claude/skills/<skill-name>/SKILL.md` in the managed settings directory |
| Personal | `~/.claude/skills/<skill-name>/SKILL.md` |
| Project | `.claude/skills/<skill-name>/SKILL.md` |
| Nested | `<subdir>/.claude/skills/<skill-name>/SKILL.md`, loaded once Claude works on files there |
| Additional directory | `.claude/skills/` inside a directory passed with `--add-dir` |
| Plugin | `<plugin>/skills/<skill-name>/SKILL.md`, invoked as `/plugin-name:skill-name` |

When enterprise, personal and project Skills share a name, enterprise wins over personal, and personal over project. A plugin Skill and a same-named Skill at any other location both load, because the plugin Skill is namespaced.

A Skill entry can be a symlink to a directory elsewhere. The karpathy-wiki development setup symlinks `~/.claude/skills/<name>/` to a checkout, so edits land without a plugin reinstall. If the plugin is also installed, the model sees both the personal Skill and the `/plugin-name:<name>` Skill; disable one of them while developing.

## The Skill listing budget

Claude Code lists every Skill's name, plus its `description` and `when_to_use` text, in context ([Skills docs](https://code.claude.com/docs/en/skills)):

- Each entry's combined `description` and `when_to_use` is cut at 1,536 characters (`skillListingMaxDescChars` changes it).
- The whole listing gets 1% of the model's context window (`skillListingBudgetFraction`, or a fixed character count in `SLASH_COMMAND_TOOL_CHAR_BUDGET`).
- When the listing overflows, Claude Code drops descriptions of the least-invoked Skills first; names always stay. `/doctor` estimates the cost, and `--debug` logs the overflow.
- A Skill with `disable-model-invocation: true` has no description in context at all.

Put the trigger first in the description: the cap cuts from the end.

## Hook output that reaches the model

Hooks pass text to Claude through `hookSpecificOutput.additionalContext`, which Claude Code wraps in a system reminder ([Hooks docs](https://code.claude.com/docs/en/hooks)). The events a Skill author most often uses:

| Event | Where the context lands |
|---|---|
| `SessionStart` | Start of the conversation, before the first prompt |
| `UserPromptSubmit` | Alongside the submitted prompt |
| `PreToolUse` | Alongside the tool result, so after the call runs |
| `PostToolUse` | Alongside the tool result |

`UserPromptExpansion`, `PostToolUseFailure`, `SubagentStart` and `Stop` also accept it. Plain-text stdout reaches Claude from `SessionStart`, `UserPromptSubmit`, `UserPromptExpansion` and `PostModelSwitch` hooks.

**Output cap.** Each `additionalContext`, `systemMessage` or `initialUserMessage` string, and a hook's plain stdout, is capped at 10,000 characters, measured per string. Over the cap, Claude Code saves the output to a file in the session directory and passes the file path with a preview of the first 2,000 characters. No setting raises the cap, and Claude is not asked to read the file, so keep anything the model must see under 10,000 characters. AgentsMD's hooks reserve 10% headroom under this and the other hosts' limits ([toolboxmd/agentsmd#179](https://github.com/toolboxmd/agentsmd/pull/179)).

## SessionStart-hook injection

A SessionStart hook can read a file, escape it for JSON, and emit it as `hookSpecificOutput.additionalContext`. The model then has the text before its first turn, and the text costs its full size in input tokens every session, whether or not the Skill is used. A plugin registers the hook in `hooks/hooks.json`; the matcher selects `startup`, `resume`, `clear`, `compact` or `fork`.

Keep the injected text small and measure it; the 10,000-character cap above bounds it. For when injection pays off (a full bootstrap Skill, or a short pointer that makes a Skill load), see [Token economics](/docs/04-token-economics).

## Headless runs: `-p` and permission modes

In `claude -p`, no one can answer a permission prompt, so any call that would prompt is denied and listed in `permission_denials` of the stream-JSON result ([Headless docs](https://code.claude.com/docs/en/headless)). With `--permission-mode acceptEdits`:

- Reads inside the working directory and `--add-dir` directories run. Reads outside them need approval, so `-p` denies them ([Permissions docs](https://code.claude.com/docs/en/permissions)). A Skill or plugin copy outside the working directory needs its own `--add-dir`.
- File edits in those directories run, as do `mkdir`, `touch`, `rm`, `rmdir`, `mv`, `cp` and `sed` on in-scope paths ([Permission modes docs](https://code.claude.com/docs/en/permission-modes)).
- Other Bash commands, such as `git commit` or a test run, need approval, so `-p` denies them. The AgentsMD trigger harness saw every `git checkout -b`, test and commit denied this way on Claude Code 2.1.284 ([toolboxmd/agentsmd#179](https://github.com/toolboxmd/agentsmd/pull/179)), and added `--allowedTools Bash` with the sandbox below ([toolboxmd/agentsmd#183](https://github.com/toolboxmd/agentsmd/pull/183)).

A harness that counts Skill reads must score denied reads as failures, not as reads; [toolboxmd/agentsmd#179](https://github.com/toolboxmd/agentsmd/pull/179) found earlier runs had scored refused reads as successes.

## The Bash sandbox

The OS-level sandbox confines the commands Claude runs through Bash, not Claude Code's own process ([Sandboxing docs](https://code.claude.com/docs/en/sandboxing)). Enforcement is Seatbelt on macOS. Defaults once `sandbox.enabled` is `true`:

- **Writes:** the working directory and its subdirectories, `--add-dir` and `permissions.additionalDirectories` directories, and the per-user temp directory in `$TMPDIR`.
- **Reads:** the whole computer except certain denied directories. This still includes credential files such as `~/.aws/credentials` and `~/.ssh/`.

The keys:

| Key | Effect |
|---|---|
| `sandbox.enabled` | Turns the sandbox on |
| `sandbox.allowUnsandboxedCommands` | `false` removes the escape hatch that reruns a command outside the sandbox |
| `sandbox.failIfUnavailable` | `true` fails instead of silently running unsandboxed when the sandbox cannot start |
| `sandbox.excludedCommands` | Commands that always run unsandboxed |
| `sandbox.filesystem.allowWrite` | Extra writable paths |
| `sandbox.filesystem.denyWrite`, `sandbox.filesystem.denyRead` | Blocked paths |
| `sandbox.filesystem.allowRead` | Re-opens a path inside a `denyRead` region; the narrower rule wins |
| `sandbox.filesystem.disabled` | Drops filesystem isolation, keeps network isolation |
| `sandbox.credentials` | Credential files and environment variables to hide from sandboxed commands |
| `sandbox.network` | Network allowlist |

Because reads default to the whole computer, confining a harness needs `denyRead` as well as the write defaults. AgentsMD's harness denies the real home and re-allows only the temporary home, with `allowUnsandboxedCommands: false` and `failIfUnavailable: true`; smoke runs on Claude Code 2.1.284 showed reads and writes outside the confinement fail with `Operation not permitted` ([toolboxmd/agentsmd#183](https://github.com/toolboxmd/agentsmd/pull/183)).

## `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_SKILL_DIR}`

Claude Code substitutes `${CLAUDE_SKILL_DIR}` in any Skill's Markdown body, and `${CLAUDE_PLUGIN_ROOT}` in a plugin Skill's body, when it loads the content. Neither variable exists in the environment of Bash commands Claude runs ([Plugins reference](https://code.claude.com/docs/en/plugins-reference#where-each-variable-resolves)). Grok Build substitutes both; Codex, OpenCode and Gemini CLI do not ([Other harnesses](/docs/11-cross-platform/others)). Full discussion in [Packaging as a plugin: the `${CLAUDE_PLUGIN_ROOT}` gotcha](/docs/08-packaging-as-plugin#the-claude_plugin_root-gotcha).

## Invocation: `disable-model-invocation` and `user-invocable`

From the [Skills docs](https://code.claude.com/docs/en/skills):

- **`disable-model-invocation: true`**: only the user can invoke, and the description is not in context. Use for side-effecting workflows: `/deploy`, `/release`, `/commit`.
- **`user-invocable: false`**: only the model can invoke; the Skill is hidden from the `/` menu. Use for background knowledge the user should not need to call.

| disable-model-invocation | user-invocable | Who can invoke | Example |
|---|---|---|---|
| false (default) | true (default) | Model and user | Most Skills |
| true | true (default) | User only | `/deploy`, `/release` |
| false (default) | false | Model only | Background discipline Skills |
| true | false | Neither | Effectively disabled |

Leave both at the default unless you need one of the constrained combinations. This is Question 1 of [Three questions](/docs/03-three-questions): decide it explicitly. Grok Build reads both fields too ([Other harnesses](/docs/11-cross-platform/others)).

## `paths:` as an activation gate

`paths:` takes glob patterns. From the [Skills docs](https://code.claude.com/docs/en/skills): "When set, Claude loads the skill automatically only when working with files matching the patterns."

```yaml
paths: ["**/*.md"]
```

The Skill loads only when the agent works with Markdown files. A file-match gate is more reliable than description matching. Grok Build implements `paths:` the same way; Codex, OpenCode and Gemini CLI ignore the field.

See [Frontmatter reference](/docs/05-authoring/frontmatter) for the field reference and [Mechanism vs decoration](/docs/07-mechanism-vs-decoration) for the broader pattern.

## Sources

- Claude Code 2.1.284 CLI, 2026-09-29.
- Claude Code docs, read 2026-09-29: [Skills](https://code.claude.com/docs/en/skills), [Hooks](https://code.claude.com/docs/en/hooks), [Permission modes](https://code.claude.com/docs/en/permission-modes), [Permissions](https://code.claude.com/docs/en/permissions), [Headless](https://code.claude.com/docs/en/headless), [Sandboxing](https://code.claude.com/docs/en/sandboxing), [Plugins reference](https://code.claude.com/docs/en/plugins-reference).
- AgentsMD trigger-harness evidence: [toolboxmd/agentsmd#179](https://github.com/toolboxmd/agentsmd/pull/179) (merged at `3fa82c0`), [toolboxmd/agentsmd#183](https://github.com/toolboxmd/agentsmd/pull/183) (merged at `588d713`).

Cross-links: [Token economics](/docs/04-token-economics), [Packaging as a plugin](/docs/08-packaging-as-plugin).
