---
name: building-agentskills
description: Use before creating a Skill; before writing or changing a Skill's frontmatter, description, routing row or SKILL.md prose; before writing or changing an MCP or agent tool description; before testing whether a Skill triggers; before benchmarking a model's output quality; before packaging, versioning or porting a Skill to another host; and before auditing a Skill that does not trigger or fails. Routes each of these actions to the building-agentskills page to read first.
license: Apache-2.0
---

# Building Agent Skills

This Skill routes each Skill-authoring action to the building-agentskills page to read before that action. The pages hold the doctrine; this file holds only the routes.

## Paths

Every path below is relative to this Skill's base directory, the directory that holds this `SKILL.md`. Claude Code shows it at the top of the loaded Skill as `Base directory for this skill: ...`. Resolve each path from that directory, never from the current working directory.

If the page does not exist there (the Skill was copied without its repository), read it from GitHub instead: replace the leading `../../` with `https://raw.githubusercontent.com/toolboxmd/building-agentskills/main/`.

## Routing

Find the row for the action you are about to take. Read its page as its own step, before any command or edit for that action. When two rows apply, read both pages.

| Action | Read first |
| --- | --- |
| Before creating your first Skill | [Quickstart](../../docs/01-quickstart.md) |
| Before choosing between a Skill, an always-loaded instruction file, a hook and a slash command | [Mental model](../../docs/02-mental-model.md) |
| Before designing a new Skill or auditing an existing one | [Three questions](../../docs/03-three-questions.md) |
| Before sizing a Skill, its description or a session-start injection | [Token economics](../../docs/04-token-economics.md) |
| Before writing or changing a Skill's frontmatter fields | [Frontmatter](../../docs/05-authoring/frontmatter.md) |
| Before writing or changing a Skill description or a routing row | [Triggers](../../docs/05-authoring/triggers.md) |
| Before writing or editing prose or code snippets in a `SKILL.md` body | [Prose discipline](../../docs/05-authoring/prose-discipline.md) |
| Before adding an Iron Law, a rationalization table or a Red Flags list | [Iron laws](../../docs/05-authoring/iron-laws.md) |
| Before splitting a `SKILL.md` into reference files, or when it nears 500 lines | [Line budget](../../docs/05-authoring/line-budget.md) |
| Before putting model invocation, retries or provider settings in a Skill | [Provider-neutral runtime](../../docs/05-authoring/provider-neutral-runtime.md) |
| Before stating a threshold or invariant the agent must not break | [Mechanism vs decoration](../../docs/07-mechanism-vs-decoration.md) |
| Before changing `SKILL.md` prose you need to prove | [Red-green for prose](../../docs/06-testing/red-green-for-prose.md) |
| Before writing tests for a Skill's scripts | [Unit tests](../../docs/06-testing/unit-tests.md) |
| Before keeping a new test that passed on its first run | [Tests that pass immediately](../../docs/06-testing/tests-that-pass-immediately.md) |
| Before testing whether a Skill, description or routing row triggers | [Trigger benchmarks](../../docs/06-testing/trigger-benchmarks.md) |
| Before benchmarking a model's output quality | [Benchmark integrity](../../docs/06-testing/benchmark-integrity.md) |
| Before packaging a Skill as a plugin | [Packaging as plugin](../../docs/08-packaging-as-plugin.md) |
| Before versioning, releasing or deprecating a Skill | [Evolution](../../docs/09-evolution.md) |
| Before auditing a Skill that does not trigger or fails | [Anti-patterns](../../docs/10-anti-patterns.md) |
| Before relying on Claude Code behavior (hooks, plugins, listing limits) | [Claude Code](../../docs/11-cross-platform/claude-code.md) |
| Before porting a Skill to Codex | [Codex](../../docs/11-cross-platform/codex.md) |
| Before porting a Skill to Gemini CLI | [Gemini CLI](../../docs/11-cross-platform/gemini-cli.md) |
| Before porting a Skill to Grok Build, OpenCode or another host | [Other harnesses](../../docs/11-cross-platform/others.md) |
| Before proposing a new lesson for this repository | [Update mechanism](../../docs/12-update-mechanism.md) |

## Iron Law

```
NO NEW LESSON WITHOUT CITED EVIDENCE
```

A lesson added to this repository cites at least one of: a shipped implementation commit, a recorded failure with inspectable evidence, a benchmark or acceptance result with its claim boundary, or a primary source for external platform behavior. Plans, upstream ideas and unverified implementations do not qualify.
