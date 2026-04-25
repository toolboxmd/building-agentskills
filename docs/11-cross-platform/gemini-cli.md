# Gemini CLI: Extensions, not Skills

Google's Gemini CLI does NOT support Agent Skills. It uses a different mechanism called Extensions. Authors trying to ship the same skill on Gemini cannot do so directly; they must port to the Extension model. This page covers what Gemini supports, what it does not, and what the gap means for cross-platform skill authors.

Source: `LANDSCAPE` 1.4, 2.3.

## What Gemini supports: Extensions

Extensions live at `~/.gemini/extensions/<extension-name>/`. Each extension contains:

- **`gemini-extension.json`.** The manifest. Names the extension and its components.
- **`GEMINI.md`.** The always-on context. Loaded at session start. Supports `@`-imports (one file can `@`-include another).
- **`commands/*.toml`.** Custom slash commands. Each TOML file declares one command.

There is no Agent Skills equivalent in Gemini. The closest mapping:

| Agent Skills concept | Gemini Extensions equivalent |
|---|---|
| `SKILL.md` body | `GEMINI.md` (with the cost trade-off below) |
| Skill description (auto-trigger) | No equivalent |
| Slash command | `commands/*.toml` |
| Progressive disclosure | None; `GEMINI.md` is always on |
| Hooks | None |

## The cost gap: always-on vs progressive disclosure

The fundamental difference: Agent Skills use progressive disclosure (description ~100 tokens, body loaded on activation). Gemini Extensions use always-on context (`GEMINI.md` and all its `@`-imports load at session start, every session).

For a 500-line skill:

- **Agent Skills behavior.** ~100 tokens per session if not invoked; ~5,000 tokens per session if invoked. Activation cost paid once per session.
- **Gemini Extensions behavior.** ~5,000 tokens per session, every session, whether the extension is "needed" or not. The full body is in context from turn 1.

For a power user with five extensions installed, the always-on cost is ~25,000 tokens of `GEMINI.md` content before the user has typed anything. This is the cost gap; it is real and it scales linearly.

See `docs/04-token-economics.md` for the full token-budget arithmetic.

## What Gemini does NOT support

- **No description-based auto-invoke.** Gemini does not read a skill's description to decide whether to load it. Extensions are loaded based on file presence, not content matching.
- **No progressive disclosure.** Everything in `GEMINI.md` is always in context. Heavy reference material that would live in `references/` for Agent Skills must live in always-on space (or be cut entirely) for Gemini.
- **No hooks.** No SessionStart, PreToolUse, PostToolUse, or Stop hook events. Behavior that requires the harness to fire on an event must be reimplemented as a slash command the user types.
- **No Iron Law / rationalization-table-as-discipline pattern.** The patterns work in `GEMINI.md` (the prose is loaded), but the always-on cost makes large discipline blocks expensive.

## Porting a skill to Gemini

If your skill is small (~100-200 lines) and the always-on cost is acceptable, port the SKILL.md body to a `GEMINI.md` directly. Replace `description` with the body's first paragraph (Gemini does not use it for triggering, but readers will see it).

If your skill is large (~500 lines), the port requires choices:

- Cut to the iron-law-only essentials. The discipline rules survive; the worked examples and rationalization tables get trimmed.
- Convert the skill to a slash command. The user types `/wiki-capture` to invoke; `GEMINI.md` carries only the activation prose.
- Skip the Gemini port. Document in your README that the skill targets Agent Skills harnesses (Claude Code, Codex, OpenCode, Cursor, Hermes) and Gemini is not supported.

The skip-the-Gemini-port choice is legitimate. Not every skill needs every harness.

## Sources

- `LANDSCAPE` 1.4 (cross-platform comparison; Gemini section).
- `LANDSCAPE` 2.3 (Gemini CLI: Extensions, not Skills; the always-on context model).

Cross-links: `docs/04-token-economics.md` (the cost gap of always-on context).
