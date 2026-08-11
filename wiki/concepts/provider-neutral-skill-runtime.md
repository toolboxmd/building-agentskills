---
title: Provider-neutral skill runtime
type: concept
tags: [agent-skills, provider-adapters, orchestration, configuration]
created: 2026-08-11
updated: 2026-08-11
related_files: [docs/05-authoring/provider-neutral-runtime.md, case-studies/2026-08-11-karpathy-wiki-provider-aware-ingest.md]
---

A semantic skill should own judgment and durable-output rules, while deterministic runtime code owns provider invocation, queue state, concurrency, retries, fallback, heartbeat, completion, and scheduling.

## Core contract

- Store provider, model, effort, and process limits in structured per-user configuration rather than a tracked shell command.
- Translate profiles through provider adapters that build argument arrays without shell evaluation.
- Keep repository identity in tracked configuration and operator choices in ignored local configuration.
- Use one automatic activation owner at a time: session-triggered or scheduled.
- Treat optional quota monitors as advisory; provider CLI results remain authoritative.
- Qualify semantic model quality offline through [[benchmark-integrity-for-agent-skills]], then enforce deterministic completion in production.

## Evidence

Karpathy-wiki commit `877e659` implemented this separation for Claude Code, Codex, and Grok with 90 passing test scripts plus disposable real-harness acceptance.
