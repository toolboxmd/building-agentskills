---
title: Evidence-gated continuous learning from upstream ships
type: idea
tags: [agent-skills, evolution, source-tracking, evidence]
status: proposed
priority: high
created: 2026-08-12
updated: 2026-08-12
related_files: [docs/superpowers/plans/2026-08-12-continuous-learning-handoff.md, docs/12-update-mechanism.md]
---

`building-agentskills` should discover relevant upstream changes automatically while keeping doctrine changes evidence-gated and human-reviewed.

## Proposed boundary

- A deterministic collector finds commits after the last absorbed commit.
- A semantic reviewer classifies events as ignore, case-study candidates, or doctrine candidates.
- A shipped commit, failure artifact, benchmark, or acceptance record must support every proposed lesson.
- Automatic runs may create candidate reports or draft changes, but must not silently rewrite or merge doctrine.
- Local `last_seen` state suppresses repeated scans; durable `last_absorbed` state advances only with a reviewed lesson.

## Initial scope

Start with `karpathy-wiki`, verify loader behavior, and prove a manual read-only source check before adding scheduled discovery or more upstream repositories.

See the active [continuous-learning handoff](../../docs/superpowers/plans/2026-08-12-continuous-learning-handoff.md).
