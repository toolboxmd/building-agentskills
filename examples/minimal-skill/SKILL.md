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

If your description does not name when the skill should activate, the agent will never trigger your skill. See `docs/05-authoring/triggers.md` in the building-agentskills repo for the discipline.

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
