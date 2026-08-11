---
title: Benchmark integrity for agent skills
type: concept
tags: [agent-skills, benchmarks, blind-review, retrieval]
created: 2026-08-11
updated: 2026-08-11
related_files: [docs/06-testing/benchmark-integrity.md, case-studies/evidence/2026-08-11-karpathy-wiki-ingest-benchmark.json]
---

An agent benchmark is valid only when the requested model produced the output independently, candidate runs cannot read prior answers or grading logic, and the score measures the user's eventual task rather than mechanical completion alone.

## Core contract

- Freeze and hash the skill, fixtures, cases, prompt, rubric, and graders.
- Forbid nested model or agentic-CLI delegation and audit command events.
- Isolate each run from memory, sibling runs, failed attempts, prior output, rubrics, and graders.
- Keep the candidate identity map outside the blind-review tree.
- Grade authored output and held-out retrieval questions before consulting raw evidence.
- Preserve contaminated attempts, exclude them from scoring, and record minimal neutral protocol amendments.
- Report deterministic, lifecycle, semantic, and retrieval scores separately.
- Treat one run per configuration as directional evidence, not a variance estimate.

## Evidence

The 2026-08-11 karpathy-wiki benchmark invalidated one attempt for nested Claude delegation and another for cross-run reads. The strongest valid Spark sample passed 19/21 deterministic assertions but scored 69/100 semantically, demonstrating why runtime correctness and retrieval utility are separate.

See also [[provider-neutral-skill-runtime]].
