# Packaging as a plugin

This page covers Claude Code plugin packaging from the karpathy-wiki shape: minimal `.claude-plugin/plugin.json`, skills in `skills/<name>/SKILL.md`, optional sibling sub-directories, the symlink install pattern, and the `${CLAUDE_PLUGIN_ROOT}` substitution gotcha.

Cross-platform packaging (Codex, Grok Build, OpenCode, Gemini CLI, Cursor) is summarized [below](#cross-platform-manifests-brief) and covered in the cross-platform pages. This page is Claude Code-specific.

## The minimal plugin shape

A Claude Code plugin is a directory of components in standard locations. The manifest is optional: without it, Claude Code loads the components it finds and takes the plugin name from the marketplace entry or the directory name ([Plugins reference](https://code.claude.com/docs/en/plugins-reference), read 2026-09-29).

```
your-plugin/
├── .claude-plugin/
│   └── plugin.json                    # optional manifest; only `name` is required
├── skills/
│   └── <skill-name>/
│       ├── SKILL.md                   # required: the skill itself
│       ├── scripts/                   # optional: helper scripts
│       ├── references/                # optional: heavy reference docs
│       └── assets/                    # optional: data files, images
├── agents/                            # optional: subagent definitions
├── commands/                          # optional: slash commands
├── hooks/                             # optional: hook definitions
├── LICENSE                            # recommended
└── README.md                          # recommended
```

## Plugin manifest: `.claude-plugin/plugin.json`

A small manifest, following the shape of [karpathy-wiki's `plugin.json` at `d8107e7`](https://github.com/toolboxmd/karpathy-wiki/blob/d8107e727f4b585a9927cad813f90fda6b559ef3/.claude-plugin/plugin.json):

```json
{
  "name": "your-plugin",
  "version": "0.1.0",
  "description": "One-sentence description of what this plugin provides.",
  "author": { "name": "yourname" },
  "repository": "https://github.com/yourname/your-plugin",
  "license": "Apache-2.0"
}
```

Per the [Plugins reference](https://code.claude.com/docs/en/plugins-reference) (read 2026-09-29), `name` is the only required field. `author` is an object with a required `name` and optional `email` and `url`. A string `author` fails validation: Claude Code 2.1.284 then refuses to load the plugin, and Grok Build 1.0.44 installs it with no Skills, while Codex 0.159.0 accepts it ([loader case study](/case-studies/2026-09-30-loader-trigger-benchmark)). `version`, `description`, `repository`, `license` and `keywords` are optional; `claude plugin validate` warns when `version`, `description` or `author` is missing, and `--strict` turns those warnings into failures.

The `name` is the namespace prefix for your plugin's skills (Claude Code uses `plugin-name:skill-name` for namespacing). Pick a name that will not collide with other plugins.

The `version` follows semantic versioning. Note: a description-string change in your skills can break implicit triggering (the description is the activation contract); a description change is conceptually a major-version shift even if the body is unchanged. See [Evolution](/docs/09-evolution).

## Where skills live

Per Claude Code's docs, and as [karpathy-wiki's `skills/`](https://github.com/toolboxmd/karpathy-wiki/tree/d8107e727f4b585a9927cad813f90fda6b559ef3/skills) does: plugin skills live at `skills/<skill-name>/SKILL.md` relative to the plugin root.

Optional sibling sub-directories under each skill:

- **`scripts/`.** Helper scripts the SKILL.md invokes. The agent-skills spec convention (Layer 1).
- **`references/`.** Heavy reference docs loaded on demand. One level deep from SKILL.md; never nested. See [Line budget](/docs/05-authoring/line-budget).
- **`assets/`.** Data files, fixtures, images. Loaded as needed.

These sub-directories are optional directories in the [Agent Skills specification](https://agentskills.io/specification) (Layer 1). The spec does not require a harness to treat them specially: the model reads them with its ordinary file tools when the SKILL.md body points to them. They work on a host only if the model may read the Skill directory there; OpenCode's `external_directory` permission and Gemini CLI's activation consent are two such gates (see the [cross-platform pages](/docs/11-cross-platform/others)).

## Install paths

Claude Code recognizes plugins via:

- **Plugin marketplace.** Add one with `claude plugin marketplace add <url-path-or-github-repo>`, then install with `claude plugin install <name>` or `<name>@<marketplace>` (Claude Code 2.1.284 `--help`, 2026-09-29).
- **Local clone + symlink.** The pattern karpathy-wiki uses for development: `git clone` the plugin repo, then `ln -s <plugin-skill-dir> ~/.claude/skills/<name>` to make the skill available without going through the plugin system.
- **Direct copy.** `cp -r <plugin-skill-dir> ~/.claude/skills/<name>`. Less common; loses the link to upstream.

Name resolution for Claude Code skills ([Skills docs](https://code.claude.com/docs/en/skills), read 2026-09-29; see [Claude Code](/docs/11-cross-platform/claude-code)):

> enterprise > personal > project; plugin skills load alongside all of them

A skill at `~/.claude/skills/wiki/` (personal) wins over `.claude/skills/wiki/` (project). A plugin skill is namespaced as `/plugin-name:wiki`, so it never collides: a personal `wiki` and a plugin's `wiki` both load. During symlink development with the plugin also installed, the model sees both copies.

## The `${CLAUDE_PLUGIN_ROOT}` gotcha

Source: `REVIEWER` G3; the [Plugins reference: where each variable resolves](https://code.claude.com/docs/en/plugins-reference#where-each-variable-resolves), read 2026-09-29.

Claude Code substitutes `${CLAUDE_PLUGIN_ROOT}` with the plugin's installed path in `plugin.json` and `hooks.json` fields, MCP and LSP server configs, and the Markdown body of a skill, command or agent that the plugin provides. Hook, MCP and LSP processes also get it as an environment variable.

The variable is NOT in the environment of commands Claude runs through the Bash tool, and a skill loaded from outside the plugin gets no substitution. A SKILL.md that says:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/foo.sh"
```

works when the skill loads from the installed plugin, because Claude Code substitutes the path into the body. It fails with `No such file or directory` when the same skill loads as a personal skill (the symlink-install case) or on Codex, OpenCode or Gemini CLI, which do not substitute it. Grok Build substitutes it in plugin skills ([`skill.rs` at `97f190f`](https://github.com/xai-org/grok-build/blob/97f190f644ae1ba07fd6ee185ef54c650e142666/crates/codegen/xai-grok-tools/src/implementations/skills/skill.rs#L286-L310)). The literal string `${CLAUDE_PLUGIN_ROOT}` reaches Bash, expands to the empty string (Bash sees an unset variable), and the command becomes `bash /scripts/foo.sh`, which does not exist.

The failure is silent during plugin install; it surfaces only when someone installs the skill another way and invokes it.

Three workarounds:

1. **Use `${CLAUDE_SKILL_DIR}` instead.** Claude Code substitutes it with the skill's own directory in the body of any skill, plugin or not ([Skills docs](https://code.claude.com/docs/en/skills)). Grok Build substitutes it too ([`skill.rs` at `97f190f`](https://github.com/xai-org/grok-build/blob/97f190f644ae1ba07fd6ee185ef54c650e142666/crates/codegen/xai-grok-tools/src/implementations/skills/skill.rs#L286-L310)); Codex, OpenCode and Gemini CLI leave it literal, so pair it with workaround 3 for those hosts.
2. **Use a relative path.** `bash scripts/foo.sh` works if the skill's working directory is set to the skill's base directory. Some skills do `cd "$(dirname "$0")"` first; some rely on Claude Code setting `pwd` correctly.
3. **Compute the path explicitly.** From a SKILL.md prose preamble: "All script paths below are relative to this skill's base directory (shown at the top of the skill as `Base directory for this skill: ...`). `cd` into that directory before invoking any script, or prefix each script with the absolute base path." This is karpathy-wiki's chosen workaround.

The build-agentskills repo's loader skill follows convention 3 (use the base directory the harness prints in the preamble).

## Cross-platform manifests (brief)

Other harnesses use different manifest shapes:

- **Codex:** `.codex-plugin/plugin.json`, listed in a marketplace's `.agents/plugins/marketplace.json`; installed with `codex plugin marketplace add` and `codex plugin add` (Codex 0.159.0). The per-skill `agents/openai.yaml` sidecar is separate. See [Codex](/docs/11-cross-platform/codex).
- **Grok Build:** an optional `plugin.json` next to `skills/`, `hooks/hooks.json` and `.mcp.json`; marketplaces index plugins in `.grok-plugin/marketplace.json` and Grok also accepts `.claude-plugin/`. Installed with `grok plugin install <name> --trust` (Grok 1.0.44). See [Other harnesses](/docs/11-cross-platform/others).
- **OpenCode:** a JavaScript or TypeScript module in `.opencode/plugins/` or `~/.config/opencode/plugins/`, or an npm package listed under `plugin` in `opencode.json`. (OpenCode 1.18.33). See [Other harnesses](/docs/11-cross-platform/others).
- **Gemini CLI:** `~/.gemini/extensions/<name>/gemini-extension.json`; an extension bundles `GEMINI.md`, `commands/*.toml`, `skills/`, `hooks/hooks.json` and `agents/` (v0.61.0). See [Gemini CLI](/docs/11-cross-platform/gemini-cli).
- **Cursor** (last checked 2026-04): `.cursor-plugin/plugin.json` declares every artifact path explicitly.

Full coverage in the [cross-platform pages](/docs/11-cross-platform/claude-code). A spec-compliant SKILL.md loads without modification on the five hosts with native Agent Skills support covered there (Claude Code, Codex, Grok Build, OpenCode, Gemini CLI); Continue.dev and Copilot CLI lacked native support when last checked (2026-04). The packaging manifest differs per harness, and so do hooks, discovery paths, listing budgets, permissions and which frontmatter fields have an effect.

## Sources

- Claude Code docs, read 2026-09-29: [Plugins reference](https://code.claude.com/docs/en/plugins-reference) (manifest fields, variable substitution), [Skills](https://code.claude.com/docs/en/skills) (name resolution, `${CLAUDE_SKILL_DIR}`); Claude Code 2.1.284 `claude plugin --help`.
- `REVIEWER` G3 (`${CLAUDE_PLUGIN_ROOT}` gotcha; the three workarounds).
- [karpathy-wiki `plugin.json` at `d8107e7`](https://github.com/toolboxmd/karpathy-wiki/blob/d8107e727f4b585a9927cad813f90fda6b559ef3/.claude-plugin/plugin.json) (the manifest shape used as exemplar).
- Cross-platform manifests: sources on each [cross-platform page](/docs/11-cross-platform/others), checked 2026-09-29 except Cursor (`LANDSCAPE` 1.4, 2026-04).

Cross-links: [Claude Code](/docs/11-cross-platform/claude-code), [Codex](/docs/11-cross-platform/codex), [Gemini CLI](/docs/11-cross-platform/gemini-cli), [Other harnesses](/docs/11-cross-platform/others).
