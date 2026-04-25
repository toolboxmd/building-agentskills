# Quickstart: your first skill in 10 minutes

This page walks you from zero to a working SKILL.md that activates in Claude Code on your machine. It is the shortest path to "the agent picked up my skill"; it deliberately does not cover anti-patterns, testing discipline, or cross-platform packaging. Those are the rest of the repo.

The walkthrough mirrors the canonical 6-line minimal template from the agent-skills spec (Layer 1) and the personal-scope install path from Anthropic's Claude Code docs (https://code.claude.com/docs/en/skills).

## Prerequisites

- `claude` CLI installed and working (run `claude --version`).
- A text editor.
- The directory `~/.claude/skills/` exists; if it does not, create it: `mkdir -p ~/.claude/skills`.

## Step 1: pick a name

The `name` field is the most constrained part of a skill. Rules from the agent-skills spec:

- Lowercase ASCII letters, digits, and hyphens only.
- Maximum 64 characters.
- No leading or trailing hyphens; no consecutive hyphens.
- Must match the parent directory name.
- The strings `anthropic` and `claude` are reserved (Claude Code constraint).

For this walkthrough, the name is `hello-skill`.

## Step 2: create the skill directory

```bash
mkdir -p ~/.claude/skills/hello-skill
```

The parent directory name (`hello-skill`) becomes your `name` field. If they do not match, the skill will not load.

## Step 3: write the SKILL.md

Create `~/.claude/skills/hello-skill/SKILL.md` with this content:

```markdown
---
name: hello-skill
description: Use when the user asks to test that a custom skill is working, or types "ping skill"; replies with a one-line confirmation that the skill activated.
---

# Hello Skill

Reply to the user with exactly:

> Hello from the hello-skill custom skill. Activation works.

Then stop. Do not add any other text.
```

That is the entire skill. Six lines of frontmatter and four lines of body.

## Step 4: verify activation

Open a fresh `claude` session in any directory:

```bash
claude
```

Type:

```
ping skill
```

Expected behavior: the agent replies with the line from your SKILL.md body and stops. If the agent responds without referencing the skill, see "Troubleshooting" below.

## What just happened

When `claude` started, it scanned `~/.claude/skills/` and read the frontmatter of every `SKILL.md` it found. The `name` and `description` were loaded into the agent's context (~100 tokens for both, per the agent-skills spec's progressive disclosure model). The body was not loaded yet.

When you typed "ping skill," the agent matched your prompt against the loaded descriptions. The `hello-skill` description starts with "Use when..." and lists "ping skill" as a trigger phrase, so the agent decided to activate it. Activation loads the full SKILL.md body into the conversation as a single message; that body told the agent what to reply with, and it complied.

## Why the description matters

The description is the only part of your skill the agent reads on every turn. If the description does not name the trigger conditions, the skill will never activate. The Layer 2 convention is "Use when..." followed by an enumeration of triggers (per `obra/superpowers` writing-skills); the Layer 1 spec just says "describes what the skill does and when to use it." Both shapes work; both are covered in `docs/05-authoring/triggers.md`.

What the description must NOT do: summarize the body's workflow. A description that reads "Replies with a one-line confirmation that the skill activated" instead of "Use when the user asks to test that a custom skill is working" causes the agent to follow the description instead of reading the body. This is the single most common Layer 2 failure mode; see `docs/10-anti-patterns.md` for the full pattern.

## Troubleshooting

The skill did not activate.

- Check that `~/.claude/skills/hello-skill/SKILL.md` exists. The path is case sensitive.
- Check that the `name` field in the frontmatter matches the directory name exactly: `hello-skill`.
- Check the frontmatter format. The first line of the file MUST be exactly `---`. If a leading whitespace character precedes the `---`, the parser will not recognize the frontmatter and the skill will be silently dropped.
- Check that you started a fresh `claude` session AFTER creating the file. Claude Code scans skills at session start; existing sessions will not pick up new top-level skill directories.
- Check `claude /skills` (the slash command). If your skill appears in the list, the file was loaded; activation is then a description-matching question. If it does not appear, the file was not loaded.

The skill activated but the body was not followed.

- Check that the body is unambiguous. If the body says "reply with one of the following," the agent will pick. If it says "reply with exactly: ...," the agent will copy.
- Check your description for workflow leakage. If the description repeats what the body says, the agent may follow the description and skip the body.

## What to read next

- `docs/02-mental-model.md`: when is a skill the right primitive? When should you use CLAUDE.md, hooks, or a slash command instead? The decision matrix.
- `docs/03-three-questions.md`: the three-question framework. The hero mental model for designing any skill.
- `docs/04-token-economics.md`: why the 500-line cap exists, and what auto-compaction does to your skill across a long session.
- `examples/minimal-skill/SKILL.md`: a working minimal skill you can copy as a starting point for your own work.

## Sources

- `LANDSCAPE` section 1.1 (the canonical 6-line minimal template).
- `LANDSCAPE` section 1.3 (Anthropic Claude Code docs, https://code.claude.com/docs/en/skills).
- `REVIEWER` G12 (Quickstart blocker for v0 audience).
