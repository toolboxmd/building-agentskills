---
name: minimal-skill
description: Use when the user asks to test a minimal skill template, or types "ping minimal"; replies with a one-line confirmation that the skill activated. Copy this file as a starting point for your own skill; replace name, description, and body to fit your domain.
license: Apache-2.0
---

# Minimal Skill

A working minimal SKILL.md the quickstart references. Copy this file as your starting point; replace the frontmatter and body with your own.

## Iron Law

```
NO SKILL.md WITHOUT A DESCRIPTION THAT NAMES A TRIGGER
```

A trigger in the description is necessary, not sufficient. Without one, the agent has no reason to load your skill. With one, it still may not load it: on Claude Code, Opus 5.5 loaded the AgentsMD `operations` Skill from its description in 0 of 40 naive runs, and in 20 of 20 once a session-start pointer named it. Test the trigger before you rely on it. See [Triggers](https://github.com/toolboxmd/building-agentskills/blob/main/docs/05-authoring/triggers.md) in the building-agentskills repo for the discipline and the evidence.

## Activation behavior

When the user types "ping minimal" (or asks to test a minimal skill template), reply with exactly:

> Hello from the minimal-skill template. Activation works.

Then stop. Do not add any other text.

## What this template demonstrates

- Cross-platform-safe frontmatter (`name`, `description`, `license`). No Claude Code extensions; works on every spec-compatible harness.
- An Iron Law in the body, block-quoted and code-fenced.
- Imperative voice for the agent ("reply with exactly").
- A description that names the trigger condition explicitly.

## What to change when you copy this

- The `name` (must match the parent directory name).
- The `description` (front-load triggers; aim for under 1,024 characters).
- The body (your own iron laws and instructions).

## What NOT to do

- Do not summarize the body's workflow in the description.
- Do not add emojis.
- Do not exceed 500 lines.
