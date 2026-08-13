---
title: Benchmark integrity for agent skills
type: concepts
tags: [agent-skills, benchmarks, blind-review, retrieval]
sources:
  - conversation
  - raw/2026-08-13-toolboxmd-creating-skills-benchmark-v2.md
related:
  - /concepts/provider-neutral-skill-runtime.md
related_files: [docs/06-testing/benchmark-integrity.md, case-studies/evidence/2026-08-11-karpathy-wiki-ingest-benchmark.json, case-studies/evidence/2026-08-12-toolboxmd-creating-skills-benchmark.json, benchmarks/toolboxmd-creating-skills/v1/results/2026-08-12/manifest.json, case-studies/2026-08-13-toolboxmd-creating-skills-benchmark-v2.md, case-studies/evidence/2026-08-13-toolboxmd-creating-skills-benchmark-v2.json]
created: "2026-08-11T00:00:00Z"
updated: "2026-08-13T13:42:43Z"
quality:
  accuracy: 5
  completeness: 5
  signal: 5
  interlinking: 4
  overall: 4.75
  rated_at: "2026-08-13T13:42:43Z"
  rated_by: ingester
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

## v2 causal design (2026-08-13)

The project replaced the v1 production-oriented benchmark with a lean daily-use benchmark that measures the behavior users actually need from a skill creator. V1's result stands only as directional evidence for its three declared cases: it did not test implicit triggering, it gave downstream agents explicit paths to generated `SKILL.md` files, it lacked a no-skill qualification arm, and one blind-review replay was contaminated by treatment identity. V1 therefore does not establish that a frozen ToolboxMD creator is generally worse than a built-in creator.

The v2 causal question has two linked stages. First, hold the authoring task, model, reasoning effort, tools, source material, and downstream task constant while changing only the creator package used to author a target skill. Second, install each generated target skill through normal discovery and issue a natural task prompt that does not name the skill, its path, or its workflow. A positive run counts as triggered only when the event trace shows the full generated `SKILL.md` was loaded — agent self-report is not sufficient.

**No-skill qualification gate.** Every benchmark case must first fail a no-skill qualification run on at least one critical assertion while remaining mechanically achievable by the same model and tools, so the benchmark does not measure tasks a capable model can already solve unaided. All treatments receive the same ordinary workspace inputs. The no-skill arm has no target skill listing; creator arms have exactly one generated target skill visible through the real skill directory. Other discoverable skills, plugins, apps, memories, network access, and nested agent CLIs are disabled.

**Case families.** Two primary daily-use families: (1) meeting notes to follow-ups — apply private team conventions, distinguish decisions from ideas, extract owners and due dates, update a tracker, verify the result; (2) weekly notes to a status deck — apply a supplied template and private reporting conventions, produce a deterministic deck artifact (e.g. Marp Markdown) without relying on another presentation skill, preserve evidence boundaries, validate the artifact. A third extracted-data spreadsheet rollup is reserved only if the two primary cases split or one is invalid, using CSV inputs rather than OCR so the case measures workflow adherence and validation rather than vision quality.

**External review.** An independent Grok Build audit (session `019ffb04-7efd-7333-aec2-778fdf65477f`) returned GO WITH CHANGES: it agreed v1 measured the wrong behavior, recommended the meeting and status-deck families, advised keeping the spreadsheet case only as a conditional reserve, recommended a normal budget of roughly 10-13 sessions with a hard ceiling near 17, and advised deterministic assertions plus trace/token evidence over a costly blind review as the core decision mechanism. It also advised limiting the claim to Codex and treating other harnesses as later portability checks. Official Agent Skills guidance (agentskills.io, learn.chatgpt.com) supports starting with two-to-three realistic cases, comparing with/without a skill or against a previous version, using clean contexts, recording token and duration data, and preferring deterministic scripts for objective assertions — a skill is triggered when its full `SKILL.md` is loaded.

**Decision rule.** ToolboxMD is recommended only if it wins both primary cases with no critical regression, or wins the deciding reserve after a one-to-one split. The built-in creator is preferred under the mirror rule; otherwise the result is mixed or tied. Equal downstream utility at greater uncached token cost counts as a loss. Repeats are allowed only when they can change the decision, and every invalid or failed run remains inspectable evidence.

## v2 final result (2026-08-13)

The v2 daily-use benchmark ran under Codex CLI 0.147.0 with `gpt-5.6-sol` at medium reasoning and ended mixed, 1 to 1. Neither creator showed better downstream quality, so the frozen ToolboxMD candidate is not promoted. The built-in creator stays the default only because the challenger did not clear the predeclared two-win gate — this does not establish general built-in superiority.

Both qualifying cases (no-skill run failed at least one critical check) showed the two creators produce equivalent downstream correctness. Meeting follow-ups: no-skill passed 2/8 critical checks; both creator-produced skills passed 7/8 with byte-identical output, missing only on an under-specified fixture (punctuation normalization was never in the private contract). Weekly status deck: no-skill passed 7/8; both generated skills passed 8/8, differing only in harmless whitespace. Each case was decided only by one-run token cost, a low-confidence tie-break: built-in won meeting follow-ups (18,550 vs 21,609 runtime tokens), ToolboxMD won the status deck (23,982 vs 30,228). All four natural positive prompts loaded the full target `SKILL.md` before output creation; zero of four related near-miss prompts triggered it.

ToolboxMD's demonstrated strength is compact activation metadata — descriptions 29.5% and 39.2% shorter with no observed trigger regression. Its demonstrated cost: `SKILL.md` 11.6%/14.1% larger, full packages 29.7%/53.9% larger, and longer authoring time in both cases. Default eval artifacts and delivery checks added cost without a measured downstream-quality gain in this sample.

Product changes for the next ToolboxMD creator candidate: preserve the compact-description pattern; emit current-directory-independent script commands (observed traces needed `.agents/skills/<name>/scripts/...` repair); move comparative/repeated eval ownership to `toolboxmd-benchmarking-skills`; count always-read references as activated core, not progressive disclosure; make Git delivery checks conditional on an explicit repository-delivery request; enforce a measured artifact-deletion pass before freezing. It must ship as a new frozen candidate, not a mutation of the retained v1 snapshot.

Infrastructure note: the first four authoring attempts were discarded before downstream use because both built-in attempts wrote Python bytecode under the protected creator tree; protocol revision 2 disabled bytecode writes and repeated all four arms symmetrically. The reserve spreadsheet case did not run — it needed five more sessions and only one remained under the 17-session ceiling. Sixteen decision sessions used 728,273 uncached-input-plus-output runtime tokens over 2,759 cumulative seconds.

Known limitation carried forward: supporting grader and event-audit scripts were not hashed in the pre-run protocol commitment. Their at-result hashes and retained outputs are inspectable, but the commitment alone cannot prove every supporting tool stayed byte-identical during execution — a gap for the next benchmark's tool-freeze scope. See [case study](../../case-studies/2026-08-13-toolboxmd-creating-skills-benchmark-v2.md) and [evidence manifest](../../case-studies/evidence/2026-08-13-toolboxmd-creating-skills-benchmark-v2.json).

See also [[provider-neutral-skill-runtime]].
