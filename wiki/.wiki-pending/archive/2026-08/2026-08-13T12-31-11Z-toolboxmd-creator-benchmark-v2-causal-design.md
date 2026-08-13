---
title: "ToolboxMD creator benchmark v2 causal design"
evidence: "conversation"
evidence_type: "conversation"
capture_kind: "chat-only"
suggested_action: "augment"
suggested_pages: []
captured_at: "2026-08-13T12-31-11Z"
captured_by: "in-session-agent"
propagated_from: null
---

---
title: "ToolboxMD creator benchmark v2 causal design"
orphaned_at: "2026-08-13T12-30-21Z"
reason: "resolver exit 14: half-built wiki (cwd or pointer target missing required files)"
---

---
title: "ToolboxMD creator benchmark v2 causal design"
orphaned_at: "2026-08-13T12-29-56Z"
reason: "headless: cwd unconfigured; user must choose mode (wiki use project|main|both)"
---

# Benchmark v2 direction for ToolboxMD skill creator

On 2026-08-13 the project decided to replace the v1 production-oriented benchmark with a lean daily-use benchmark that measures the behavior users actually need from a skill creator. The v1 result remains valid only as directional evidence for its three declared cases. It did not test implicit triggering, it gave downstream agents explicit paths to generated SKILL.md files, it lacked a no-skill qualification arm, and its blind-review evidence was contaminated in one replay by treatment identity. The v1 outcome therefore does not establish that the frozen ToolboxMD creator is generally worse than the Codex built-in creator.

The v2 causal question has two linked stages. First, hold the authoring task, model, reasoning effort, tools, source material, and downstream task constant while changing only the creator package used to author a target skill. Second, install each generated target skill through normal Codex discovery and issue a natural task prompt that does not name the skill, its path, or its workflow. A positive run counts as triggered only when the event trace shows that the full generated SKILL.md was loaded. Agent self-report is not sufficient.

Every benchmark case must first fail a no-skill qualification run on at least one critical assertion while remaining mechanically achievable by the same model and tools. This prevents benchmarking tasks that a capable model can already solve from a prompt or ordinary source files. All treatments receive the same ordinary workspace inputs. The no-skill arm has no target skill listing. Creator arms have exactly one generated target skill visible through the real skill directory. Other discoverable skills, plugins, apps, memories, network access, and nested agent CLIs are disabled.

The two primary daily-use families are:

1. Meeting notes to follow-ups. A natural request should trigger a generated skill that applies private team conventions, distinguishes decisions from ideas, extracts owners and due dates, updates a tracker, and verifies the result.
2. Weekly notes to a status deck. A natural request should trigger a generated skill that applies a supplied template and private reporting conventions, produces a deterministic deck artifact such as Marp Markdown without relying on another presentation skill, preserves evidence boundaries, and validates the artifact.

A third extracted-data spreadsheet rollup is reserved only if the two primary cases split or one is invalid. It uses CSV inputs rather than OCR so the benchmark measures workflow adherence and validation instead of vision quality.

An independent Grok Build audit, session 019ffb04-7efd-7333-aec2-778fdf65477f, returned GO WITH CHANGES. It agreed that v1 measured the wrong behavior, recommended the meeting and status-deck families, advised keeping a spreadsheet case only as a conditional reserve, recommended a normal budget of roughly 10 to 13 sessions with a hard ceiling near 17, and advised deterministic assertions plus trace and token evidence rather than a costly blind review as the core decision mechanism. It also advised limiting the claim to Codex and treating other harnesses as later portability checks.

Official Agent Skills guidance supports starting with two or three realistic cases, comparing with and without a skill or against a previous version, using clean contexts, recording token and duration data, and preferring deterministic scripts for objective assertions. The official description guidance says the description carries the triggering burden and that a skill is triggered when its full SKILL.md is loaded. Sources:
- https://agentskills.io/skill-creation/evaluating-skills
- https://agentskills.io/skill-creation/optimizing-descriptions
- https://learn.chatgpt.com/docs/build-skills

The intended decision rule is conservative. ToolboxMD is recommended only if it wins both primary cases with no critical regression, or wins the deciding reserve after a one-to-one split. The built-in creator is preferred under the mirror rule. Otherwise the result is mixed or tied. Equal downstream utility at greater uncached token cost is a loss. Repeats are allowed only when they can change the decision, and every invalid or failed run remains inspectable evidence.