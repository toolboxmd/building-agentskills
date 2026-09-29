# building-agentskills

Evidence-backed doctrine for designing AI agent skills: how to author a Skill, how to route an agent to the right procedure before each action, and how to benchmark whether it does.

It covers three areas:

- **Authoring.** Frontmatter, descriptions, prose, line budgets, mechanism versus decoration, packaging and evolution.
- **Routing.** Which procedure loads when: descriptions, routing rows, before-clauses and session-start pointers.
- **Trigger benchmarks.** Testing whether a description or routing row makes the agent read the right file before it acts, with valid scoring and confined runs.

The evidence comes from shipped Skills: [karpathy-wiki](https://github.com/toolboxmd/karpathy-wiki) (two case studies) and [AgentsMD](https://github.com/toolboxmd/agentsmd) (the routing benchmarks on Claude Code, Codex, Grok Build and OpenCode).

Authoring a skill well requires answering three questions:

1. **Who invokes?** Agent (the description lets it load the skill, but does not make it), user (`/skill-name`), or both?
2. **What fires on rules?** Is each invariant in your SKILL.md decoration (the agent reads and decides) or mechanism (a script, validator exit code, hook, or captured artifact fires on it)?
3. **What is the token budget?** Does your skill fit the auto-compaction floor (under ~5,000 tokens / ~500 lines) and the description listing budget?

Read [`docs/03-three-questions.md`](docs/03-three-questions.md) end-to-end on first contact. Every other doc here is a destination from one of the three questions.

## What this is

A public, layered, cross-platform repository of patterns for authoring AI agent skills. Three layers:

- **Layer 1, agent-skills foundation.** The format, frontmatter, progressive disclosure rules. Defined at https://agentskills.io/specification.
- **Layer 2, superpowers conventions.** TDD-for-prose, iron laws, rationalization tables, the brainstorming-spec-plan-execute pipeline. Defined in https://github.com/obra/superpowers.
- **Layer 3, this repo.** Patterns evidenced by karpathy-wiki and AgentsMD ships that the existing canon does not cover: decoration vs mechanism, prose-as-code, TDD inversions, provider-neutral runtimes, contamination-resistant agent benchmarks, routing rows and trigger benchmarks.

See [`docs/00-overview.md`](docs/00-overview.md) for the layered architecture explainer.

## Who it is for

Skill authors at any layer. The repo assumes you can find and read Layer 1 and Layer 2 yourself; it contributes the Layer 3 deltas and structures them for cross-platform use.

The audience splits into four groups:

- **First-time skill authors.** Read [`docs/01-quickstart.md`](docs/01-quickstart.md) first. Then the other two blocker docs below.
- **Authors with a skill that does not trigger or that fails.** Read [`docs/05-authoring/triggers.md`](docs/05-authoring/triggers.md), then [`docs/10-anti-patterns.md`](docs/10-anti-patterns.md). Each anti-pattern has a counter cross-link.
- **Authors testing whether a skill triggers.** Read [`docs/06-testing/trigger-benchmarks.md`](docs/06-testing/trigger-benchmarks.md), then the [routing benchmarks case study](case-studies/2026-09-29-agentsmd-routing-benchmarks.md).
- **Authors auditing an existing skill.** Read [`docs/03-three-questions.md`](docs/03-three-questions.md), then [`docs/07-mechanism-vs-decoration.md`](docs/07-mechanism-vs-decoration.md).

## The three blocker docs

These three docs close the audience gap a layered repo would otherwise leave. Read them in order before reading anything else.

1. [`docs/01-quickstart.md`](docs/01-quickstart.md). Your first skill in 10 minutes.
2. [`docs/02-mental-model.md`](docs/02-mental-model.md). When is a skill the right primitive at all?
3. [`docs/04-token-economics.md`](docs/04-token-economics.md). The hard numbers: why the 500-line cap exists, what auto-compaction does, how SessionStart-hook injection cost compounds.

## Documentation map

### Hero docs

- [`docs/00-overview.md`](docs/00-overview.md). The layered architecture explainer.
- [`docs/01-quickstart.md`](docs/01-quickstart.md). Your first skill in 10 minutes (BLOCKER).
- [`docs/02-mental-model.md`](docs/02-mental-model.md). Skills vs CLAUDE.md vs hooks vs slash commands (BLOCKER).
- [`docs/03-three-questions.md`](docs/03-three-questions.md). The hero framework, deep dive.
- [`docs/04-token-economics.md`](docs/04-token-economics.md). The why of constraints (BLOCKER).

### Authoring

- [`docs/05-authoring/frontmatter.md`](docs/05-authoring/frontmatter.md). Field-by-field reference.
- [`docs/05-authoring/prose-discipline.md`](docs/05-authoring/prose-discipline.md). Voice and snippet-as-code rules.
- [`docs/05-authoring/triggers.md`](docs/05-authoring/triggers.md). Description as activation contract.
- [`docs/05-authoring/iron-laws.md`](docs/05-authoring/iron-laws.md). The four discipline-prose patterns.
- [`docs/05-authoring/line-budget.md`](docs/05-authoring/line-budget.md). Why 500 lines is a contract.
- [`docs/05-authoring/provider-neutral-runtime.md`](docs/05-authoring/provider-neutral-runtime.md). Separate semantic skill judgment from provider adapters and deterministic orchestration.

### Testing

- [`docs/06-testing/red-green-for-prose.md`](docs/06-testing/red-green-for-prose.md). The four prose-change sub-modes.
- [`docs/06-testing/unit-tests.md`](docs/06-testing/unit-tests.md). What to test and how.
- [`docs/06-testing/tests-that-pass-immediately.md`](docs/06-testing/tests-that-pass-immediately.md). The two valid TDD inversions.
- [`docs/06-testing/benchmark-integrity.md`](docs/06-testing/benchmark-integrity.md). Attribution, read isolation, blind retrieval grading, and contaminated-run handling.
- [`docs/06-testing/trigger-benchmarks.md`](docs/06-testing/trigger-benchmarks.md). Testing whether a description or routing row makes the agent read a file before the action: fixtures, confinement, valid scoring, and records.

### Standalone deep dive and reference

- [`docs/07-mechanism-vs-decoration.md`](docs/07-mechanism-vs-decoration.md). The strongest single signal.
- [`docs/08-packaging-as-plugin.md`](docs/08-packaging-as-plugin.md). Plugin manifest and install paths.
- [`docs/09-evolution.md`](docs/09-evolution.md). Ship cycles, semver, deprecation.
- [`docs/10-anti-patterns.md`](docs/10-anti-patterns.md). The failure modes catalog, including routing rows that do not fire and trigger-benchmark instruments that score wrong.
- [`docs/12-update-mechanism.md`](docs/12-update-mechanism.md). How new lessons flow in.

### Cross-platform

- [`docs/11-cross-platform/claude-code.md`](docs/11-cross-platform/claude-code.md). Claude Code-specific frontmatter and hooks.
- [`docs/11-cross-platform/codex.md`](docs/11-cross-platform/codex.md). Codex: Skills, the `agents/openai.yaml` sidecar, plugins and hooks.
- [`docs/11-cross-platform/gemini-cli.md`](docs/11-cross-platform/gemini-cli.md). Gemini CLI: Agent Skills, hooks and extensions.
- [`docs/11-cross-platform/others.md`](docs/11-cross-platform/others.md). Grok Build, OpenCode, Cursor, Hermes, Continue.dev, Copilot CLI.

### Case study and example

- [`case-studies/2026-04-25-karpathy-wiki-v2.2.md`](case-studies/2026-04-25-karpathy-wiki-v2.2.md). The seed case study.
- [`case-studies/2026-08-11-karpathy-wiki-provider-aware-ingest.md`](case-studies/2026-08-11-karpathy-wiki-provider-aware-ingest.md). Provider-neutral runtime and benchmark-integrity ship.
- [`case-studies/2026-09-29-agentsmd-routing-benchmarks.md`](case-studies/2026-09-29-agentsmd-routing-benchmarks.md). AgentsMD routing and trigger benchmarks on four hosts: setup, instrument failures, fixes and numbers.
- [`case-studies/2026-09-29-t3-delegation-tool-descriptions.md`](case-studies/2026-09-29-t3-delegation-tool-descriptions.md). MCP tool descriptions as activation contracts, and what deferred tool loading hides.
- [`examples/minimal-skill/SKILL.md`](examples/minimal-skill/SKILL.md). A working minimal skill to copy.

### Loader skill

- [`skills/building-agentskills/SKILL.md`](skills/building-agentskills/SKILL.md). The loader: a routing table that sends the agent to the right page before each authoring, testing or packaging action. Its paths resolve from its own directory inside this repository; a copy of the Skill directory alone reads the pages from GitHub.

## Contributing

How new lessons enter this repo: per-ship retrospectives, reader-submitted issues, quarterly landscape audits. See [`docs/12-update-mechanism.md`](docs/12-update-mechanism.md) for the case-study shape and the contribution model. Planned work is tracked in [GitHub Issues](https://github.com/toolboxmd/building-agentskills/issues).

Every lesson cites at least one of: a shipped commit, a recorded failure with inspectable evidence, a benchmark result with its claim boundary, or a primary source for platform behavior. Aspirational patterns are out of scope; the case studies show what evidence-driven additions look like.

## License

Apache 2.0. See [`LICENSE`](LICENSE).

The choice is deliberate. Apache 2.0's explicit patent grant matches the posture of `agentskills/agentskills` (the spec org's reference implementation, also Apache 2.0) and eases cross-pollination across the ecosystem. This repo's license is Apache 2.0, NOT MIT, even though related skills (like karpathy-wiki) ship under MIT. See [`docs/09-evolution.md`](docs/09-evolution.md) for the license-of-skills nuance.
