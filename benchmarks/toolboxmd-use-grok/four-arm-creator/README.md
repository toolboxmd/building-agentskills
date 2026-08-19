# Four-arm Creator diagnostic for `toolboxmd-use-grok`

This directory records a pre-registered diagnostic comparison of four frozen
Creator packages on one known Grok authoring brief:

| Arm | Creator treatment | Frozen source |
|---|---|---|
| A | legacy ToolboxMD Creator | retained vNext regression fixture |
| B | early Creator vNext | commit `bfbd679fceec4bf2d403b8aca3a4b09d9396340e` |
| C | final Creator vNext | exact reviewed PR 2 commit `20fc268615079ade496e31cc5e55f51bcc5ad3b0` |
| D | current built-in Codex `skill-creator` | local system package copied at freeze time |

The historical raw Grok candidate and the acceptance-refined Grok package are
unranked references. They do not contribute to the Creator score.

The known brief influenced Creator vNext, so this diagnostic cannot establish
general superiority, production promotion, or a default Creator. A reported
winner means only that one frozen treatment led on this one pre-registered
known task under the recorded model and harness.

## Isolation boundary

Each authoring run uses a fresh opaque directory and task-specific `HOME` and
`CODEX_HOME`. The only model-visible skill is the treatment copied to the same
neutral path. Model-generated commands receive:

- a restricted macOS Seatbelt profile with `:minimal` runtime reads;
- read access only to the frozen inputs, frozen harness, and treatment;
- write access only to the run output directory;
- direct network disabled;
- an allow-listed shell environment with no inherited credentials;
- no project instructions, user configuration, rules, plugins, apps, MCP
  servers, bundled skills, memories, goals, web search, or multi-agent tools.

Both a control process and the authoring agent must run the frozen isolation
probe. The probe verifies an allowed input read, denied repository and auth
reads, an allowed output write, a denied network attempt, and absence of
sensitive environment names. Failure in any arm makes the whole comparison
ineligible for ranking.

## Frozen execution conditions

- authoring model: `gpt-5.6-sol`;
- reasoning effort: `medium`;
- Codex CLI: `0.147.0`;
- one fresh authoring context per arm;
- 600-second hard wall-clock cap per arm;
- post-run caps of 750,000 input tokens and 30,000 output tokens;
- no real Grok call;
- no retry unless the pre-registered tied-finalist rule applies;
- exact common prompt in `authoring-prompt.md`;
- exact decision rule and hashes in `preregistration.json`.

## Evaluation boundary

The frozen grader first checks the two-file package, portable frontmatter,
budgets, explicit-only activation language, adapter behavior against a local
fake Grok CLI, failure classification, timeout process-tree cleanup, input and
environment isolation, and automatic-mode fail-closed behavior. Compatibility
with the custom ToolboxMD validator is reported separately and cannot decide
the winner.

An arm with a critical contract failure is not recommendable. Among eligible
arms with no critical failures, a known-task recommendation requires at least
85 utility points and an 8-point lead. Otherwise the result is inconclusive.
The exact scoring weights and held-out admission rule are frozen before any
authoring output exists.
