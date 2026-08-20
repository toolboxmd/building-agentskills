---
name: toolboxmd-creating-skills
description: Create a new portable Agent Skill from concrete user needs, real artifacts, trigger examples, and observed failure evidence. Use when a user wants to design and validate a reusable skill package from scratch. Updating an existing skill and comparing skill versions are out of scope.
---

# Creating Skills

Create the smallest evidence-backed package that helps an agent perform a reusable task. Do not start by drafting generic guidance.

## Boundaries

- If the target skill already exists, hand off to `toolboxmd-updating-skills` when available. Until then, only make a narrowly requested, clearly bounded edit; do not turn this workflow into an updater.
- If the user asks whether one version is better, hand off to `toolboxmd-benchmarking-skills` when available. Until then, offer only a narrow smoke check the user explicitly requests; do not build a comparative benchmark.
- Treat a catalog, marketplace listing, or search result as discovery evidence only. It can locate material but cannot establish a format rule or authoring claim.

## Inputs

Obtain enough evidence to name:

- the reusable job and its user value;
- 2-5 realistic prompts that should trigger the behavior;
- 2-5 close near misses that should not trigger it;
- required inputs, expected outputs, and one or more real artifacts;
- corrections, failure traces, review comments, or other observed evidence of what agents get wrong;
- project and platform constraints, including available mechanisms and test facilities;
- the requested destination and delivery expectations.

If material evidence is missing, ask focused questions or complete one representative task with the user first. Label hypotheses as hypotheses; do not launder general model knowledge into project doctrine.

## Default path

### 1. Decide whether a skill is the right primitive

Inspect applicable project instructions before choosing. Prefer the primitive whose loading and enforcement behavior matches the need:

| Need | Prefer |
|---|---|
| Reusable judgment, procedure, or domain guidance loaded when relevant | Agent Skill |
| Always-on project facts or conventions | Project instructions such as `AGENTS.md` or equivalent |
| Automatic enforcement on an observable event | Hook or CI/pre-commit mechanism |
| Explicit user-started workflow | Command or user-invoked skill, depending on the platform |
| Repeated deterministic transformation or validation | Script or ordinary program |
| Stable external tools or data exposed to agents | MCP server |
| Installation, lifecycle wiring, multiple components, or platform integration | Plugin or extension |

A skill can coordinate these components, but prose does not make them fire. If the task is one-off, already handled reliably without special knowledge, or entirely deterministic, explain why a skill adds no value and recommend the smaller primitive.

### 2. Build an evidence brief before drafting

Record concrete triggers, near misses, inputs, outputs, artifacts, and failure evidence. For each proposed instruction, cite the artifact or observation that supports it. Prefer actual runbooks, schemas, successful task traces, corrections, issues, and diffs over generic best practices.

Do not proceed with a generic skill when the domain-specific evidence is too thin. Ask for a representative artifact, perform a representative task, or return an evidence-gap list.

### 3. Answer three independent design questions

Write the answers in working notes before choosing frontmatter or files:

1. **Who invokes?** Agent, user, or both? A portable description can support agent discovery, but user-only enforcement may require a platform mechanism outside portable frontmatter.
2. **What fires on each invariant?** For every `must`, `always`, `never`, numeric limit, or state transition, name either advisory prose or a real mechanism: script, validator exit code, hook, CI gate, or checked artifact. If nothing fires, rewrite it as guidance or propose a justified mechanism.
3. **What is the token budget?** Budget the always-listed description, activated `SKILL.md`, conditionally loaded references, and any always-on integration. Default to a description under 1,024 characters and `SKILL.md` well below 500 lines; set a smaller target based on expected invocation frequency.

Keep the answers independent. Correct invocation does not enforce invariants, and a small file does not guarantee discovery.

### 4. Plan the smallest package

Start with only `SKILL.md`. Add a directory only when evidence shows why it will be used:

- `references/` for substantial or conditional knowledge;
- `scripts/` for repeated deterministic work;
- `assets/` for templates or files consumed in outputs;
- `evals/` for realistic test prompts and checks on a nontrivial skill;
- platform sidecars only when the delivery target needs them.

Keep the essential decision path, inputs, outputs, defaults, and gotchas in `SKILL.md`. Put detail behind explicit conditions such as “Read `references/api-errors.md` when the service returns a non-success status.” Keep references shallow and avoid duplicated explanations.

Do not add a README, changelog, design diary, status file, or other process history to the skill package.

### 5. Draft from evidence

Use portable frontmatter with `name` and `description`; add other specification fields only when they carry real information. The directory and `name` must agree.

Write the description as a compact activation contract:

- state the capability;
- name concrete user intents or situations that should trigger it;
- name important exclusions when adjacent tasks are easy to confuse;
- omit the internal workflow summary.

In the body, lead with a concise default path. State explicit inputs and outputs, conditions for loading references, safe defaults, and concrete gotchas drawn from evidence. Use imperative prose. Explain why when judgment is needed; use rigid language only for genuine invariants.

Prefer instructions. Add a script after repeated runs reveal reinvented deterministic work or when mechanical validation is inherently valuable. Scripts should be noninteractive, accept explicit inputs, use safe defaults, offer `--help`, separate data from diagnostics where useful, validate before mutation, and return meaningful exit codes. Add dry-run behavior for stateful or destructive work.

Use [the offline authoring reference](references/authoring-reference.md) when checking format rules, source authority, sidecar fields, or the detailed validation checklist.

### 6. Test proportionately

For a nontrivial skill, prepare 2-3 realistic prompts with expected outputs. Include variation and at least one boundary or near-miss. Add objective assertions only for observable properties; use human review for subjective quality.

Run at least one downstream smoke check in a fresh context: provide the created skill, a realistic trigger prompt, and representative inputs; verify the agent loads the skill, follows its default path, and produces the promised output. Inspect the execution trace when available, not only the final response.

Escalate testing based on risk:

- deterministic scripts: syntax check plus focused behavior tests;
- discipline rules: observed baseline failure and a with-skill pressure scenario when practical;
- executable snippets in prose: rehearse the exact snippet, not a retyped variant;
- platform integration: disposable real-harness acceptance;
- broad comparative claims: out of scope; hand off to `toolboxmd-benchmarking-skills`.

The starter cases in [evals/evals.json](evals/evals.json) and [the downstream smoke check](evals/downstream-smoke.md) are examples to adapt, not a mandatory large suite.

### 7. Validate and deliver

Run the bundled validator from the skill root:

```bash
python3 scripts/validate_skill.py .
```

Also run the official Agent Skills validator if it is already available locally. Do not add a network dependency merely to obtain it.

Before delivery, inspect the complete package tree and verify:

- portable frontmatter, name grammar, directory/name agreement, and description length;
- `SKILL.md` line budget and conditional loading instructions;
- every referenced relative path exists and no absolute local path is embedded;
- sidecar metadata shape and required quoting/length constraints;
- scripts pass syntax checks, `--help`, focused tests, and safe-default review;
- eval prompts and at least one downstream smoke check exist when warranted;
- no empty, speculative, duplicate, or process-history files were added.

Do not modify the package after final inspection without repeating validation and inspection.

## Outputs

Deliver:

- the new skill directory with `SKILL.md` and only justified support files;
- a short evidence-and-design summary, including the primitive decision and the three independent answers;
- validation and test evidence, including any skipped checks and why;
- a handoff report that states **validated**, **tested**, **committed**, and **pushed** separately. Never infer commit or push state from successful validation.

## Gotchas

- A description must include capability and trigger boundaries to satisfy the portable specification, but should not summarize the body workflow. These requirements are compatible.
- Portable frontmatter cannot guarantee user-only or agent-only invocation across every harness. State the invocation intent, then add a platform mechanism only when the target requires it.
- Advisory prose is valid for judgment. It is not enforcement for thresholds, lifecycle state, or destructive gates.
- A passing validator proves structure, not usefulness. The downstream task is the smoke check.
- Do not force a large pressure-test or baseline-comparison campaign on every skill. Match testing effort to novelty, risk, determinism, and the user's requested claim.
- Keep provider identity, model choice, scheduling, retries, and concurrency out of semantic instructions unless the skill is intentionally platform-specific.
