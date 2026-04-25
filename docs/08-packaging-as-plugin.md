# Packaging as a plugin

This page covers Claude Code plugin packaging from the karpathy-wiki shape: minimal `.claude-plugin/plugin.json`, skills in `skills/<name>/SKILL.md`, optional sibling sub-directories, the symlink install pattern, and the `${CLAUDE_PLUGIN_ROOT}` substitution gotcha.

Cross-platform packaging (Cursor, OpenCode, Gemini, Codex) lives in `docs/11-cross-platform/`. This page is Claude Code-specific.

## The minimal plugin shape

A Claude Code plugin is a directory with one required file plus skill directories.

```
your-plugin/
├── .claude-plugin/
│   └── plugin.json                    # required: name, version, description, author
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

The minimal manifest, mirrored from karpathy-wiki's shape (`KP-PLUGIN`):

```json
{
  "name": "your-plugin",
  "version": "0.1.0",
  "description": "One-sentence description of what this plugin provides.",
  "author": "yourname",
  "repository": "https://github.com/yourname/your-plugin",
  "license": "Apache-2.0"
}
```

Required fields per the Claude Code plugin spec: `name`, `version`, `description`, `author`. Optional but recommended: `repository`, `license`, `keywords`.

The `name` is the namespace prefix for your plugin's skills (Claude Code uses `plugin-name:skill-name` for namespacing). Pick a name that will not collide with other plugins.

The `version` follows semantic versioning. Note: a description-string change in your skills can break implicit triggering (the description is the activation contract); a description change is conceptually a major-version shift even if the body is unchanged. See `docs/09-evolution.md`.

## Where skills live

Per the convention from `KP-PLUGIN` and Claude Code's docs: plugin skills live at `skills/<skill-name>/SKILL.md` relative to the plugin root.

Optional sibling sub-directories under each skill:

- **`scripts/`.** Helper scripts the SKILL.md invokes. The agent-skills spec convention (Layer 1).
- **`references/`.** Heavy reference docs loaded on demand. One level deep from SKILL.md; never nested. See `docs/05-authoring/line-budget.md`.
- **`assets/`.** Data files, fixtures, images. Loaded as needed.

These sub-directories are spec-canonical (Layer 1) and recognized by every spec-compatible harness, not just Claude Code.

## Install paths

Claude Code recognizes plugins via:

- **Plugin marketplace.** Subscribe via `claude plugin marketplace add <url>`. Plugins published in a marketplace install with `claude plugin install <name>`.
- **Local clone + symlink.** The pattern karpathy-wiki uses for development: `git clone` the plugin repo, then `ln -s <plugin-skill-dir> ~/.claude/skills/<name>` to make the skill available without going through the plugin system.
- **Direct copy.** `cp -r <plugin-skill-dir> ~/.claude/skills/<name>`. Less common; loses the link to upstream.

Per-scope priority for Claude Code skills (per `docs/04-token-economics.md` and `docs/11-cross-platform/claude-code.md`):

> enterprise > personal > project > plugin

A skill at `~/.claude/skills/wiki/` (personal) shadows a skill at `<plugin>/skills/wiki/`. Plugin skills are namespaced (`plugin-name:wiki`) so they cannot shadow each other across plugins, but they CAN be shadowed by personal or project skills with the same bare name.

## The `${CLAUDE_PLUGIN_ROOT}` gotcha

Source: `REVIEWER` G3, "wiki concept page references" (`/Users/lukaszmaj/wiki/concepts/claude-code-plugin-root-substitution.md`).

The literal string `${CLAUDE_PLUGIN_ROOT}` appears as a config-time substitution token in `plugin.json` and `hooks.json`. Claude Code expands it to the plugin's installed path when reading those files. The token works inside Claude Code's own configuration plumbing.

The token does NOT propagate to the Bash tool. A SKILL.md that says:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/foo.sh"
```

will fail with `Exit 127 / No such file or directory` when run as a personal skill (the symlink-install case). The literal string `${CLAUDE_PLUGIN_ROOT}` reaches Bash, expands to the empty string (Bash sees an unset variable), and the command becomes `bash /scripts/foo.sh`, which does not exist.

The failure mode is silent during plugin install; it surfaces only when someone installs the skill personally (via symlink) and tries to invoke it.

The three workarounds documented in the wiki concept page:

1. **Use `${CLAUDE_SKILL_DIR}` instead.** Per Claude Code docs, this token is "available in bash injection commands to reference scripts or files bundled with the skill, regardless of the current working directory." It propagates to Bash where `${CLAUDE_PLUGIN_ROOT}` does not.
2. **Use a relative path.** `bash scripts/foo.sh` works if the skill's working directory is set to the skill's base directory. Some skills do `cd "$(dirname "$0")"` first; some rely on Claude Code setting `pwd` correctly.
3. **Compute the path explicitly.** From a SKILL.md prose preamble: "All script paths below are relative to this skill's base directory (shown at the top of the skill as `Base directory for this skill: ...`). `cd` into that directory before invoking any script, or prefix each script with the absolute base path." This is karpathy-wiki's chosen workaround.

The wiki concept page tracks the failure mode and the workarounds. The build-agentskills repo's loader skill follows convention 3 (use the base directory the harness prints in the preamble).

## Cross-platform manifests (brief)

Other harnesses use different manifest shapes:

- **Cursor:** `.cursor-plugin/plugin.json` declares every artifact path explicitly.
- **OpenCode:** `.opencode/plugins/<name>.js` is a JavaScript plugin that registers the skills directory and prepends bootstrap context to the first user message.
- **Gemini:** `~/.gemini/extensions/<name>/gemini-extension.json` declares an extension (not a plugin); always-on context lives in `GEMINI.md`, custom commands in `commands/*.toml`.
- **Codex:** `agents/openai.yaml` is the Codex-specific sidecar; the skills themselves live in `.agents/skills/<name>/`.

Full coverage in `docs/11-cross-platform/`. Most spec-compliant skills work in multiple harnesses with no modification (the SKILL.md is portable); only the manifest layer differs per harness.

## Sources

- `LANDSCAPE` 2.1 (Claude Code plugin packaging).
- `LANDSCAPE` 1.4 (cross-platform manifest landscape).
- `REVIEWER` G3 (`${CLAUDE_PLUGIN_ROOT}` config-time-token-vs-shell-env-var gotcha; the three workarounds).
- `KP-PLUGIN` (the minimal manifest shape used as exemplar).

Cross-links: `docs/11-cross-platform/`.
