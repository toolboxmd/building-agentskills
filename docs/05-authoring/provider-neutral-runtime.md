# Provider-neutral skills and deterministic runtimes

A skill should describe the judgment an agent must apply. Provider commands, model selection, concurrency, retries, scheduling, and process state belong in a deterministic runtime around the skill. Karpathy-wiki commit [`877e659`](https://github.com/toolboxmd/karpathy-wiki/commit/877e659) shipped this separation for Claude Code, Codex, and Grok after a provider-named skill caused benchmark attribution contamination.

This pattern applies when the same semantic skill may run through more than one model provider or when ingestion continues outside the foreground conversation. It does not mean every prose-only skill needs a dispatcher.

## The ownership cut

| Concern | Owner | Why |
|---|---|---|
| What evidence means | Skill | Requires model judgment |
| What durable output to write | Skill | Requires synthesis and page architecture |
| Provider, model, and reasoning effort | Local profile | Varies by user, machine, quota, and benchmark result |
| CLI arguments and output parsing | Provider adapter | Deterministic and provider-specific |
| Queue claims and concurrency | Dispatcher | Must be atomic and measurable |
| Retry, cooldown, and fallback | Dispatcher | Must not depend on an agent remembering prose |
| Heartbeat and process cleanup | Worker wrapper | Must reflect real process state |
| Validation, archive, and completion | Deterministic completion gate | Must have one terminal outcome |
| Scheduled or session-triggered activation | Lifecycle adapter | Must have exactly one automatic owner |

The skill may state the semantic contract: preserve source boundaries, deduplicate exact evidence, link related knowledge, and defer when evidence is insufficient. It should not construct a Claude, Codex, or Grok command, calculate free slots, or edit run-history state.

## Semantic configuration, not a shell command

A raw setting such as `headless_command = "claude -p"` combines four decisions in one string: provider, executable, invocation mode, and shell parsing. It is difficult to validate, unsafe around quoting, and teaches every downstream agent that Claude is the intended executor.

Use structured profiles instead:

```toml
[ingest]
default_profile = "author"
fallback_profile = "fallback"
max_processes = 4

[ingest.profiles.author]
provider = "codex"
executable = "codex"
model = "example-model"
reasoning_effort = "medium"
max_processes = 3
```

An adapter turns these fields into an argument array. It never evaluates the configuration as shell text. The profile name is user-defined; provider, model, and effort remain explicit and independently testable.

This is what semantic configuration means: configuration names intent and capabilities, while adapter code owns the exact command syntax.

## Split repository identity from operator choices

Tracked configuration should contain shared structural facts: the wiki role, schema version, or creation date. Provider credentials, executable paths, model choices, concurrency, fallback, activation mode, and optional quota tools are per user or machine and should live in an ignored local file.

This split prevents one contributor's subscription, path, or preferred model from becoming a repository default. It also lets the same repository run on a smaller machine with one worker and on a larger machine with more workers without changing tracked files.

Migration from a mixed legacy file should be explicit:

1. Detect the old shape and print one actionable migration command.
2. Offer a complete dry run.
3. Back up the original.
4. Validate temporary outputs before atomic replacement.
5. Preserve unrelated ignore-file lines.
6. Fail without partial mutation.

Commit [`877e659`](https://github.com/toolboxmd/karpathy-wiki/commit/877e659) implements and tests this contract without migrating an existing user wiki.

## Keep lifecycle state simple, but explicit

A filesystem queue is enough when it already models the job lifecycle. Karpathy-wiki retained three states:

```text
pending capture -> processing capture -> archived or failed capture
```

It did not add a database or a second durable job document. The processing filename remained the lease; a heartbeat refreshed it while the wrapper and provider process identifiers made liveness checkable.

The important addition was not more state. It was an unambiguous owner for state transitions:

- the dispatcher claims work atomically;
- the wrapper writes run events and heartbeat;
- the completion gate validates and archives;
- reconciliation requeues a dead stale lease once;
- a live process with a stale heartbeat is surfaced, not duplicated.

Simple state is good when every transition has one owner and is recoverable after interruption.

## One automatic activation owner

Session-triggered and scheduled dispatch are both valid. Running both creates duplicate scans, unnecessary provider calls, and race pressure.

Make activation a local configuration choice:

- `session_start`: the session hook injects the skill and launches one short dispatcher tick;
- `scheduled`: the session hook only injects the skill, while an external scheduler launches short ticks.

The dispatcher itself should be identical in both modes. Activation selects who calls it, not how queue semantics work. A status command should report mismatches such as “scheduled is configured but no scheduler is installed.”

## Optional quota monitors are advisory

A quota utility can improve routing, but it must not become a hidden dependency. Missing, malformed, stale, or timed-out monitor output should fall back to reactive behavior: run the provider CLI and classify its real result.

The provider response is authoritative. A monitor may avoid a known-bad call; it must never make otherwise valid configuration unusable.

## Qualify semantic quality offline

Do not insert a second LLM reviewer after every ingest merely because output quality matters. That doubles cost, adds another failure surface, and still does not guarantee retrieval usefulness.

Instead:

1. Benchmark candidate model/profile combinations on representative sources.
2. Blind-grade authored output and held-out retrieval questions.
3. Choose a qualified default and optional fallback.
4. Enforce only deterministic completion checks in the hot path.
5. Re-run the benchmark when semantic skill instructions materially change.

See [Benchmark integrity](/docs/06-testing/benchmark-integrity) for the isolation and grading protocol.

## Failure semantics that avoid hot loops

Technical and semantic outcomes are different:

- transient provider errors consume a bounded retry;
- rate limits set a cooldown and can release the slot to a fallback without consuming an attempt;
- authentication or capability failures use a bounded cooldown rather than immediate repetition;
- exhausted technical work moves to a failed queue;
- insufficient source evidence is deferred as `needs_more_detail`, not repeatedly retried.

The exact labels vary by system. The general rule is stable: retry only outcomes that repetition can plausibly fix.

## Evidence

- [`877e659`](https://github.com/toolboxmd/karpathy-wiki/commit/877e659) replaces direct spawning with a bounded provider-aware dispatcher and 90 passing test scripts.
- [Codex Spark acceptance](https://github.com/toolboxmd/karpathy-wiki/blob/877e659/tests/acceptance/dispatcher/2026-08-11-codex-spark-medium.md) verifies provider/model/effort attribution, duplicate handling, augmentation, missing quota-monitor behavior, and clean terminal state.
- [Clean-session and scheduler acceptance](https://github.com/toolboxmd/karpathy-wiki/blob/877e659/tests/acceptance/dispatcher/2026-08-11-clean-session-and-scheduler.md) verifies mutually exclusive activation and a real temporary macOS scheduler lifecycle.

Cross-links: [Mechanism vs decoration](/docs/07-mechanism-vs-decoration), [Benchmark integrity](/docs/06-testing/benchmark-integrity), [Provider-aware ingest case study](/case-studies/2026-08-11-karpathy-wiki-provider-aware-ingest).
