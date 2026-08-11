# Case study: karpathy-wiki provider-aware ingest ship

- **Date:** 2026-08-11
- **Subject:** karpathy-wiki bounded provider-aware dispatcher
- **Implementation:** [`877e659`](https://github.com/toolboxmd/karpathy-wiki/commit/877e659)
- **Baseline:** `990cb20`
- **Verification:** 90 test scripts passed, 0 failed; disposable Codex and clean-session/scheduler acceptance completed
- **Benchmark evidence:** [condensed machine-readable manifest](/case-studies/evidence/2026-08-11-karpathy-wiki-ingest-benchmark.json)

This ship separated a semantic wiki-ingestion skill from its provider and lifecycle runtime. The same ingest procedure can now run through Claude Code, Codex, or Grok profiles while one bounded dispatcher owns claims, concurrency, fallback, retries, cooldowns, heartbeat, completion, and scheduling.

The implementation was motivated by two different problems: production ingestion needed bounded resumable execution, and model selection needed a benchmark that measured whether the resulting wiki was useful to query. Treating these as separate systems became the central architectural decision.

## Ship summary

Commit [`877e659`](https://github.com/toolboxmd/karpathy-wiki/commit/877e659) replaced direct provider spawning with:

- structured provider/model/effort profiles;
- a tracked structural config and ignored per-user runtime config;
- global and per-profile concurrency ceilings;
- a default profile plus optional fallback;
- rate-limit cooldowns and bounded technical retries;
- a processing-file heartbeat and dead-worker reconciliation;
- deterministic validation, archive, and terminal run events;
- mutually exclusive SessionStart and scheduled activation;
- optional quota-monitor preflight with reactive fallback;
- provider-neutral ingest instructions;
- disposable real-harness acceptance.

No existing user wiki was used as a migration target or fixture.

## The architectural cut

The first design idea was to make the skill directly run a configurable “headless command.” That looked simple but kept provider identity, shell parsing, concurrency, and job state mixed into semantic prose.

The final cut created three layers:

1. **Skill:** decides what knowledge to author, how to preserve claims, how to deduplicate, and how to link pages.
2. **Provider adapter:** translates a structured profile into an argument array and classifies provider result channels.
3. **Dispatcher and worker:** own queue state, leases, retries, fallback, heartbeat, process cleanup, and deterministic completion.

The separation is documented in [Provider-neutral skills and deterministic runtimes](/docs/05-authoring/provider-neutral-runtime).

## Benchmark before runtime selection

The frozen ingest benchmark compared one low, medium, and high reasoning run of the same Spark model. Every run processed the same three sequential cases: cold start, exact duplicate, and related augmentation.

| Effort | Deterministic assertions | Blind semantic score | Retrieval full / partial / none | Duration | Clean final state |
|---|---:|---:|---:|---:|---|
| Low | 16 / 21 | 55 / 100 | 1 / 6 / 1 | 766 s | No |
| Medium | 19 / 21 | 69 / 100 | 3 / 5 / 0 | 480 s | Yes |
| High | 17 / 21 | 54 / 100 | 1 / 7 / 0 | 737 s | No |

Medium was the strongest sample and the fastest. The benchmark had one run per configuration, so this is a directional result, not a variance estimate or a universal claim that medium effort beats high.

More importantly, 19/21 deterministic checks still produced only 69/100 semantic quality. Green lifecycle evidence did not mean the authored wiki was complete. All candidates materially under-extracted the customer-research source.

## Two invalid attempts that improved the harness

### Nested model delegation

The first contaminated Spark attempt completed the cold case itself, then invoked `claude -p` during the duplicate case. The frozen skill called itself a Claude ingester and the old config named Claude, so the model followed the original runtime identity instead of acting as the ingester under test.

The attempt was stopped and excluded. The harness gained a neutral attribution guard: the model under test must perform the task itself and may not invoke another model, agent, subagent, or agentic CLI. A transcript audit verifies the guard.

### Cross-run read leakage

The first medium attempt searched global memory, sibling run output, and deterministic grader code before its first wiki write. It had access to clues about prior behavior and expected checks, so it was not independent.

The attempt was stopped before producing a candidate wiki and excluded. The harness gained a read-isolation boundary: each run may read only its own wiki, task evidence, frozen skill, frozen plugin, and files directly referenced by the skill.

Both failures are documented as benchmark evidence rather than hidden cleanup. See [Benchmark integrity](/docs/06-testing/benchmark-integrity).

## Deterministic runtime mechanisms

The ship converted several process promises into code-backed contracts:

- “at most N ingests” became an atomic dispatcher lock plus slot leases;
- “retry later after a limit” became cooldown events with explicit reset times;
- “fallback when default is unavailable” became immediate slot refill using the next qualified profile;
- “processing means live work” became heartbeat plus wrapper/provider process identifiers;
- “do not duplicate a live worker” became reconciliation that distinguishes stale heartbeat from dead processes;
- “finish cleanly” became one completion script that validates, archives, closes the run, and commits;
- “do not retry missing evidence” became a deferred `needs_more_detail` state;
- “scheduled mode” became a real lifecycle adapter, not SessionStart plus a cron racing each other.

This is the same decoration-to-mechanism principle as v2.2, applied to orchestration rather than page rules.

## Configuration lessons

The tracked config now contains repository identity. The ignored local config contains provider profiles, model identifiers, reasoning effort, process limits, activation mode, routing, and optional quota-monitor settings.

That split matters for distributable skills:

- a contributor's subscription and executable path do not become repository policy;
- weak and strong machines can use different concurrency without tracked diffs;
- users without the optional quota monitor still have a fully valid wiki;
- model selection can change after a benchmark without changing the semantic skill;
- the runtime can validate provider, executable, model, and effort separately.

Legacy mixed configuration migrates only through explicit dry-run, backup, validation, and atomic replacement. The implementation acceptance used disposable fixtures, not a live wiki.

## Real-harness acceptance findings

Unit and integration tests were necessary but not sufficient.

The disposable Codex acceptance found that an operator-level Codex option incompatible with Spark leaked into the run. The adapter was changed to ignore unrelated user model configuration while preserving authentication.

The same acceptance found a local Europe/Warsaw timestamp labeled with `Z`. Page instructions and regression coverage now require a UTC clock.

Clean Claude sessions verified both activation modes. A temporary real macOS LaunchAgent installed, ran one bounded tick, uninstalled, restored SessionStart mode, and left no matching process or scheduler artifact.

The acceptance records are public at [Codex Spark medium](https://github.com/toolboxmd/karpathy-wiki/blob/877e659/tests/acceptance/dispatcher/2026-08-11-codex-spark-medium.md) and [clean sessions plus scheduler](https://github.com/toolboxmd/karpathy-wiki/blob/877e659/tests/acceptance/dispatcher/2026-08-11-clean-session-and-scheduler.md).

## What worked

- Freezing the semantic benchmark before implementation separated model quality from runtime correctness.
- Blind retrieval grading exposed missing durable knowledge that deterministic checks could not.
- Preserving contaminated attempts made the protocol amendments auditable.
- Rule-to-owner mapping kept semantic judgment in the skill and process invariants in code.
- A filesystem queue remained sufficient once claims, heartbeat, and terminal transitions had explicit owners.
- Disposable real-harness acceptance caught configuration and timestamp defects missed by unit tests.
- Optional infrastructure degraded to reactive behavior instead of becoming an installation prerequisite.

## What failed

- Provider identity embedded in the frozen skill caused nested delegation in the first Spark attempt.
- Broad filesystem search let an ostensibly independent run read memory, siblings, and grader code.
- Initial runtime review missed executable-mode risk; real lifecycle acceptance was needed to prove entrypoints worked outside the development shell.
- Concurrency review found races beyond happy-path tests: one worker completion could erase another worker's cooldown, and a provider error could leave its process group alive.
- Treating “zero exit” as completion was insufficient; the runtime needed explicit terminal state and archive evidence.

## What the existing canon missed

- **Provider-neutral semantic skill plus provider-specific adapter.** Cross-platform packaging guidance does not explain how one semantic procedure safely drives multiple agentic CLIs.
- **Attribution integrity in model benchmarks.** A model can delegate to the provider named by the skill, invalidating the comparison while still producing plausible output.
- **Read isolation for agentic benchmarks.** Agent memory and broad repository search are experimental inputs unless explicitly excluded.
- **Retrieval-first wiki grading.** Successful ingest and valid files do not prove a future agent can recover the knowledge.
- **Offline qualification instead of an LLM reviewer in the hot path.** Semantic model selection and deterministic production completion are separate controls.
- **Activation-owner exclusivity.** Session hooks and schedulers should call the same dispatcher, but only one may be automatic for a given installation.

## What we missed

- The benchmark used one run per effort. It ranks these samples but does not estimate stochastic variance.
- None of the Spark candidates reached the “strong” semantic band; production author selection still depends on the broader multi-model benchmark.
- Automatic scheduler support ships only for macOS. Other systems can call the portable tick from their scheduler, but systemd and Windows adapters remain future work.
- The ship supports three provider adapters, not an arbitrary plugin API for third-party adapters.
- The benchmark evidence is condensed here; raw transcripts remain outside this public repository and are represented by hashes in the evidence manifest.

## What this case study changes in this repo

It adds two Layer-3 patterns:

- [Provider-neutral skills and deterministic runtimes](/docs/05-authoring/provider-neutral-runtime)
- [Benchmark integrity for agent skills](/docs/06-testing/benchmark-integrity)

It also expands the anti-pattern catalog with provider identity leakage and contaminated benchmarks. These additions cite the shipped implementation commit and the recorded invalid attempts rather than proposing an aspirational architecture.

## Sources

- [`877e659`](https://github.com/toolboxmd/karpathy-wiki/commit/877e659), the implementation commit.
- [Implementation and verification plan](https://github.com/toolboxmd/karpathy-wiki/blob/877e659/docs/planning/2026-08-11-bounded-provider-aware-ingest-dispatcher-implementation.md).
- [Benchmark evidence manifest](/case-studies/evidence/2026-08-11-karpathy-wiki-ingest-benchmark.json).
- [Codex Spark medium acceptance](https://github.com/toolboxmd/karpathy-wiki/blob/877e659/tests/acceptance/dispatcher/2026-08-11-codex-spark-medium.md).
- [Clean-session and scheduler acceptance](https://github.com/toolboxmd/karpathy-wiki/blob/877e659/tests/acceptance/dispatcher/2026-08-11-clean-session-and-scheduler.md).

Cross-links: [Provider-neutral runtime](/docs/05-authoring/provider-neutral-runtime), [Benchmark integrity](/docs/06-testing/benchmark-integrity), [Mechanism vs decoration](/docs/07-mechanism-vs-decoration), [Update mechanism](/docs/12-update-mechanism).
