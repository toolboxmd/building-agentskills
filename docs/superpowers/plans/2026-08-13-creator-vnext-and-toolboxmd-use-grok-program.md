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

Completion evidence, updated 2026-08-14:

- product: `skills/toolboxmd-creating-skills/`;
- exact package: three files, 45,976 bytes, aggregate SHA-256
  `2515fc3495597e4b8442ebaab997414df115dbf70af864b5db457d617b135eed`;
- activated core: 74 lines and 3,973 bytes, with a 226-character
  description, zero references, zero evals, and one read-only validator;
- freeze and claim boundary:
  `benchmarks/toolboxmd-creating-skills/vnext/manifest.json`;
- the delta answers diagnostic failure patterns only. It supports no creator
  superiority or promotion claim.
- exact-HEAD review first added 2,256 executable-only bytes for quote-aware
  YAML comment correctness and the reviewed Hermes metadata surface;
- a later exact-HEAD review added 460 executable-only bytes within that cap for
  optional `default_prompt`, all-decodable-file local-path scanning, and
  single-line CommonMark reference-definition destinations;
- a bounded adversarial audit added 7,353 executable-only bytes and narrowed
  the claim to a canonical ToolboxMD package-policy checker with optional
  already-installed `skills-ref` cross-checking. The cumulative executable
  delta from the pre-revision freeze was 10,069 bytes and the package cap is
  36,000 bytes. Activated-core, description, file, reference, eval, and script
  budgets are unchanged;
- a later two-finding exact-HEAD pass added 27 executable-only bytes for YAML
  special-float classification and dot-relative fragile script commands. The
  cumulative executable delta became 10,096 bytes;
- a subsequent two-finding pass added 353 executable-only bytes for exact
  Hermes sequence-item state and separator-bounded same-line command
  detection. The cumulative executable delta became 10,449 bytes;
- the quote-only canonical correction removed 312 executable bytes by
  replacing partial implicit-YAML classification with one JSON-double-quoted
  generated string form, mapping-only portable metadata, and parity-aware shell
  continuation normalization. The current cumulative executable delta is
  10,137 bytes;
- a follow-up exact-HEAD correction added 273 executable bytes to require
  JSON-double-quoted user-defined portable metadata keys. The current
  cumulative executable delta is 10,410 bytes after consolidating duplicate
  diagnostic paths without dropping contract fixtures;
- empty and comment-only metadata hardening added 142 executable bytes. The
  cumulative executable delta is 10,552 bytes, and omission remains valid;
- strict delivery-command and direct task-relative helper hardening added 116
  executable bytes. The cumulative executable delta is 10,668 bytes;
- optional Codex sidecar subsets and a bounded lexical command scanner added
  2,766 executable bytes. The cumulative delta is 13,434 bytes. The package
  cap became 40,000 bytes at that stage, restoring the readable accepted
  workflow while the
  executable-only scanner preserves quote, escape, operator, redirection,
  comment, command-position, and assignment provenance. Activated-core,
  description, file, reference, eval, and script budgets remain unchanged,
  and no lower total package-size claim is allowed;
- grouping-operator hardening added 226 executable bytes for unquoted shell
  parentheses and canonical Markdown-link masking, bringing the cumulative
  executable delta to 13,660 bytes;
- exact-digest operator attestation and grouping-brace hardening added 2,673
  executable bytes. The cumulative executable delta is 16,333 bytes and the
  package cap is 44,000 bytes. Non-Python helpers can pass strict validation
  only when the operator separately checks them, reports that command, and
  binds the current bytes through a repeated `--script-syntax-checked`
  argument. ToolboxMD verifies the binding, not command execution. Activated
  core and all non-package-byte budgets remain unchanged;
- bounded same-line shell clause state added 959 executable bytes for the fixed
  unquoted `if`, `while`, `until`, `then`, `do`, `elif`, `else`, and `!` set.
  The cumulative executable delta is 17,292 bytes; quoted, escaped, prose,
  argument, `fi`, and `done` tokens do not reset command position without a
  real separator. Multiline and nested shell parsing remain outside scope;
- built-in host-validator compatibility added 132 executable bytes to reject
  `<` or `>` in descriptions even when `skills-ref` is unavailable. The
  cumulative executable delta was 17,424 bytes;
- an exact-HEAD `env` bypass and Grok architecture audit then retired the
  arbitrary shell lexer. Root, blockquote, and list fence handling plus
  explicit context diagnostics added 1,189 executable bytes overall, so the
  cumulative executable delta at that stage was 18,613 bytes without changing the 44,000-byte
  cap. Closed case-insensitive `sh`, `bash`, and `shell` fences reject
  immediate non-whitespace task-relative helper children without interpreting shell syntax. Single-line inline,
  indented, and other fenced code produce a context error; all UTF-8 files below
  `scripts/` plus executable or shebang files are scanned; ordinary prose, link
  destinations, directory-only mentions, and generic configs without a schema
  remain outside the rule. Leading-whitespace child names and multiline inline
  spans are outside the custom lexical subset;
- exact-HEAD review then reused the same root, blockquote, and list fence state
  for Markdown link masking. It added 345 executable bytes. The real-interpreter
  shim test is test-only;
- the next exact-HEAD correction JSON-quoted `name` like every other generated
  string and rejects executable or shebang helpers outside `scripts/`. Reusing
  package collection and deleting obsolete scalar special cases reduced the
  executable by 197 bytes, bringing the cumulative delta at that stage to
  18,761 bytes;
- a bounded exact-HEAD correction then preserved blank lines inside
  list-contained fences in the shared script-path and link-masking state. It
  added 128 executable bytes, bringing the cumulative delta to 18,889
  bytes, without waiving blockquote markers or nonblank container exits;
- the current exact-HEAD correction adds 119 executable bytes for
  case-insensitive Windows drive-user paths and explicit creation-mode sidecar
  UI requirements, bringing the cumulative delta to 19,008 bytes. General
  validation still accepts supported partial existing sidecars;
- independent exact-current audit added 277 executable bytes to hide remote
  and anchor-link query or fragment text from workstation-path scanning while
  preserving file and drive-root local links, and to reject whitespace-only
  present interface strings. The cumulative delta is 19,285 bytes;
- the next exact-HEAD correction adds 26 executable bytes for one-or-more
  parent-relative helper prefixes at the existing token boundary and empty or
  case-insensitive localhost file URI authorities. Embedded parent segments and
  remote file authorities remain outside those checks. The cumulative
  executable delta is 19,311 bytes;
- the following exact-HEAD correction rejects YAML-invalid lone and paired
  JSON surrogate escapes through the shared canonical scalar decoder while
  literal Unicode and escaped backslash text remain valid. Reuse plus removal
  of redundant runtime annotation and module declarations reduces executable
  bytes by 25, bringing the cumulative delta to 19,286 bytes;
- the next exact-HEAD correction recognizes any combination of canonical `./`
  and `../` segments at the existing task-relative token boundary and keeps
  invalid UTF-8 Python helpers as package-validation failures instead of later
  AST inspection errors. Reuse plus removal of a redundant subprocess default
  adds 17 executable bytes, bringing the cumulative delta to 19,303 bytes;
- the following exact-HEAD correction scopes case-insensitivity to the `file`
  scheme and optional localhost authority while retaining case-sensitive POSIX
  roots and remote-authority nonmatches. It adds 4 executable bytes, bringing
  the cumulative delta to 19,307 bytes;
- the current exact-HEAD correction keeps invalid UTF-8 OpenAI sidecars as one
  package issue and reports `skipped_extension` without discovering or invoking
  portable `skills-ref` in explicit Hermes extension mode. It adds 187
  executable bytes, bringing the cumulative delta to 19,494 bytes. A bounded
  active-core deletion pass removed 127 bytes without changing the workflow;
  the package cap is now 45,000 bytes while activated-core, description, file,
  reference, eval, and script budgets remain unchanged. No lower package-cost,
  superiority, or promotion claim is allowed;
- the next exact-HEAD correction adds 789 executable bytes and brings the
  cumulative delta to 20,283 bytes. A raised package budget cannot loosen the
  portable 1,024-character description ceiling, while a lower budget remains
  effective. Percent-decoding applies only to lexically bounded
  empty-authority or localhost file URI paths before case-sensitive POSIX-root
  checks; embedded text, remote authorities, and remote or anchor destinations
  remain nonlocal. The 45,000-byte cap and all non-package-byte budgets are
  unchanged;
- the following exact-HEAD correction adds 57 executable bytes and brings the
  cumulative delta to 20,340 bytes. Task-relative helper detection accepts
  slash or backslash separators while retaining explicit-root and embedded-path
  exclusions, decoded local file URI paths classify mixed-separator Windows
  drive-user roots, and zero-to-three-space reference-definition indentation no
  longer contaminates labels. The 45,000-byte cap and all activated-core
  budgets are unchanged;
- the next exact-HEAD correction adds 167 executable bytes and brings the
  cumulative delta to 20,507 bytes. Local single-slash `file:/...` roots share
  the decoded local-file check, MCP dependency values require non-whitespace
  text, and the closed lexical helper rule rejects bare, leading-dot, or
  embedded static task-relative segment prefixes. Literal `<skill-dir>` and
  standalone leading home roots, URI and remote tokens, and ordinary Markdown
  link destinations, including those in helper-source Markdown, remain safe. A readable deletion
  pass removed 87 activated-core bytes without changing the workflow. The
  executable avoids runtime-evaluated PEP 604 optional annotations so system
  Python 3.9 reaches the CLI. The 45,000-byte cap and all activated-core budgets
  are unchanged;
- the latest exact-HEAD correction adds 595 executable bytes and brings the
  cumulative delta to 21,102 bytes. Malformed HTTP and file URI destinations
  now produce one stable `URI_SYNTAX` package issue instead of an uncaught
  `urlsplit` traceback across Markdown masking, destination validation, and
  local-file classification. A readable deletion pass removed 109
  activated-core bytes without changing its workflow. The package cap is now
  46,000 bytes; description, activated-core, file, reference, eval, and script
  budgets remain unchanged, with no lower-cost, superiority, or promotion
  claim;
- the following exact-HEAD correction adds 524 executable bytes and brings the
  cumulative delta to 21,626 bytes. Lexically normalized relative link targets
  compare exact stored component spelling independent of host filesystem
  casing, without symlink expansion. Hermes config keys decode before entry
  validity and empty or whitespace-only text fails once. A bounded deletion
  pass removed 34 activated-core bytes without changing the workflow. The
  46,000-byte cap and all non-package-byte budgets remain unchanged;
- the next exact-HEAD correction adds 98 executable bytes and brings the
  cumulative delta to 21,724 bytes. Declared sidecar icon paths compare exact
  file and directory component spelling while retaining existing assets-root,
  missing, escape, and symlink outcomes. Independent audit keeps icon symlink
  loops as structured package-level failures without resolving them. Static
  task-relative helper detection includes `foo~`, `~foo`, and `foo~bar`
  ordinary segments across slash,
  backslash, mixed, and dot forms; only a standalone leading `~/` or `~\` home
  segment remains excluded. A bounded deletion pass removed 169 activated-core
  bytes without changing the workflow. The 46,000-byte cap and all other
  budgets remain unchanged;
- the next exact-HEAD correction adds 162 executable bytes and brings the
  cumulative delta to 21,886 bytes. The target `scripts` component matches
  case-insensitively after one lexical token boundary across slash, backslash,
  nested, and dot forms, but `scripts` text inside an ordinary component such
  as `foo+scripts` remains outside the helper rule, including around quoted
  portable punctuation and after an unquoted comma within the same path
  component. A bounded wording pass removed 67 activated-core bytes without
  changing the workflow. The 46,000-byte cap and all budgets remain unchanged;
- the next exact-HEAD correction adds 35 executable bytes and brings the
  cumulative delta to 21,921 bytes. Direct Windows drive-user paths accept
  slash or backslash independently around `Users`, the exact `127.0.0.1` file
  URI authority is local, and single-line CommonMark reference labels collapse
  internal whitespace before case-insensitive matching. POSIX roots remain
  case-sensitive and other file authorities remain remote. The 46,000-byte cap
  and all budgets remain unchanged;
- canonical subset v2 uses one-line JSON double quotes for every top-level
  string, including `name`, and every user-defined portable metadata key and
  value.
  The `metadata.hermes.config` vendor extension requires
  `--allow-hermes-metadata` and double-quoted key-led entries for an explicitly
  Hermes-targeted package; this mode reports `skipped_extension` and does not
  run the portable `skills-ref` cross-check;
- vNext retains a smaller activated core and fewer distributed files/artifacts
  than retained v1, but claims no lower total package bytes, eligible creator
  advantage, superiority, or promotion readiness;

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

Completion evidence, updated 2026-08-14:

- `tests/toolboxmd-creating-skills-vnext.test.sh` passes from an external
  working directory;
- the test reproduces the package freeze and budgets, checks exit codes 0/1/2,
  rejects immediate non-whitespace task-relative helper children in root, blockquote, and list
  closed case-insensitive `sh`, `bash`, and `shell` fences without parsing
  commands, strings, comments, heredocs, wrappers, assignments, continuations,
  or control flow; rejects the same shape in single-line inline, indented, and non-shell
  fenced code with a context error; requires recognized shell fences to close;
  scans all UTF-8 files below `scripts/`, rejects executable or shebang helpers
  outside it, and keeps ordinary prose,
  Markdown link destinations, directory-only mentions, leading-whitespace child
  names, explicit skill roots,
  and generic configs without a schema outside the rule. The prescribed
  command makes warnings fatal,
  validates the real copyable minimal-skill example under explicit budgets,
  accepts the explicit `<skill-dir>` contract,
  accepts independently optional Codex interface, policy, and dependency
  sections in general mode, including supported partial interfaces, while
  present interface strings and MCP dependency values require non-whitespace
  text, creation mode requires both UI fields in a present optional sidecar, and
  both modes reject empty sections and empty sidecars; invalid UTF-8 sidecars
  remain one package issue with validation exit 1; accepts
  titled local links; rejects
  reserved provider names, single-quoted values, and every unquoted top-level
  string including names, prose, dates, hexadecimal, octal, and YAML typed scalars,
  enforces the portable 1,024-character description ceiling even when a caller
  raises the package budget while allowing a stricter budget,
  prevents trailing comments from hiding quoting errors, rejects block scalars,
  accepts the exact Hermes config extension only in explicit extension mode
  with double-quoted key-led sequence items and required descriptions, and
  rejects sequence markers and unquoted user-defined keys in portable metadata,
  rejects bare and comment-only metadata while accepting omission,
  ignores link syntax inside Markdown code, validates canonical single-line
  reference destinations, warns when complex Markdown requires official
  coverage, detects POSIX, container, case-insensitive Windows drive-user,
  percent-decodes lexically bounded local single-slash or empty/localhost file
  URI paths, and detects shebang-local paths while ignoring embedded file text,
  remote authorities, and remote or anchor-link query or fragment text during
  workstation-path scanning;
  recognizes slash and backslash task-relative helper separators across bare,
  leading-dot, embedded, mixed, and nested static segment prefixes while
  keeping literal skill and standalone leading home roots, URI tokens, remote
  contexts, and ordinary Markdown link destinations safe, including in helper
  sources,
  classifies decoded Windows drive-user paths in empty or localhost file URIs,
  and extracts canonical reference labels independently of their permitted
  zero-to-three-space indentation while masking four-space indented code;
  requires an exact-current-byte operator
  attestation before a separately checked non-Python helper can pass strict
  mode, and reports that ToolboxMD did not execute the language-specific
  command; exercises optional portable `skills-ref`
  pass/fail/error/timeout states, proves explicit Hermes extension mode reports
  `skipped_extension` without invoking it,
  records that the external validator's filesystem and network behavior is
  not attested by ToolboxMD,
  detects the retained meeting and deck baggage patterns,
  disables Python bytecode writes, and proves retained creator inputs were not
  mutated;
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
