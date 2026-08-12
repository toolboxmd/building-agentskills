---
title: Continuous learning from upstream skill ships — handoff
status: READY FOR DESIGN REVIEW
date: 2026-08-12
owner: lukemaj
scope: building-agentskills general repository
related:
  - docs/12-update-mechanism.md
  - case-studies/2026-08-11-karpathy-wiki-provider-aware-ingest.md
  - docs/05-authoring/provider-neutral-runtime.md
  - docs/06-testing/benchmark-integrity.md
---

# Continuous learning from upstream skill ships — handoff

## Outcome

Continue developing `building-agentskills` as a general, evidence-backed doctrine repository. Work completed in `karpathy-wiki` should be discoverable automatically, but it should enter this repository only after it becomes a verified, reusable lesson.

The intended system is:

```text
upstream change detected
  -> candidate event recorded
  -> ship evidence qualified
  -> case-study or doctrine change drafted
  -> focused validation
  -> human review and merge
  -> absorbed checkpoint advanced
```

Automatic discovery is desirable. Automatic doctrine mutation and automatic merge are not.

## Shipped state

The last doctrine ship before this handoff is commit `a87d457` (`docs: add provider-neutral runtime benchmark lessons`). That commit is already on `origin/main` and added the evidence-backed result of the `karpathy-wiki` provider-aware ingest work:

- `docs/05-authoring/provider-neutral-runtime.md`
- `docs/06-testing/benchmark-integrity.md`
- `case-studies/2026-08-11-karpathy-wiki-provider-aware-ingest.md`
- `case-studies/evidence/2026-08-11-karpathy-wiki-ingest-benchmark.json`
- navigation, loader, anti-pattern, test, and project-wiki updates supporting those lessons

The core additions were verified before being committed and pushed. No continuous source watcher or `/check-sources` workflow has been implemented yet.

## Local state that is not shipped

Two pre-existing files are untracked:

- `TODO.md`
- `docs/superpowers/specs/2026-05-06-drift-prevention-and-check-sources-design.md`

They contain valuable earlier thinking about loader verification, freshness gates, source declarations, and a `/check-sources` workflow. They are drafts based on the older `bd1b61c` baseline, not repository truth. Preserve them and review them; do not execute the six-commit plan verbatim or include the files in a commit accidentally.

The most important correction to the older draft is checkpoint semantics:

- `last_seen` is runtime convenience and may remain local and ignored;
- `last_absorbed` is durable repository state and advances only when the corresponding lesson change is reviewed and merged.

A single checkpoint advanced immediately after scanning can permanently hide a source event that was seen but never accepted.

## Decisions already made

1. This work changes the general `building-agentskills` repository. It does not migrate or specialize a Naturbiss wiki.
2. Start with `karpathy-wiki` as the first upstream source. Prove the loop before adding `obra/superpowers` or more repositories.
3. Detect upstream changes broadly, but promote only qualified ship events.
4. Keep collection deterministic and lesson extraction semantic.
5. A candidate can draft a case study, documentation delta, evidence manifest, and pull request. A human accepts or rejects the lesson.
6. Repository content remains English.
7. Tests must be proportional: exercise parsers, checkpoints, classification contracts, generated artifacts, and failure recovery; do not require one new test per prose paragraph.

## Qualification boundary

An upstream event is eligible for a doctrine proposal only when all of the following are true:

- implementation or operational evidence exists, rather than only a plan;
- the relevant commit, failure artifact, benchmark, or acceptance record can be cited;
- the lesson is reusable outside the source repository;
- the claim states what the evidence proves and what it does not prove;
- the proposal names whether it adds a new pattern, changes an existing pattern, or belongs only in a case study.

Examples of events that should normally remain unabsorbed:

- formatting-only commits;
- speculative designs without a shipped result;
- local fixes with no reusable authoring lesson;
- benchmark scores without attribution and read-isolation evidence;
- repeated statements of a lesson already represented in the doctrine.

## Recommended implementation sequence

### Milestone 0 — verify the loader

Resolve the blocker described in `TODO.md` before depending on the loader for automation:

1. Verify current Claude Code plugin skill-discovery behavior against current primary documentation instead of assuming the draft's manifest diagnosis is correct.
2. Verify Codex discovery through this repository's `AGENTS.md` plus the installed skill.
3. Run fresh-session trigger smoke tests using realistic authoring and audit prompts.
4. Record the exact provider, installation method, prompt, observed activation, and result.

### Milestone 1 — read-only source check

Build the smallest end-to-end path for one source:

1. A tracked `karpathy-wiki` source declaration names its repository, branch, and durable absorbed commit.
2. A deterministic collector lists commits after the absorbed commit and writes a run-local candidate report.
3. A semantic reviewer classifies each candidate as `ignore`, `case-study-candidate`, or `doctrine-candidate`, with evidence citations and a short rationale.
4. The command makes no doctrine edits and advances no absorbed checkpoint.

Run this manually until its boundaries are trustworthy.

### Milestone 2 — reviewed draft generation

For accepted candidates, generate a reviewable change set:

- case study and evidence manifest first;
- doctrine delta only when the case reveals a reusable gap;
- navigation, loader, generated public artifacts, and project wiki updated when their contracts require it;
- focused tests plus the full suite only when shared contracts are touched;
- no automatic merge.

Advance `last_absorbed` in the same reviewed commit as the accepted lesson. Rejected candidates may update only local `last_seen` state or an explicit durable rejection ledger if repeated rediscovery becomes a measured problem.

### Milestone 3 — scheduled discovery

After at least two correct manual source checks and one correct draft-generation cycle, add a schedule. Prefer a repository-level scheduled workflow for public upstream Git history; use a local scheduler only for sources that require local authentication or local artifacts.

The scheduled path should create or update one candidate report or draft pull request. It should not open duplicate work for the same commit range and should not merge.

## First task for the next agent

Do not begin with the full automation implementation. First:

1. inspect `a87d457` and the current working tree;
2. read both untracked drafts without modifying them;
3. verify the loader gap with current primary documentation and fresh-session evidence;
4. compare the older drift-prevention spec with this handoff;
5. present a revised Milestone 0–1 design for user approval, including exact state files, checkpoint transitions, and the minimum tests.

The first design should explicitly answer:

- who invokes the source check now and after scheduling;
- what deterministic mechanism prevents lost or duplicate candidate ranges;
- what token and model budget the semantic classification consumes;
- which facts are tracked repository state versus ignored per-run state;
- what evidence allows a candidate to become doctrine.

## Completion contract for the next milestone

Milestone 0–1 is not complete until:

- loader behavior is evidenced rather than assumed;
- the same upstream range can be checked twice without duplicate durable output;
- a seen-but-unaccepted event remains recoverable;
- no doctrine file changes during read-only mode;
- invalid source configuration fails clearly;
- tests, commit state, and push state are reported separately.
