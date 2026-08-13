---
title: Creator vNext and toolboxmd-use-grok program
status: APPROVED, STEPS 1-3 COMPLETE
date: 2026-08-13
owner: lukemaj
scope: building-agentskills product and evidence workflow
depends_on:
  - pull request 1, toolboxmd-creating-skills benchmark v2
  - benchmarks/toolboxmd-creating-skills/v2/results/2026-08-13/recommendations.md
---

# Creator vNext and `toolboxmd-use-grok` program

## Outcome

Complete one evidence-gated sequence that turns the creator benchmark into a
smaller creator candidate, dogfoods that candidate on a real Grok Build
integration, and then makes a bounded promotion decision.

The sequence has two product outputs:

1. a simplified `toolboxmd-creating-skills` vNext candidate;
2. a working `toolboxmd-use-grok` skill for explicit Grok consultation and
   opt-in automatic review of mature implementation plans.

The Grok skill replaces the previously proposed inbox-response example in
step 4. It is a real product and dogfooding case, not a disposable fixture.

## Claim boundary

The vNext creator delta is limited to findings already supported by benchmark
v2. The Grok use case must not introduce Grok-specific rules into the creator
before the creator candidate is frozen.

Because the Grok brief is known while this program is being planned, its result
is developmental and operational evidence. It is not, by itself, a blind or
general ranking proof for all skill creators. Any release claim must say this
explicitly.

The base Grok brief can diagnose whether vNext exhibits the intended changes,
but it cannot promote vNext. Freeze a small held-out paraphrase and
fault-injection set only after the creator candidate is frozen. That set may
contribute to a narrow promotion decision because it was not used to author the
revision.

## Non-goals

- Do not merge any pull request without explicit user approval.
- Do not change retained v1 or v2 benchmark artifacts.
- Do not build a generic multi-harness framework before a second real adapter
  demonstrates which abstractions are actually shared.
- Do not add queues, schedulers, provider voting, or automatic agent ping-pong.
- Do not let automatic Grok review edit the repository.
- Do not make automatic external data transfer the public marketplace default.
- Do not stage or modify the protected local drafts named in `AGENTS.md`.

## Step 1: close the benchmark PR review gate

Keep pull request 1 limited to benchmark v1 and v2 evidence, doctrine changes,
and the associated project-wiki record.

1. Request `@codex review` against the current PR HEAD.
2. Monitor until the review covers that HEAD or a real blocker is confirmed.
3. Verify every non-outdated finding before changing anything.
4. Apply only fixes that preserve frozen generated evidence and the benchmark's
   claim boundary.
5. Re-run proportionate checks, push any fix, and request a new review.
6. Finish only when checks pass and no actionable review thread remains.
7. Leave the PR unmerged until the user explicitly approves merge.

Current request evidence:

- PR: `https://github.com/toolboxmd/building-agentskills/pull/1`
- requested review comment:
  `https://github.com/toolboxmd/building-agentskills/pull/1#issuecomment-5282336595`
- reviewed target HEAD: `9ebbd06603e74bee7729eb7d2c956ace670ae8e3`

Completion evidence, 2026-08-13:

- final reviewed parent HEAD: `e07502f2ced07917acdc8d7d3f8e5ad6f9301595`;
- corrected v1 and v2 each retain zero eligible creator comparisons;
- checks passed and no actionable current-HEAD review thread remained;
- pull request 1 remains unmerged pending explicit user approval.

## Step 2: build `toolboxmd-creating-skills` vNext

Create a new frozen creator candidate on a stacked branch. Implement only the
changes supported by benchmark v2:

1. Preserve compact descriptions and explicit trigger exclusions.
2. Make generated script commands independent of the task working directory.
3. Warn mechanically about bare `python3 scripts/`, `node scripts/`, and
   `bash scripts/` examples without a documented skill-directory resolution.
4. Stop packaging comparative or repeated eval artifacts by default.
5. Keep package-local tests only when they validate a justified deterministic
   script or an explicit distribution contract.
6. Count references loaded on every invocation as activated core. Inline short,
   load-bearing rules or justify the separate file.
7. Run Git delivery checks only when repository delivery was requested.
8. Add a final artifact-budget deletion pass with evidence for every support
   file.
9. Keep Python bytecode and ancestor Git discovery isolated in all test runs.

Do not rewrite the retained creator snapshot. The result is a new candidate
with its own hash and package inspection.

Completion evidence, 2026-08-13:

- product: `skills/toolboxmd-creating-skills/`;
- exact package: three files, 23,496 bytes, aggregate SHA-256
  `e76c24dda94e6228cdad895b3fc0abe89c22558bbdce7c11c9d062f66cd5212f`;
- activated core: 114 lines and 6,353 bytes, with a 278-character
  description, zero references, zero evals, and one read-only validator;
- freeze and claim boundary:
  `benchmarks/toolboxmd-creating-skills/vnext/manifest.json`;
- the delta answers diagnostic failure patterns only. It supports no creator
  superiority or promotion claim.

## Step 3: run a cheap deterministic regression check

Before any new comparative model run, replay the known meeting-followups and
weekly-status-deck authoring contracts as a regression screen.

Check mechanically that vNext:

- retains valid portable frontmatter and compact activation contracts;
- emits no fragile working-directory-dependent commands;
- performs no unconditional ancestor Git inspection for package-only work;
- removes unjustified default eval artifacts;
- reduces activated core or supplies evidence for every retained byte;
- retains working validators and the previously promised behavior;
- does not mutate creator inputs or write Python bytecode into protected trees.

This step answers only whether the observed problems were fixed without a
known regression. It is not a new superiority benchmark. Stop and repair the
candidate if this gate fails.

Completion evidence, 2026-08-13:

- `tests/toolboxmd-creating-skills-vnext.test.sh` passes from an external
  working directory;
- the test reproduces the package freeze and budgets, checks exit codes 0/1/2,
  blocks fragile bare script paths, accepts the explicit `<skill-dir>`
  contract, detects the retained meeting and deck baggage patterns, disables
  Python bytecode writes, and proves retained creator inputs were not mutated;
- zero model sessions were run, so this is a deterministic regression screen,
  not a new creator comparison.

## Step 4: build and verify `toolboxmd-use-grok`

Use the frozen vNext creator to produce the first candidate, retain that raw
candidate, and refine only in response to observed acceptance failures.

### Invocation modes

The skill has two modes:

1. **Explicit consultation.** Trigger when the user asks to ask, send, pass,
   delegate for review, or obtain an opinion from Grok or Grok Build.
2. **Automatic plan review.** When explicitly enabled by the user, trigger once
   after a meaningful implementation plan is coherent and executable, but
   before it is presented as ready or execution begins.

Automatic review does not trigger for open brainstorming, trivial two-step
work, status reporting, a plan already reviewed at the same content hash, the
processing of Grok's own response, a benchmark that forbids nested agents, an
explicit opt-out, or content that cannot safely be sent externally.

The public skill defaults to explicit consultation only. The user's personal
configuration may opt into automatic plan review after acceptance passes.

### Smallest package

```text
skills/toolboxmd-use-grok/
├── SKILL.md
└── scripts/
    └── consult-grok
```

Add another file only when a test or an actual Grok Build contract demonstrates
that it is needed.

`SKILL.md` owns semantic judgment: activation, brief selection, privacy, loop
prevention, and reconciliation of Grok's advice. The adapter owns deterministic
invocation: argument construction without shell evaluation, controlled working
directory, timeout, exit codes, structured output, session metadata, and raw
result retention.

The adapter must not inherit unrelated user MCP servers, plugins, hooks, or
skills merely because they are present in the normal Grok profile. Use an
isolated runtime profile or an equally explicit disable mechanism while keeping
authentication outside the repository. Fail with a readable preflight error if
the requested isolation cannot be established.

Use xAI's official Claude Code plugin as a reference implementation, not as a
runtime dependency. Its current review bridge demonstrates safe argument-vector
spawning, fresh session identifiers, a read-only sandbox, structured critique
output, raw-output retention, and explicit parse errors. It also demonstrates
limits that this skill must close: the bridge uses `--always-approve`, inherits
ambient Grok configuration and extensions, and has no wall-clock timeout for a
foreground review. The plugin README is not the command source of truth when it
differs from the implementation.

The installed Grok Build 1.0.3 preflight on 2026-08-13 found 26 skills and one
MCP server under the ordinary user profile. An empty `GROK_HOME` removed the
user config layer but still discovered project instructions, four compatibility
skills, and one MCP server. Therefore an empty profile alone is not evidence of
isolation. Automatic review must use a staged review directory with no project
instructions and must prove, through `grok inspect --json` or an equivalent
machine-readable preflight, that forbidden extensions are absent or unusable.
The acceptance suite must test whether denying `MCPTool(*)` blocks both direct
MCP tools and always-on MCP meta-tools. If it does not, automatic review remains
disabled until a stronger configuration boundary exists.

For the isolated process, set every supported Cursor and Claude compatibility
surface to false:

```text
GROK_CURSOR_SKILLS_ENABLED=false
GROK_CURSOR_RULES_ENABLED=false
GROK_CURSOR_AGENTS_ENABLED=false
GROK_CURSOR_MCPS_ENABLED=false
GROK_CURSOR_HOOKS_ENABLED=false
GROK_CURSOR_SESSIONS_ENABLED=false
GROK_CLAUDE_SKILLS_ENABLED=false
GROK_CLAUDE_RULES_ENABLED=false
GROK_CLAUDE_AGENTS_ENABLED=false
GROK_CLAUDE_MCPS_ENABLED=false
GROK_CLAUDE_HOOKS_ENABLED=false
GROK_CLAUDE_SESSIONS_ENABLED=false
```

Those switches do not disable native `.grok`, native `.agents`, or generic
project instruction files. The staged review directory and effective-config
preflight remain mandatory. A dedicated `GROK_HOME` also moves `auth.json`.
Authenticate that stable profile once with `grok login`, or pass an existing
`XAI_API_KEY` through the process environment. Do not copy credentials into
ephemeral directories or retain them in repository evidence.

### Automatic-review safety contract

- Review is read-only and uses a fresh session.
- Send a minimal brief, not the entire conversation or repository.
- Do not send secrets, credentials, `.env` files, unrelated memory, or
  unrelated worktree content.
- Disable Grok memory, subagents, and web search unless the user explicitly
  asks for research that requires it.
- Supply the brief through `--prompt-file`, use a fresh `--session-id`, cap
  agent turns with `--max-turns`, and enforce a separate wall-clock timeout that
  terminates the complete child process tree.
- Prefer JSON Schema output with `additionalProperties: false`; retain raw
  stdout and a parse error when structured parsing fails.
- Accept both the documented JSON envelope's `structured_output` value and a
  direct schema-shaped object. Freeze the observed Grok Build 1.0.3 behavior in
  the real acceptance evidence.
- Do not use `--always-approve` or `--yolo` for automatic review.
- Run at most one automatic consultation per normalized plan hash.
- Tell Grok not to invoke Codex, Claude, Grok, or another agentic CLI.
- Treat Grok's response as a proposal. Report what was accepted, rejected, and
  changed, with reasons.
- If automatic review fails, report the skip and continue unless the user made
  Grok review mandatory. If an explicit Grok request fails, stop and report the
  concrete error.

Explicit mutation such as "have Grok implement this" is outside automatic v1.
It requires a later, explicit branch or worktree contract and must never be
smuggled through plan review.

### Review output contract

Ask Grok for a bounded structure:

```text
VERDICT: PROCEED | PROCEED WITH CHANGES | REPLAN | NEEDS HUMAN DECISION

OVERENGINEERING:
MISSING:
RISKS:
MINIMUM PLAN DELTA:
USER DECISIONS:
```

The calling agent returns a short reconciliation and the revised plan rather
than copying Grok's answer blindly.

### Acceptance

Use a fake `grok` executable first. Verify:

1. explicit Polish and English consultation prompts activate the skill;
2. a mature implementation plan triggers exactly one review when opt-in is on;
3. brainstorming, trivial work, Grok-response processing, repeated plan hashes,
   explicit opt-out, and prohibited benchmark contexts do not trigger;
4. the adapter passes the frozen arguments and prompt file without shell
   interpolation;
5. timeout, non-zero exit, invalid JSON, and missing CLI fail as documented;
6. the automatic path cannot mutate the project and does not expose protected
   fixture content;
7. unrelated MCP servers, plugins, hooks, skills, and user memory are not
   initialized or exposed;
8. a cancelled or incomplete Grok stop reason is not reported as a completed
   review;
9. output includes verdict, session identifier when available, usage, stop
   reason, and enough raw evidence to audit the call.
10. `--max-turns` and the wall-clock timeout are tested separately, and timeout
    kills every spawned Grok process rather than only the bridge parent;
11. preflight compares the effective configuration with the frozen allow-list,
    rather than assuming that an empty `GROK_HOME` is isolated.

After fake-CLI tests pass, run one synthetic real-CLI acceptance using the
installed Grok Build version. The brief must contain no secret or unrelated
repository data. Only after this pass may automatic plan review be enabled in
the user's personal instructions.

### Primary Grok sources

- [xAI Grok Build repository](https://github.com/xai-org/grok-build)
- [Headless mode guide](https://github.com/xai-org/grok-build/blob/main/crates/codegen/xai-grok-pager/docs/user-guide/14-headless-mode.md)
- [Sandbox guide](https://github.com/xai-org/grok-build/blob/main/crates/codegen/xai-grok-pager/docs/user-guide/18-sandbox.md)
- [Permissions and safety guide](https://github.com/xai-org/grok-build/blob/main/crates/codegen/xai-grok-pager/docs/user-guide/22-permissions-and-safety.md)
- [Official Claude Code plugin](https://github.com/xai-org/grok-build-plugin-cc)
- [Official bridge implementation](https://github.com/xai-org/grok-build-plugin-cc/blob/main/plugins/grok-build/scripts/grok-bridge.mjs)
- [Official Grok process wrapper](https://github.com/xai-org/grok-build-plugin-cc/blob/main/plugins/grok-build/scripts/lib/grok.mjs)

## Step 5: compare, decide, and promote only supported changes

First compare the current ToolboxMD creator with vNext on the frozen base Grok
skill brief, using the same authoring model, inputs, tools, and fake-CLI
downstream checks. Treat this as diagnostic dogfooding, not promotion evidence.

After vNext is frozen, freeze a compact paraphrase and fault-injection set that
was not available while authoring the revision. It should exercise implicit
activation, near misses, a malformed Grok response, an incomplete stop reason,
and isolation from unrelated runtime extensions. This is the only new evidence
from the Grok family that may contribute to promotion.

Compare separately:

- positive triggering and difficult near misses;
- downstream correctness and full-procedure adherence;
- script invocation safety and failure behavior;
- activated description, core, and always-read reference cost;
- package files and bytes;
- authoring duration and runtime tokens;
- unnecessary commands, Git inspection, and package artifacts.

If observable utility ties and cost alone separates the candidates, run one
paired repeat before declaring a cost winner. Do not open a reserve case merely
to manufacture a majority.

Only if vNext clears the known-case regression gate and the post-freeze held-out
set without a critical regression should it be compared with the built-in
creator. The known base Grok brief alone cannot clear this gate. A built-in
comparison is for a default recommendation, not a prerequisite for shipping a
useful Grok skill.

Possible outcomes:

- **vNext promoted:** it improves utility or preserves utility with a stable,
  meaningful reduction in activated or authoring cost.
- **vNext retained as candidate:** evidence is tied, mixed, or too noisy.
- **vNext rejected:** it introduces a critical regression.

Ship the best validated `toolboxmd-use-grok` product even if the creator
comparison remains mixed. Keep product quality and creator-ranking claims
separate.

## Branch and pull-request topology

1. `codex/benchmark-v2` -> `main`: immutable benchmark evidence and doctrine.
2. `codex/creating-skills-vnext` -> `codex/benchmark-v2` until its parent lands:
   this plan, creator vNext, and deterministic regression evidence.
3. `codex/toolboxmd-use-grok` -> `codex/creating-skills-vnext`: Grok skill,
   adapter, fake-CLI tests, and real acceptance evidence.

After a parent merges, rebase its child onto latest `main` and retarget the PR.
Use one writer per branch. Never let local Codex and Codex Cloud edit the same
branch concurrently.

## Completion contract

The program is complete only when:

- PR 1 has checks passing and no actionable current-HEAD review findings;
- creator vNext is frozen, validated, committed, pushed, and reviewed;
- known-case regression checks pass;
- `toolboxmd-use-grok` passes fake-CLI and one real read-only acceptance;
- personal automatic review is enabled only after that acceptance;
- the comparison verdict states its evidence and limitations;
- documentation, generated public artifacts, and project wiki are updated when
  their contracts require it;
- every branch, commit, push, PR, check, review status, and remaining issue is
  reported separately;
- no pull request is merged without explicit user approval.
