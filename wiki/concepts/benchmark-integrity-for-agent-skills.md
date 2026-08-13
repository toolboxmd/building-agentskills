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
updated: "2026-08-13T18:18:46Z"
quality:
  accuracy: 5
  completeness: 5
  signal: 5
  interlinking: 4
  overall: 4.75
  rated_at: "2026-08-13T18:18:46Z"
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

The 2026-08-12 creator benchmark reached the same boundary from another direction, but its raw model-event JSONL was not retained. All 15 compact event audits record command execution and none has independently verifiable environment, filesystem, and network isolation evidence. A post-result correction therefore made all 15 streams and all three creator comparisons ineligible without reconstructing missing commands. The deterministic checks and blind judgments, including a recorded tie and built-in preference, remain diagnostic only. The candidate stays outside the active skill path because it did not clear its promotion gate, not because v1 established a better creator.

That screen recorded 14 benchmark sessions and 2,064,691 input tokens, of which 1,611,264 were cached, plus 73,053 output tokens. Those measurements are diagnostic, not eligible comparative cost evidence. They motivated a leaner next protocol: use cheap mechanical gates first, make later semantic runs conditional, and spend a tie-breaker case only when it can change the decision. This is a protocol hypothesis, not a variance-backed rule.

## v2 causal design (2026-08-13)

The project replaced the v1 production-oriented benchmark with a lean daily-use benchmark that measures the behavior users actually need from a skill creator. V1 retains diagnostic artifacts for its three declared cases, but zero eligible comparisons: it did not test implicit triggering, it gave downstream agents explicit paths to generated `SKILL.md` files, it lacked a no-skill qualification arm, one pair leaked treatment identity, and every retained compact event audit lacks trust-bearing isolation evidence. V1 therefore does not establish that either creator is better.

The v2 causal question has two linked stages. First, hold the authoring task, model, reasoning effort, tools, source material, and downstream task constant while changing only the creator package used to author a target skill. Second, install each generated target skill through normal discovery and issue a natural task prompt that does not name the skill, its path, or its workflow. A positive run counts as triggered only when the event trace shows the full generated `SKILL.md` was loaded — agent self-report is not sufficient.

**No-skill qualification gate.** Every benchmark case must first fail a no-skill qualification run on at least one critical assertion while remaining mechanically achievable by the same model and tools, so the benchmark does not measure tasks a capable model can already solve unaided. All treatments receive the same ordinary workspace inputs. The no-skill arm has no target skill listing; creator arms have exactly one generated target skill visible through the real skill directory. Other discoverable skills, plugins, apps, memories, network access, and nested agent CLIs are disabled.

**Case families.** Two primary daily-use families: (1) meeting notes to follow-ups — apply private team conventions, distinguish decisions from ideas, extract owners and due dates, update a tracker, verify the result; (2) weekly notes to a status deck — apply a supplied template and private reporting conventions, produce a deterministic deck artifact (e.g. Marp Markdown) without relying on another presentation skill, preserve evidence boundaries, validate the artifact. A third extracted-data spreadsheet rollup is reserved only if the two primary cases split or one is invalid, using CSV inputs rather than OCR so the case measures workflow adherence and validation rather than vision quality.

**External review.** An independent Grok Build audit (session `019ffb04-7efd-7333-aec2-778fdf65477f`) returned GO WITH CHANGES: it agreed v1 measured the wrong behavior, recommended the meeting and status-deck families, advised keeping the spreadsheet case only as a conditional reserve, recommended a normal budget of roughly 10-13 sessions with a hard ceiling near 17, and advised deterministic assertions plus trace/token evidence over a costly blind review as the core decision mechanism. It also advised limiting the claim to Codex and treating other harnesses as later portability checks. Official Agent Skills guidance (agentskills.io, learn.chatgpt.com) supports starting with two-to-three realistic cases, comparing with/without a skill or against a previous version, using clean contexts, recording token and duration data, and preferring deterministic scripts for objective assertions — a skill is triggered when its full `SKILL.md` is loaded.

**Decision rule.** ToolboxMD is recommended only if it wins both primary cases with no critical regression, or wins the deciding reserve after a one-to-one split. The built-in creator is preferred under the mirror rule; otherwise the result is mixed or tied. Equal downstream utility at greater uncached token cost counts as a loss. Repeats are allowed only when they can change the decision, and every invalid or failed run remains inspectable evidence.

## v2 final result (2026-08-13)

The v2 daily-use benchmark ran under Codex CLI 0.147.0 with `gpt-5.6-sol` at medium reasoning. A stricter post-result isolation audit changed the verdict from mixed, 1 to 1, to inconclusive. All 15 command-bearing retained streams lack recorded trusted evidence for a sanitized environment, filesystem read and write confinement, and syscall-level network enforcement. This includes all eight scored streams, both no-skill qualifications, the infrastructure preflight, and four discarded authoring streams. Zero cases qualify and zero paired creator comparisons remain eligible. The frozen ToolboxMD candidate is not promoted, and no creator or cost winner was established.

Meeting follow-ups passed 2/8 critical checks without a skill; the two retained generated packages then passed 7/8 and produced byte-identical output. Weekly status deck passed 7/8 without a skill; both generated packages passed 8/8. Those qualifications and all four positive activation traces are command-bearing and ineligible, so their grades and loads are diagnostic only. The two zero-command near-miss streams remain eligible for the narrow observation that none of four exposed target skills loaded.

The retained ToolboxMD descriptions were 29.5% and 39.2% shorter, while its packages had larger `SKILL.md` files, larger total size, and longer authoring time. None of these differences is eligible comparative evidence. They motivate hypotheses for a smaller next candidate and a clean re-benchmark.

Product changes for the next ToolboxMD creator candidate: preserve the compact-description pattern; emit current-directory-independent script commands (observed traces needed `.agents/skills/<name>/scripts/...` repair); move comparative/repeated eval ownership to `toolboxmd-benchmarking-skills`; count always-read references as activated core, not progressive disclosure; make Git delivery checks conditional on an explicit repository-delivery request; enforce a measured artifact-deletion pass before freezing. It must ship as a new frozen candidate, not a mutation of the retained v1 snapshot.

Infrastructure note: the first four authoring attempts were discarded before downstream use because both built-in attempts wrote Python bytecode under the protected creator tree; protocol revision 2 disabled bytecode writes and repeated all four arms symmetrically. The reserve spreadsheet case did not run — it needed five more sessions and only one remained under the 17-session ceiling. Sixteen decision sessions used 728,273 uncached-input-plus-output runtime tokens over 2,759 cumulative seconds.

The corrected auditor uses one trust boundary: any `command_execution` event, including a started or incomplete event, requires a separate independently verifiable harness or enforcement artifact for environment sanitization, filesystem read and write confinement, and syscall-level network enforcement. Historical JSONL records none. Detailed checks for parent traversal, literal paths, Git, environment expansion, shell wrappers, and interpreter payloads remain diagnostic reasons, but parser completeness is not proof of strict isolation. Re-auditing all 17 retained streams made 15 ineligible with zero model sessions added. Only the two zero-command near-miss streams remain narrowly eligible. A future command-bearing benchmark must add the trust-bearing evidence channel before it can qualify.

The same invariant applies to v1. Its 15 compact audit records all contain positive command counts and no trusted evidence, so all are ineligible. Because their raw model-event JSONL was not retained, the correction does not claim an exact-command re-audit. It preserves the original compact reasons, usage, judgments, grades, generated skills, and outputs as diagnostic history while withdrawing eligible tie, winner, quality, cost, and trigger claims.

Known limitation carried forward: supporting grader and event-audit scripts were not hashed in the pre-run protocol commitment. Their at-result hashes and retained outputs are inspectable, but the commitment alone cannot prove every supporting tool stayed byte-identical during execution. See [case study](../../case-studies/2026-08-13-toolboxmd-creating-skills-benchmark-v2.md) and [evidence manifest](../../case-studies/evidence/2026-08-13-toolboxmd-creating-skills-benchmark-v2.json).

See also [[provider-neutral-skill-runtime]].
