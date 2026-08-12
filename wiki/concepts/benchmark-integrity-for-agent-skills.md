---
title: Benchmark integrity for agent skills
type: concept
tags: [agent-skills, benchmarks, blind-review, retrieval]
created: 2026-08-11
updated: 2026-08-12
related_files: [docs/06-testing/benchmark-integrity.md, case-studies/evidence/2026-08-11-karpathy-wiki-ingest-benchmark.json, case-studies/evidence/2026-08-12-toolboxmd-creating-skills-benchmark.json, benchmarks/toolboxmd-creating-skills/v1/results/2026-08-12/manifest.json]
---

An agent benchmark is valid only when the requested model produced the output independently, candidate runs cannot read prior answers or grading logic, and the score measures the user's eventual task rather than mechanical completion alone.

## Core contract

- Freeze and hash the skill, fixtures, cases, prompt, rubric, and graders.
- Forbid nested model or agentic-CLI delegation and audit command events.
- Isolate each run from memory, sibling runs, failed attempts, prior output, rubrics, and graders.
- Keep the candidate identity map outside the blind-review tree.
- Scan exact binary artifacts as well as text before blind review. Compiled files can embed source paths and treatment labels.
- Give the blind reviewer treatment-neutral deterministic gate results before judging so critical failures enter the frozen verdict rule.
- Grade authored output and held-out retrieval questions before consulting raw evidence.
- Preserve contaminated attempts, exclude them from scoring, and record minimal neutral protocol amendments.
- Validate score arithmetic, cited paths, confidence, and the verdict rule before revealing identity. An invalid replay remains evidence but cannot replace a valid result.
- Report deterministic, lifecycle, semantic, and retrieval scores separately.
- Treat one run per configuration as directional evidence, not a variance estimate.

## Evidence

The 2026-08-11 karpathy-wiki benchmark invalidated one attempt for nested Claude delegation and another for cross-run reads. The strongest valid Spark sample passed 19/21 deterministic assertions but scored 69/100 semantically, demonstrating why runtime correctness and retrieval utility are separate.

The 2026-08-12 creator benchmark reached the same boundary from another direction. The ToolboxMD candidate generated three packages that passed every held-out deterministic check, but it recorded no valid blind wins: one tie, one baseline win, and one pair invalidated by identity-bearing Python bytecode. The candidate was retained as evidence and removed from the active skill path.

That screen used 14 benchmark sessions and 2,064,691 input tokens, of which 1,611,264 were cached, plus 73,053 output tokens. The cost is evidence for a leaner next protocol: use cheap mechanical gates first, make later semantic runs conditional, and spend a tie-breaker case only when it can change the decision. This is a proposed v2 direction, not a variance-backed rule.

See also [[provider-neutral-skill-runtime]].
