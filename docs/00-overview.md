# Overview: the layered architecture

This repo is the third layer of a stack. Two layers below it already exist; their conventions and constraints carry forward. This page names the layers, what each adds, and what each leaves out, so you can read the rest of the docs knowing which layer a given pattern belongs to.

## Layer 1: agent-skills (the foundation)

The Agent Skills format, maintained by Anthropic and open to community contribution, is the cross-platform foundation. Its specification lives at https://agentskills.io/specification. The reference implementation lives at https://github.com/agentskills/agentskills (Apache 2.0) and ships the `skills-ref validate` validator.

What Layer 1 gives you:

- The `SKILL.md` file format. Frontmatter (`name`, `description`, optional `license`, `compatibility`, `metadata`) plus a markdown body.
- The directory shape. `<skill-name>/{SKILL.md, scripts/, references/, assets/, ...}`. `SKILL.md` is the only required file.
- Progressive disclosure. Metadata loads at startup (~100 tokens for name + description); the body loads on activation (recommended under 5,000 tokens); files in `scripts/`, `references/`, `assets/` load only when needed.
- The 500-line cap. The spec text reads "Keep your main SKILL.md under 500 lines." Anthropic's Claude Code docs repeat this verbatim.
- The 1024-character description hard cap. Per-spec maximum.
- The validator. `skills-ref validate ./my-skill` checks frontmatter format, name format, and directory layout.

What Layer 1 leaves out:

- How to write a description that actually triggers the agent. The spec says only that the description "describes what the skill does and when to use it."
- An anti-pattern catalog. The spec is descriptive of what is, not prescriptive about what to avoid.
- A testing methodology beyond the validator.
- Iron-laws, rationalization tables, red-flag lists, or other discipline patterns.
- Per-harness extensions (Claude Code's `when_to_use`, `model`, `effort`, `paths`, `hooks`, etc.). The spec is harness-neutral by design.
- Distribution and versioning guidance.

Layer 1 is your contract with the ecosystem. Stay inside it and your skill works on Claude Code, Codex, OpenCode, Cursor, Hermes, and any future harness that adopts the spec.

## Layer 2: superpowers (the convention layer)

The `obra/superpowers` skill library packages the skill-authoring meta-discipline: skills about how to write skills, how to plan multi-step work, how to dispatch subagents, how to do TDD on prose, how to dispatch and respond to code review. It runs ~15 skills at roughly 200 lines each, plus a few longer reference skills.

What Layer 2 adds on top of Layer 1:

- The "Use when..." description format and the Claude Search Optimization (CSO) discipline. Description must describe triggering conditions, not summarize the workflow. Operationalized in `writing-skills` (the skill about writing skills).
- The Iron Law pattern. Single-sentence, all-caps, block-quoted code-fenced rules. Example: `NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST`.
- The rationalization table. Two-column markdown grid mapping verbatim agent excuses to their counter.
- The Red Flags list. Bulleted thought patterns the agent should recognize as signaling a violation in progress.
- The bulletproofing-against-rationalization discipline. Close every loophole, name spirit-vs-letter explicitly.
- TDD applied to documentation. RED-GREEN-REFACTOR for prose changes; pressure-testing with subagents for discipline skills.
- The brainstorming-spec-plan-execute pipeline. Four skills that compose into a non-trivial-ship workflow.
- Subagent dispatch patterns. Fresh-subagent-per-task; two-stage review (spec compliance, then code quality); explicit BASE_SHA/HEAD_SHA in dispatch prompts.
- Cross-platform packaging templates. Per-harness manifests for Claude Code, Cursor, OpenCode, Gemini, Codex.

What Layer 2 leaves out:

- Mechanism vs decoration. Every threshold or invariant in superpowers' SKILL.md files is enforced by either a script (rare) or by the agent reading and complying. The pattern of "wire every invariant to a firing mechanism" is not yet named in superpowers.
- Statefulness patterns. Superpowers skills are stateless process documentation. Skills that produce and manipulate persistent artifacts (locks, manifests, drift detection) need a different discipline.
- TDD inversions. The TDD skill treats "tests that pass immediately" as an anti-pattern; the regression-pin and mechanism-rehearsal cases are not named.
- Heredoc-in-prose silent correctness bugs. Superpowers prose is read by the foreground agent; it is not executed by a headless subprocess, so the byte-exact-snippet hazard does not surface there.

Layer 2 is the convention layer. Most patterns you read about online when researching how to write a skill in 2026 are Layer 2 patterns. They are conventions, not specification rules. You can ignore them and still be spec-compliant; you ignore them at the cost of triggerability and discipline.

## Layer 3: this repo (the delta)

`toolboxmd/building-agentskills` is the delta. It documents what one stateful artifact-manipulating skill (karpathy-wiki) learned in shipping v2.2 that the existing canon does not yet cover, plus a cross-platform reference frame so readers know which patterns are universal and which are Claude Code specific.

What Layer 3 adds on top of Layers 1 and 2:

- Decoration vs mechanism. Every threshold or invariant in your SKILL.md must answer "what fires on it?" If the answer is "the agent decides," wire it to a script, validator exit code, hook, or captured artifact. Documented in `07-mechanism-vs-decoration.md`.
- The three-question framework. Who invokes? What fires on rules? What is the token budget? The hero mental model. See `03-three-questions.md`.
- Heredoc-in-prose silent correctness bugs. Snippets in SKILL.md prose are production code when a headless subprocess executes them; test verbatim. See `05-authoring/prose-discipline.md`.
- TDD inversions. Regression-pin and mechanism-rehearsal as legitimate "tests pass immediately" cases. See `06-testing/tests-that-pass-immediately.md`.
- Subagent reformatting hazard. Implementer subagents reformat unrelated lines as a "quality gesture"; the cure is an explicit Diff Scope clause. See `10-anti-patterns.md`.
- Cross-platform reference frame. Per-harness sections under `docs/11-cross-platform/` with explicit "X does NOT support Y" labels where applicable.

What Layer 3 deliberately does not add:

- A re-statement of the agent-skills spec. Read https://agentskills.io/specification.
- A re-statement of Claude Code's docs. Read https://code.claude.com/docs/en/skills.
- A re-statement of superpowers' patterns. Read `obra/superpowers`.
- Any pattern that does not have ship evidence behind it. Every pattern in this repo cites a concrete commit or a concrete failure mode.
- LLM-specific magic, vector search, web UI, dashboards, notifications. The skill being shipped is documentation; the docs and the loader skill are the artifact.

## What this repo is

This repo is a layered authoring reference for AI agent skills. It assumes you can find and read Layer 1 (agent-skills spec) and Layer 2 (superpowers) yourself. It contributes the Layer 3 patterns one stateful skill discovered in production and structures them for cross-platform use.

The three blocker docs (`docs/01-quickstart.md`, `docs/02-mental-model.md`, `docs/04-token-economics.md`) close the audience gap a layered repo would otherwise leave: a first-time author needs to know how to ship a hello-world skill, when a skill is the right primitive at all, and why the constraints exist. Read those three first. The rest of the docs make sense once those are in place.

## What this repo is not

This repo is not a tutorial. It does not walk you through writing your first ten skills, does not pick a stack for you, does not have opinions about your project layout. It is a reference structured as docs you read on demand. The hero framework (`03-three-questions.md`) is the only doc you should read end-to-end on first contact; everything else is a destination you arrive at when a specific question forces you there.

This repo is also not Claude Code specific. Per-harness specifics live in `docs/11-cross-platform/`. The rest of the docs speak to all harnesses unless explicitly labeled. Where a feature is Claude Code specific (and many are), the doc says so inline.

## Sources

- `LANDSCAPE` (`/Users/lukaszmaj/dev/bigbrain/research/building-agentskills/2026-04-24-skill-authoring-landscape-2026.md`) sections 1.1, 1.2, 1.3, 7.1.
- `REVIEWER` (`/Users/lukaszmaj/dev/bigbrain/research/building-agentskills/2026-04-24-analyzer-review.md`), Verdict and What the analyzer got right.

Cross-links: README.md, docs/03-three-questions.md.
