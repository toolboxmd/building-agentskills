---
name: building-agentskills
description: Use when authoring or auditing an AI agent skill; covers the layered architecture (agent-skills foundation, superpowers conventions, ship-evidenced deltas), the three-question framework (who invokes / what fires on rules / what is the token budget), and pattern catalogs for frontmatter, prose discipline, triggers, iron laws, line budget, prose-change testing, mechanism vs decoration, packaging, evolution, anti-patterns, and cross-platform packaging.
license: Apache-2.0
---

# Building Agent Skills

A layered authoring reference for AI agent skills. This skill is a thin loader; the substance lives in `docs/`.

## The three-question framework

Every skill must answer three questions. They are the hero mental model.

1. **Who invokes?** Agent (auto-trigger by description), user (`/skill-name`), or both? See `docs/02-mental-model.md` and `docs/05-authoring/frontmatter.md` for the `disable-model-invocation` / `user-invocable` taxonomy.
2. **What fires on rules?** Every "must," "always," "never," and numeric threshold in your SKILL.md is decoration (the agent reads and decides) or mechanism (a script, validator exit code, hook, or captured artifact fires on it). Decoration is fine for guidance; mechanism is required for invariants. See `docs/07-mechanism-vs-decoration.md`.
3. **What is the token budget?** Auto-compaction floor is ~5,000 tokens (~500 lines); description listing cap is 1,536 chars combined; total description budget across all skills is 8,000 chars (or 1% of context window). See `docs/04-token-economics.md`.

Read `docs/03-three-questions.md` end-to-end on first contact. Every other doc in this repo is a destination from one of the three questions.

## Iron Law

```
NO SKILL DOC UPDATE WITHOUT A CITED SHIP-EVIDENCE COMMIT
```

Every pattern in this repo cites a real commit, a real failure mode, or a verbatim source. Aspirational patterns do not land. If you propose an addition, name the commit or the documented failure that motivates it.

## The under-500-line discipline

Keep your SKILL.md under 500 lines. The 500-line cap is the auto-compaction survival floor; it is not a stylistic preference. See `docs/04-token-economics.md` for the why and `docs/05-authoring/line-budget.md` for the rule statement and what to do when you push over.

## The three blocker docs (must-read trio for any new author)

1. `docs/01-quickstart.md`: "Your first skill in 10 minutes." The hello-world walkthrough; mirrors the agent-skills spec's 6-line minimal template and Anthropic's personal-scope install path.
2. `docs/02-mental-model.md`: skills vs CLAUDE.md vs hooks vs slash commands. The decision matrix. When is a skill the right primitive at all?
3. `docs/04-token-economics.md`: the why of skill constraints. Hard numbers; calculator for SKILL.md size, description budget, auto-compaction cost, SessionStart-hook injection cost.

Read these three in order before reading anything else. Everything else makes sense once they are in place.

## Documentation map

The full repo. Each entry is one paragraph; follow the link for the full doc.

### `docs/00-overview.md`
The layered architecture explainer. Three layers: agent-skills (Layer 1, the spec foundation), superpowers (Layer 2, the convention layer), this repo (Layer 3, ship-evidenced deltas). Names what each layer adds and what each leaves out.

### `docs/01-quickstart.md` (BLOCKER)
Your first skill in 10 minutes. Pick a name, write minimal frontmatter, drop a SKILL.md in `~/.claude/skills/<name>/`, see it activate.

### `docs/02-mental-model.md` (BLOCKER)
The decision matrix: skills vs CLAUDE.md (always-on facts) vs hooks (event-driven mechanism) vs slash commands (user-initiated). Includes the recent Claude Code unification of custom commands into skills.

### `docs/03-three-questions.md` (HERO)
The three-question framework, deep dive. Worked answers for karpathy-wiki: 476 lines, ~5k tokens, fits 25k auto-compaction budget, three decoration-to-mechanism wirings, agent-only auto-trigger.

### `docs/04-token-economics.md` (BLOCKER)
The why of constraints. 25k auto-compaction budget shared across skills; 5k per-skill survival floor; 1024-char description hard cap; 1536-char Claude Code listing truncation; 8000-char total budget. SessionStart-hook injection cost: ~17.8k tokens / 13 firings / 57 hours measured in superpowers issue #1220.

### `docs/05-authoring/frontmatter.md`
Field-by-field frontmatter reference. Cross-platform-safe column (`name`, `description`, `license`, `compatibility`, `metadata`) vs Claude Code extensions (`when_to_use`, `disable-model-invocation`, `user-invocable`, `argument-hint`, `arguments`, `allowed-tools`, `model`, `effort`, `context: fork` + `agent`, `hooks`, `paths`, `shell`).

### `docs/05-authoring/prose-discipline.md`
Voice (imperative for the agent; third-person for the description; no first-person agent voice; no time-sensitive prose; no emojis) and the snippet-as-code rule (snippets in SKILL.md prose are production code; test verbatim; macOS `wc -c` whitespace gotcha; markdown numbered-list indent leak).

### `docs/05-authoring/triggers.md`
Description as activation contract. Two contrasting shapes: superpowers' "Use when..." enumerative format vs Anthropic PDF skill's long enumerative trigger inventory. The description-pressure-test loop.

### `docs/05-authoring/iron-laws.md`
Four discipline-prose patterns: Iron Law (block-quoted code-fenced single sentence), forbidden-rationalization table, Red Flags list, spirit-vs-letter clause. Each with a karpathy-wiki example.

### `docs/05-authoring/line-budget.md`
The 500-line cap as load-bearing constraint. Why 500 lines specifically: the 5k-token auto-compaction survival floor.

### `docs/06-testing/red-green-for-prose.md`
RED-GREEN-REFACTOR for prose changes. Four sub-modes: prose-as-deletion (multi-pattern grep), prose-as-addition (section-header grep + verbatim-snippet test), prose-as-tightening (BEFORE/AFTER + reviewer reads diff), prose-as-refactor (`wc -l` + reviewer reads diff).

### `docs/06-testing/unit-tests.md`
What to test in a skill. Script unit tests (TDD discipline), pressure scenarios for discipline skills, `skills-ref validate` for spec compliance. The cross-script regression rule: contract-touching changes default to the full test suite.

### `docs/06-testing/tests-that-pass-immediately.md`
The TDD inversion. Two valid cases: regression-pin (test pins existing correct behavior) and mechanism-rehearsal (test rehearses an LLM-mechanism snippet). Plus the cases where the inversion is invalid.

### `docs/07-mechanism-vs-decoration.md`
The standalone deep dive. Sharpened framing of the rule. Three karpathy-wiki v2.2 wirings (index-size threshold, manifest origin contract, validator-blocks-commit). The `paths:` glob as activation gate in reverse.

### `docs/08-packaging-as-plugin.md`
Claude Code plugin packaging from the karpathy-wiki shape. Minimal `.claude-plugin/plugin.json`, skills in `skills/<name>/SKILL.md`, optional `references/`/`scripts/`/`assets/` siblings. Symlink install pattern. The `${CLAUDE_PLUGIN_ROOT}` substitution gotcha and three workarounds.

### `docs/09-evolution.md`
Audit cycle, semver for skills, deprecation strategies, license-of-skills nuance. Reviewer fix-up rate as a quality signal (25-40% is healthy; `<5%` means rubber-stamp; `>50%` means vague plans).

### `docs/10-anti-patterns.md`
The failure modes catalog. Each pattern with a one-line definition, evidence trail (commit citation), and counter (cross-link to the positive form).

### `docs/11-cross-platform/claude-code.md`
Claude Code-specific appendix: per-scope priority, SessionStart-hook injection, `${CLAUDE_PLUGIN_ROOT}`, `disable-model-invocation` / `user-invocable` taxonomy, `paths:` glob.

### `docs/11-cross-platform/codex.md`
Codex CLI: native agent-skills support, optional `agents/openai.yaml` sidecar, multi-agent opt-in via `[features] multi_agent = true`, `AGENTS.md` for persistent context.

### `docs/11-cross-platform/gemini-cli.md`
Gemini CLI does NOT support Agent Skills. Uses Extensions: `~/.gemini/extensions/<name>/` with `gemini-extension.json` + `GEMINI.md` + `commands/*.toml`. Always-on context model, fundamentally different from progressive disclosure.

### `docs/11-cross-platform/others.md`
OpenCode (native, JS plugin, explicit `skill` tool), Cursor (full plugin bundle), Hermes (agentskills.io-compatible), Continue.dev (custom commands not skills), GitHub Copilot CLI (SessionStart hook bridge from v1.0.11+).

### `docs/12-update-mechanism.md`
How new lessons enter this repo. Per-ship retrospectives, reader-submitted issues, quarterly landscape audits. The case-study shape.

### `case-studies/2026-04-25-karpathy-wiki-v2.2.md`
The seed case study. The v2.2 ship retrospective, written for the public audience.

### `examples/minimal-skill/SKILL.md`
A working ~30-line SKILL.md the quickstart references. Copy as a starting point.

## How to use this skill

Read `docs/03-three-questions.md` first; it is the hero framework. Then read the three blocker docs (`01-quickstart.md`, `02-mental-model.md`, `04-token-economics.md`) in order.

For specific authoring questions, jump to the relevant doc via the documentation map above. The cross-link map is dense; following one link usually surfaces the next two you need.

For self-audit, work through `docs/10-anti-patterns.md` against your own SKILL.md. Each anti-pattern has a counter cross-link.
