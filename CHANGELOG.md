# Changelog

Changes readers of this repository see, in [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format. The version rule and the tag step are in `AGENTS.md`.

## [Unreleased]

### Added

- `npm test` fails when `package.json`, `.claude-plugin/plugin.json`, this file and a tag on the commit disagree on the version, and when `docs/`, `case-studies/`, `skills/` or `examples/` change without a change to this file ([#22](https://github.com/toolboxmd/building-agentskills/issues/22)).

### Changed

- The README describes the quickstart, mental model, three-questions and token-economics pages as they read after [#12](https://github.com/toolboxmd/building-agentskills/issues/12).

## [0.2.0] - 2026-09-29

### Added

- Case study of the AgentsMD routing benchmarks on Claude Code, Codex, Grok Build and OpenCode: harness setup, instrument failures, fixes and numbers with record paths, plus an evidence manifest and a first `GLOSSARY.md` ([#6](https://github.com/toolboxmd/building-agentskills/issues/6)).
- `docs/06-testing/trigger-benchmarks.md`, the method for testing whether a description or routing row makes the agent read a file before it acts ([#5](https://github.com/toolboxmd/building-agentskills/issues/5)).
- Case study of MCP tool descriptions as activation contracts: a deferred delegation tool whose description did not name the shell route it replaces, a `triggers.md` section on tool descriptions, and two anti-patterns (a shell recipe in memory outranking the host's routing, a decision-point tool deferred behind tool search) ([#4](https://github.com/toolboxmd/building-agentskills/issues/4)).
- Nine routing and harness anti-patterns, and two AgentsMD cases for measuring and rewording before building a hook ([#13](https://github.com/toolboxmd/building-agentskills/issues/13)).
- `npm test` checks links with `mint broken-links` and the freshness of `public/llms.txt`, and CI runs it on every pull request and push to `main` ([#10](https://github.com/toolboxmd/building-agentskills/issues/10)).

### Changed

- `triggers.md` covers when a description is not enough, how to word routing rows and how to test a trigger ([#5](https://github.com/toolboxmd/building-agentskills/issues/5)).
- The quickstart, mental model, three-questions and token-economics pages state the measured activation behavior and each host's listing and hook-output limits ([#12](https://github.com/toolboxmd/building-agentskills/issues/12)).
- The cross-platform and packaging pages state current Claude Code, Codex, Grok Build, OpenCode and Gemini CLI facts, each cited and dated; Grok Build is covered ([#8](https://github.com/toolboxmd/building-agentskills/issues/8)).
- The README, overview, `AGENTS.md`, update-mechanism page and example Skill state the current scope and point at Issues; the loader Skill is a routing table whose paths resolve from its own directory ([#14](https://github.com/toolboxmd/building-agentskills/issues/14)).
- Planned work moved from `TODO.md`, the drift-prevention draft and the continuous-learning handoff into Issues #17 to #22; the handoff is marked superseded ([#11](https://github.com/toolboxmd/building-agentskills/issues/11)).

### Fixed

- Four doctrine pages lose a wrong license fact for obra/superpowers, two undefined source nicknames and a dated model ID ([#9](https://github.com/toolboxmd/building-agentskills/issues/9)).
- `triggers.md` no longer credits karpathy-wiki's SKIP and anti-rationalization shape to superpowers ([#5](https://github.com/toolboxmd/building-agentskills/issues/5)).
- Gemini CLI is described with its Agent Skills and hooks; the pages no longer say plugin Skills are shadowed by personal Skills, Codex subagents are opt-in, or OpenCode reads a description only after the call ([#8](https://github.com/toolboxmd/building-agentskills/issues/8)).

### Removed

- The executed 2026-05-06 docs-hotfix plan and its design spec; the spec broke `mint broken-links` ([#10](https://github.com/toolboxmd/building-agentskills/issues/10)).
