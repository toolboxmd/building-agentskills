# Mental model: skills vs CLAUDE.md vs hooks vs slash commands

This is the decision matrix. Before you write a skill, ask: is a skill actually the right primitive for what you want? The cost of a wrong-primitive answer is a skill that never triggers, that bloats every conversation, or that should have been a script.

This doc answers Question 1 of the hero framework (who invokes?). For the full framework, see `docs/03-three-questions.md`.

## The four primitives

Claude Code (and most spec-compatible harnesses) gives you four mechanisms for adding behavior or context to the agent. They differ in (a) who triggers them, (b) when they load, and (c) what they cost per session.

| Primitive | Who triggers | When loaded | Per-session cost | Best for |
|---|---|---|---|---|
| Skill | Agent (description match) OR user (`/skill-name`) | On invocation | ~100 tokens (description) at startup, ~5,000 tokens (body) on activation | Procedure-shaped or discipline-shaped content the agent should pick up when relevant |
| CLAUDE.md / AGENTS.md | Always | Session start | Full content every session | Always-on facts: project conventions, tooling versions, contributor identity |
| Hook (SessionStart, PreToolUse, etc.) | Harness (event fires) | When the event fires | Only the hook output, only when the event fires | Mechanism-shaped automation: gating, validation, context injection on demand |
| Slash command (custom or skill-as-command) | User (typed `/name`) | On user invocation | Same as a skill (one is a thin wrapper around the other) | User-initiated workflows the agent should never trigger on its own |

## When to use each

### Use a skill when

The content is procedure shaped or discipline shaped, and you want the agent to pick it up when a relevant moment arises.

Examples:
- A capture-and-ingest workflow (karpathy-wiki). Triggers on "research subagent returned a file" or on a confusion being resolved. The agent loads the skill, follows its protocol, and writes to the wiki.
- A discipline rule for prose changes ("RED-GREEN-REFACTOR for prose"). Triggers when the agent is editing a SKILL.md.
- A reference for a heavy domain (Anthropic's `pdf` skill in `anthropics/skills/skills/pdf`). Triggers when the user mentions a PDF; the body lists every PDF operation the skill supports.

The cost trade-off: skills have zero per-session cost when not invoked (Claude Code only reads the description, not the body, until activation). The cost of activation is the body size in tokens, which sits in the conversation for the rest of the session.

### Use CLAUDE.md (or AGENTS.md) when

The content is a fact, not a procedure, and you want it always visible.

Examples:
- "This project uses pytest, not unittest."
- "When committing, use the Conventional Commits style."
- "Do not add em dashes anywhere; it is a project rule."

CLAUDE.md is the wrong home for a procedure ("when the user asks for a bug fix, do these 7 things") because the always-on cost compounds. Anthropic's Claude Code docs name this directly: "Create a skill when you keep pasting the same playbook, checklist, or multi-step procedure into chat, or when a section of CLAUDE.md has grown into a procedure rather than a fact."

If your CLAUDE.md is over ~200 lines and growing, the procedure-shaped sections are skill candidates.

### Use a hook when

The behavior is mechanism shaped (something must happen automatically) and the trigger is an event the harness can observe.

Examples:
- SessionStart hook injecting an iron-law block (`obra/superpowers` uses this for the `using-superpowers` bootstrap; cost measured in `LANDSCAPE` 2.1 at ~17.8k tokens over 57 hours / 13 firings, see `docs/04-token-economics.md`).
- PreToolUse hook validating a Bash command before execution.
- Stop hook running a final lint or test suite before the agent emits its done sentinel.

Hooks are Claude Code specific in detail (other harnesses have hooks but with different event sets and config formats; see `docs/11-cross-platform/`). The principle of "use the harness to enforce" is universal; the implementation is not.

### Use a slash command when

The user must initiate the action. The agent should never decide on its own to run it.

Examples:
- `/deploy`, `/release`, `/commit`. Side effects on real systems; the agent should not auto-fire.
- `/explain-architecture` for a long-form orientation walkthrough. The user wants it on demand.

In Claude Code, custom slash commands have merged into skills. A file at `.claude/commands/deploy.md` and a skill at `.claude/skills/deploy/SKILL.md` both create `/deploy` and behave the same way (per Claude Code's official docs). Pick whichever shape fits your authoring model; they are interchangeable. The skill shape is more general (it can also auto-trigger if you do not opt out); the command shape is conventionally for user-initiated work and conventionally never auto-fires.

To force user-only invocation, set `disable-model-invocation: true` in your skill's frontmatter (Claude Code extension). This is the hard line between "agent may invoke" and "user must invoke." See `docs/11-cross-platform/claude-code.md` for the full taxonomy.

## When a subagent fork is the right primitive

Claude Code's `context: fork` + `agent: Explore | Plan | general-purpose` runs a skill in an isolated subagent context. This is conceptually a fifth primitive but is built on top of the skill primitive: you ship a normal skill with `context: fork` in its frontmatter.

When to fork:

- The skill produces an artifact and does not need the parent's context. Karpathy-wiki's headless ingester is morally a fork (in practice, it is a `claude -p` subprocess; see `docs/07-mechanism-vs-decoration.md`).
- The skill needs a different model. Set `model: claude-opus-4-7` in frontmatter; the fork uses Opus while the parent uses Sonnet.
- The parent context is heavy and the skill's output is small. Forking saves the parent from carrying the skill's body for the rest of the session.

When NOT to fork:

- The skill needs to see the conversation. A fork starts with no history; you must pass everything explicitly in the skill body or as arguments.
- The skill's output needs to influence the parent's next decision in real time. Forks return their output but do not persist their reasoning.

Per Anthropic's docs: "`context: fork` only makes sense for skills with explicit instructions. If your skill contains guidelines like 'use these API conventions' without a task, the subagent receives the guidelines but no actionable prompt, and returns without meaningful output." This is a subtle authoring trap; see `docs/04-token-economics.md` for the cost trade-off (`REVIEWER` M3, M5).

## Decision shortcuts

If you are still unsure, these heuristics resolve most cases:

- "I want this loaded every session" → CLAUDE.md (if it is a fact) or SessionStart hook (if it is a mechanism).
- "I want the agent to pick this up when relevant" → skill, with a description that names the triggers.
- "I want the user to call this explicitly" → skill with `disable-model-invocation: true`, or a `.claude/commands/` markdown file.
- "I want the harness to enforce this" → hook. Skills are advisory; hooks are mechanism. See `docs/07-mechanism-vs-decoration.md`.
- "I have a CLAUDE.md section over 30 lines that reads like a procedure" → it is a skill candidate.

## Cost matters

Per-session cost differs by primitive. CLAUDE.md is paid every session, every turn. Skills are paid only when activated. Hooks are paid only when the event fires. The dollar consequences are real for long-running sessions; the full numbers are in `docs/04-token-economics.md` (Question 3 of the hero framework).

## Source layering

This doc is Layer 3 (synthesis). The four primitives are Layer 1 / Claude Code spec; the "use a skill when" framing is Layer 2 (superpowers convention); the explicit "skills have merged with custom commands" point is Claude Code 2026 documentation. Where this doc says something, the layer is identified inline so you can validate against the source.

## Sources

- `REVIEWER` G1 (the blocker that prompted this doc; the merge of custom commands into skills).
- `LANDSCAPE` 1.3 (Anthropic Claude Code docs lifecycle quote: "grew into a procedure rather than a fact").
- `REVIEWER` M3 (the cost trade-off of `context: fork`).
- Claude Code docs at https://code.claude.com/docs/en/skills (frontmatter taxonomy).

Cross-links: `docs/03-three-questions.md` (Question 1: who invokes), `docs/04-token-economics.md` (cost), `docs/11-cross-platform/claude-code.md` (per-harness specifics), `docs/07-mechanism-vs-decoration.md` (skills are advisory; hooks enforce).
