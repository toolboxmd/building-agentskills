# Line budget: why 500 lines is a contract

The 500-line cap on SKILL.md is not a stylistic preference. It is a load-bearing constraint tied to Claude Code's auto-compaction floor. This page explains the why; the numerical detail is in `docs/04-token-economics.md`.

## The number

Source: agent-skills spec, https://agentskills.io/specification, "Keep your main SKILL.md under 500 lines."

Source: Anthropic Claude Code docs, https://code.claude.com/docs/en/skills, "Keep `SKILL.md` under 500 lines."

Both sources name the same number. The convergence is not coincidence; it traces to the same underlying mechanic.

## The why

Claude Code carries activated skills forward across auto-compaction within a 25,000-token shared budget, keeping the first 5,000 tokens of each. A 500-line SKILL.md is approximately 5,000 tokens (the rule of thumb is ~10 tokens per line of prose; tighter prose runs lower, code-heavy prose runs higher).

A 500-line skill survives compaction. A 1,000-line skill is truncated to its first half after compaction; the truncated half is the part the agent will not see for the rest of the session.

The full numerical breakdown is in `docs/04-token-economics.md`. The summary: the 500-line cap is the auto-compaction survival floor. Going over is not a style issue; it is a silent loss of behavior after the next compaction event.

## The implication

When your SKILL.md is over 500 lines, you have two options:

- **Tighten the prose.** Remove every word that is not load-bearing. Discipline prose is verbose by default; aggressive editing routinely cuts 20-30 percent.
- **Push detail to `references/`.** The agent-skills spec convention: file references one level deep from SKILL.md. Heavy reference material (API docs, comprehensive syntax, exhaustive examples) belongs in sibling files loaded on demand. Source: agent-skills spec; superpowers convention (`LANDSCAPE` 3.6).

The agent reads SKILL.md by default. References load only when the agent decides to read them (or when SKILL.md links to one inline). Heavy reference material should not live in SKILL.md; it bloats the auto-compaction footprint and pushes other skills out of the budget.

## The shape of references

Per the agent-skills spec: file references one level deep from SKILL.md. Avoid deeply nested reference chains.

Per superpowers (`LANDSCAPE` 3.6): sibling files named `<skill-name>/<topic>.md` (for example, `systematic-debugging/{condition-based-waiting,defense-in-depth,root-cause-tracing}.md`). Never nested.

The flat-references discipline is two-fold: agent UX (one-level-deep is browsable; nested chains are not) and validator simplicity (the agent-skills validator checks one-level-deep references; nested chains may not be supported uniformly).

## When to use references

- **Heavy reference material (~100+ lines).** API docs, comprehensive syntax. Per superpowers writing-skills SKILL.md:84-91.
- **Reusable tools.** Scripts, utilities, templates. These typically live in `scripts/` or `assets/`, not `references/`, but the same one-level-deep rule applies.
- **Rarely-needed content.** Loaded on demand keeps SKILL.md cheap. If a section is consulted in less than 10 percent of skill activations, it is a reference candidate.

## Karpathy-wiki's reference choice

Karpathy-wiki at v2.2 is 476 lines. The skill chose to stay under the 500-line cap with no `references/` directory. From the skill's own prose (lines 474-476):

> Nothing for v1. The skill is a single file under the 500-line superpowers budget. If later iterations exceed the budget, split specific operations (ingest-detail, lint-detail) to `references/*.md`, flat (never nested).

This is a deliberate design choice, not an accident. The audit (cited in `LESSONS` 2.1) checked the skill against the 500-line cap; v2.2's net change was +21 lines (from 455 to 476). Future ships that push over will trigger the references split.

The reviewer noted (`REVIEWER` verification table) that the `references/` directory does not actually exist on disk; the SKILL.md prose says "nothing for v1" and means it. If the next ship adds `references/`, it will materialize as a real sibling directory at that point.

## The audit step

Add to your pre-ship checklist:

```bash
wc -l skills/<skill-name>/SKILL.md
```

If over 500, the next ship's plan should include a "split to references" task. Do not let a SKILL.md drift over budget across multiple ships; the silent compaction-truncation hits without warning.

## Sources

- `LANDSCAPE` 3.5 (the 500-line cap as universal across spec / superpowers / Anthropic docs).
- `REVIEWER` G2 ("a 500-line SKILL.md is roughly 5,000 tokens").

Cross-links: `docs/04-token-economics.md` (the full token-budget arithmetic), `docs/08-packaging-as-plugin.md` (where references live in the directory tree).
