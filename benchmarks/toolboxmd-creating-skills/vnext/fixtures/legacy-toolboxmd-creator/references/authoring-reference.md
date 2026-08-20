# Offline authoring reference

Read this file when format rules, source authority, sidecar metadata, or the full pre-delivery audit matters. The default authoring path remains in `SKILL.md`.

## Source authority

Use evidence in this order and label it accurately:

1. **Normative format rules.** The frozen Agent Skills specification snapshot defines the portable package: `SKILL.md`; required `name` and `description`; allowed optional fields; naming grammar; progressive disclosure; relative file references; and the under-500-line recommendation.
2. **Authoritative platform guidance.** Frozen Agent Skills authoring guides explain evidence-led drafting, script design, output evaluation, and description testing. Platform documentation defines only that platform's sidecars, hooks, invocation controls, and install behavior.
3. **Shipped examples and comparative practice.** Frozen upstream creator and superpowers files show useful patterns: realistic prompts, concise trigger descriptions, pressure scenarios, rationalization evidence, and iterative testing. They are examples, not the portable standard.
4. **Local evidence-backed doctrine.** Repository snapshots contribute the primitive decision, three-question framework, mechanism boundary, token economics, provider-neutral runtime cut, proportional testing, and evolution boundaries. Treat numerical platform claims as snapshot-specific rather than universal format law.
5. **Discovery-only catalogs.** Registries, marketplace listings, search results, and link collections can help locate sources. Do not use them as proof of behavior, compliance, popularity, or quality.

Authoring snapshots consulted for this package:

- Normative and authoritative: `inputs/agent-skills/specification.mdx`, `best-practices.mdx`, `using-scripts.mdx`, `evaluating-skills.mdx`, and `optimizing-descriptions.mdx`.
- Local doctrine: `inputs/repo-docs/02-mental-model.md`, `03-three-questions.md`, `04-token-economics.md`, `05-authoring/*`, `06-testing/*`, `07-mechanism-vs-decoration.md`, `09-evolution.md`, `10-anti-patterns.md`, and `11-cross-platform/*`.
- Comparative practice: `inputs/upstream/anthropic-skill-creator.md`, `superpowers-writing-skills.md`, and `superpowers-testing-skills.md`.

These citations identify frozen authoring evidence. They are not runtime dependencies and need not exist where the finished skill is installed.

## Resolved disagreements

### Description content

The normative specification requires a description to say what the skill does and when to use it. Some comparative practice recommends trigger conditions only because workflow summaries can become shortcuts. Satisfy both: write capability plus trigger and exclusion boundaries, but keep procedural steps in the body.

### Test size

Authoritative evaluation guidance starts with 2-3 realistic cases. Comparative discipline practice can require repeated pressure scenarios, controls, and many trials. Use 2-3 cases and one downstream smoke check by default for a nontrivial new skill. Expand only when risk, observed variance, discipline enforcement, or the claim being made justifies it. Version-versus-version comparison belongs to `toolboxmd-benchmarking-skills`.

### Frontmatter controls

The portable specification recognizes:

- `name` (required)
- `description` (required)
- `license` (optional)
- `compatibility` (optional)
- `metadata` (optional string-to-string map)
- `allowed-tools` (optional and experimental)

Invocation controls such as user-only flags, path gates, model or effort selection, and hooks are platform extensions. Do not put them in portable frontmatter. Record the desired invocation model and implement platform control separately when required.

## Normative format checklist

### Directory and name

- The skill is a directory containing `SKILL.md`.
- `name` is 1-64 characters, uses lowercase ASCII letters, digits, and single hyphens, and has no leading or trailing hyphen.
- `name` matches the parent directory.

### Description

- It is nonempty and no longer than 1,024 characters.
- It states capability and when to use it.
- It uses concrete intent, artifact, domain, or symptom terms that support discovery.
- It includes exclusions for close adjacent tasks when needed.
- It does not compress the workflow into frontmatter.

### Body and resources

- Keep `SKILL.md` under 500 lines and preferably much smaller.
- Keep the default path and universally needed gotchas in the body.
- Use relative paths from the skill root.
- Keep referenced resources shallow; avoid chains of references.
- Tell the agent exactly when to load each conditional reference.
- Add `references/`, `scripts/`, `assets/`, or `evals/` only when used.

## Evidence brief template

```markdown
Reusable job:
User value:

Should trigger:
- "..."

Near misses:
- "..."

Required inputs:
- ...

Required outputs:
- ...

Real artifacts inspected:
- path or artifact — what it proves

Observed failures or corrections:
- evidence — reusable lesson

Constraints:
- project, platform, safety, dependency, delivery

Evidence gaps:
- unknown — how to resolve it
```

## Three-question record

```markdown
Who invokes: agent | user | both
Portable behavior:
Platform mechanism, if any:

Invariant | Advisory or mechanism | What fires | Failure behavior
---|---|---|---
... | ... | ... | ...

Description budget: ___ / 1024 characters
SKILL.md target: ___ lines / ___ estimated tokens
Conditional references: ___
Always-on integration cost: ___
```

Do not use a platform-only frontmatter field merely to make the record look complete. The record explains design intent; the package uses only fields supported by its target.

## Script contract

Bundle a script when repeated executions reinvent the same deterministic logic or when a mechanical gate catches failures more reliably than prose. Review it for:

- noninteractive operation;
- explicit inputs and concise `--help`;
- safe defaults and dry-run for risky mutation;
- validation before writes and no partial mutation on failure;
- idempotence or documented retry behavior;
- structured stdout where another tool consumes results;
- diagnostics on stderr;
- bounded output or pagination;
- meaningful documented exit codes;
- declared, minimal, preferably offline-compatible dependencies;
- syntax and focused behavior tests.

Keep provider selection, model identity, scheduling, concurrency, retry state, and lifecycle ownership in a deterministic runtime or platform integration. Keep semantic judgment in the skill.

## Sidecar: `agents/openai.yaml`

This sidecar is platform-specific and optional; other clients may ignore it. When included for this package contract, use:

```yaml
interface:
  display_name: "Human-readable name"
  short_description: "A concise 25 to 64 character summary"
  default_prompt: "Use $skill-name to perform the requested task."
```

Quote all three strings. The `default_prompt` should be one sentence and explicitly mention the `$skill-name`. Do not invent icons, brand colors, dependencies, or invocation policy when they were not requested and evidenced.

## Proportional test plan

Choose the smallest tier that supports the claim:

1. **Mechanical validation:** every skill. Validate frontmatter, layout, paths, metadata, line count, and script syntax.
2. **Prepared evals and smoke check:** nontrivial skills. Use 2-3 realistic prompts, one boundary, expected outputs, and observable assertions. Execute at least one representative downstream task in fresh context when the harness permits.
3. **Focused behavior tests:** scripts, executable snippets, fragile formats, and platform wiring. Test exact bytes or exact interfaces where copying is the runtime behavior.
4. **Pressure or replicated testing:** costly discipline rules, stochastic failures, high-risk operations, or strong reliability claims.

When a baseline test already passes, ask whether the skill adds value. A regression pin or exact mechanism rehearsal may legitimately pass immediately; label that role explicitly.

## Final audit

Inspect the whole tree, then check:

- no unexpected or empty files;
- no README, changelog, status report, or authoring diary;
- no duplicated doctrine across body and references;
- every local Markdown link and mentioned bundled path resolves;
- no absolute workstation paths, credentials, or time-sensitive unsupported claims;
- frontmatter uses only fields portable to the target contract;
- name, directory, and eval `skill_name` agree;
- description and sidecar lengths are within bounds;
- every rigid invariant names its enforcement or is honestly advisory;
- all scripts have syntax checks and proportionate tests;
- the final tree is unchanged after inspection.

Report four states independently:

```text
Validated: yes/no — evidence
Tested: yes/no/partial — evidence and skipped checks
Committed: yes/no/unknown — commit identifier if known
Pushed: yes/no/unknown — remote/ref if known
```
