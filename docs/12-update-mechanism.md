# Update mechanism: how new lessons flow in

This page covers how new lessons enter this repo. v0 ships ONE case study; this file describes how subsequent ones land. The mechanism has three sources: per-ship retrospective, reader-submitted issues, and quarterly landscape audit.

Source: `REVIEWER` G11; `LESSONS` itself as the seed instance.

## Per-ship retrospective

A retrospective is a ship's own debrief. It is written AFTER the ship lands; it documents what worked, what failed, what the existing canon missed, what the ship added.

The v2.2 lessons report (`/Users/lukaszmaj/dev/bigbrain/research/building-agentskills/2026-04-24-lessons-from-v2.2-ship.md`) is the seed instance of this format. It enumerates per-skill load-bearing analysis, patterns the existing meta-skills do not cover, the brainstorming-spec-plan-execute pipeline as gestalt, RED-GREEN-REFACTOR for prose, and case studies of reviewer-driven fix-ups. The shape is a reference for what a retrospective looks like.

### Case-study shape

A case study lives at `case-studies/<date>-<ship-name>.md`. The date is in `YYYY-MM-DD` format; the ship name is a short slug.

Sections in a case study:

- **Ship summary.** What shipped. One paragraph.
- **The architectural cut (if any).** A non-obvious design choice the audit did not name. The v2.2 case study's `sources/` deletion is this section.
- **The decoration-to-mechanism wirings.** For stateful or rule-bearing skills, the specific commits that turned prose-as-wish into script-as-contract.
- **Reviewer-driven fix-ups.** The per-commit narrative of what the reviewer caught. Cite commits explicitly.
- **What worked.** Patterns that paid off. Name them with their cross-link to the relevant doc.
- **What failed.** Patterns that did not. Name what would have caught the failure.
- **What the existing canon missed.** The gap the ship's lessons fill (the patterns the existing meta-skills do not cover).
- **What we missed.** Honest list of things the ship did not catch and known imperfections.

The v2.2 case study (`case-studies/2026-04-25-karpathy-wiki-v2.2.md`) is the worked example.

## Reader-submitted issues

The repo accepts issues for:

- **Pattern requests.** A reader has observed a pattern in their own ship and thinks the repo should document it.
- **Correction requests.** A reader notices a factual error or stale information.
- **Cross-platform updates.** A harness changes its behavior; the repo's coverage should update.
- **Anti-pattern submissions.** A reader has observed a failure mode; the repo's catalog should add it.

The repo does NOT accept:

- **PRs that rewrite the project's voice.** Voice is an editorial choice, not a per-PR negotiation.
- **PRs that add LLM-specific magic.** The repo is cross-platform; vendor-specific patterns live in `docs/11-cross-platform/`.
- **PRs without ship evidence.** Every pattern in the repo cites a real commit or a real failure mode. Aspirational patterns (`in principle this would help`) are out of scope.

## Quarterly landscape audit

The skill-authoring landscape changes faster than any single ship. The Anthropic skills repo gains new categories; Codex CLI adds features; new harnesses appear; existing harnesses change defaults. A quarterly audit catches drift.

The v2.2 ship's landscape report (`/Users/lukaszmaj/dev/bigbrain/research/building-agentskills/2026-04-24-skill-authoring-landscape-2026.md`) is the seed instance. It enumerates state of the art, who is writing skill-authoring guides, the harness landscape, anatomy of a "good" skill, anti-patterns observed in the wild, the quality bar for 2026, source catalog.

The audit cadence: every quarter, re-fetch the canonical sources (agentskills.io spec, Anthropic Claude Code docs, superpowers, the major harnesses' docs). Compare against the repo's current claims; file issues for divergence; update the docs.

## When a lesson lands in the repo

A lesson moves from "observed in a ship" to "documented in this repo" through one of three paths:

1. **Reviewer-driven from a case study.** The ship's case study is reviewed; patterns it surfaces become candidate doc updates.
2. **Issue-driven from reader submission.** A reader files a pattern request; the maintainer reviews and either adds it or declines with rationale.
3. **Audit-driven from the quarterly landscape.** The audit catches drift; updates ship as a maintenance commit.

In all three paths, the lesson must cite ship evidence (a commit, a failure mode, a verbatim source). The `LESSONS` and `LANDSCAPE` reports for v2.2 are the prototype: every claim has a source path or a commit SHA.

## What v0 ships

v0 ships:

- One case study (karpathy-wiki v2.2).
- The patterns that case study surfaced (decoration-vs-mechanism, prose-as-code, subagent reformatting, cross-script regression, spec arithmetic, TDD inversions).
- The cross-platform reference frame (Claude Code, Codex, Gemini CLI, others).
- The hero framework (the three-question framework).
- The blocker docs (Quickstart, Mental Model, Token Economics).
- The loader skill (`skills/building-agentskills/SKILL.md`).
- The example skill (`examples/minimal-skill/SKILL.md`).

v0.1+ will add additional case studies (when 3+ ships exist), the per-ship retrospective template formalized, and CI for SKILL.md validation. See the `Out of scope` section of the v0 plan for the deferred-to-v0.1 list.

## Sources

- `REVIEWER` G11 (per-ship retrospective format).
- `LESSONS` itself (the v2.2 lessons report as the seed retrospective instance).
- `LANDSCAPE` itself (the 2026-04 landscape audit as the seed quarterly-audit instance).

Cross-links: `case-studies/2026-04-25-karpathy-wiki-v2.2.md`.
