# `toolboxmd-use-grok` base brief

## Reusable job and value

Let an agent ask the locally installed Grok Build CLI for a bounded second
opinion, then reconcile that advice instead of copying it blindly. The public
skill defaults to consultation only when the user explicitly asks for Grok.
An optional personal policy may request one review of a mature implementation
plan, but only after automatic isolation and real acceptance are proven.

## Invocation contract

The agent should use the skill for explicit Polish or English requests to ask,
send, pass, delegate for review, or obtain an opinion from Grok or Grok Build.

Automatic plan review is outside the public default. When a user separately
opts in, it may run once after a meaningful implementation plan is coherent
and executable, before the plan is presented as ready or execution begins.

Do not trigger automatic review for open brainstorming, trivial two-step work,
status reporting, an unchanged plan already reviewed at the same normalized
content hash, processing Grok's own response, a benchmark that forbids nested
agents, explicit opt-out, or content that cannot safely be sent externally.

## Inputs and outputs

Input is a minimal prompt file containing only the question or mature plan and
the context needed to review it. Output is a structured review with one verdict
from `PROCEED`, `PROCEED WITH CHANGES`, `REPLAN`, or `NEEDS HUMAN DECISION`, plus
overengineering, missing items, risks, the minimum plan delta, and user
decisions. The calling agent reports accepted, rejected, and changed advice
with reasons.

## Product boundary

The target package contains only:

```text
skills/toolboxmd-use-grok/
├── SKILL.md
└── scripts/
    └── consult-grok
```

`SKILL.md` owns semantic activation, brief selection, privacy, loop prevention,
and reconciliation. The adapter owns deterministic preflight, safe argv,
staging, timeout, exit classification, structured parsing, and evidence.

## Deterministic adapter contract

- Accept the brief through `--prompt-file`; never interpolate it into a shell.
- Use a fresh UUID and a staged working directory with no project instructions.
- Use a read-only sandbox, no memory, no subagents, no web by default, bounded
  max turns, and a separate wall-clock timeout that terminates the process tree.
- Do not use `--always-approve` or `--yolo` for automatic review.
- Disable every supported Cursor and Claude compatibility surface.
- Prevent unrelated native skills, agents, hooks, plugins, MCP servers, user
  memory, and project instructions from becoming usable in the review.
- Preflight effective configuration against a frozen allow-list. An empty
  `GROK_HOME` alone does not prove isolation.
- Deny all MCP tool calls, including direct and meta-tool paths.
- Use JSON Schema with `additionalProperties: false` and accept either a direct
  schema object or the documented envelope's `structured_output` object.
- Retain redacted raw stdout, stderr, invocation metadata, session identifier,
  usage, stop reason, and enough evidence to audit accepted or rejected advice.
- Distinguish missing CLI, isolation failure, nonzero exit, timeout, invalid
  JSON, incomplete stop reason, and max-turn exhaustion.
- Never expose credentials, `.env` content, unrelated memory, or unrelated
  worktree content. Tell Grok not to invoke any agentic CLI.
- A stable dedicated `GROK_HOME` is required for automatic mode. Authentication
  may come from that profile or an existing `XAI_API_KEY`; credentials are not
  copied into staging or evidence.

## Failure behavior

An explicit user-requested consultation failure stops and reports the concrete
error. An optional automatic review failure is reported as skipped and the main
work may continue unless the user made review mandatory. If isolation cannot be
proven, automatic mode fails closed and remains disabled.

## Evidence and acceptance

Start with a fake `grok` executable. Cover frozen argv and environment, prompt
file handling, both structured-output shapes, separate max-turn and timeout
behavior, complete child-tree termination, nonzero and malformed output,
incomplete stop reasons, missing CLI, shell-injection resistance, protected
content exclusion, and inspect allow-list behavior. The fake must not invoke
the real CLI.

After fake tests pass, attempt one synthetic real read-only consultation with
no repository, private, or secret content and with web disabled. If strict
automatic isolation cannot be established, do not run an automatic acceptance;
a bounded explicit synthetic consultation may still record the blocker.

## Three answers and budgets

1. The agent invokes the public skill only in response to an explicit user Grok
   request. A separate personal policy may add automatic mature-plan review.
2. The adapter enforces process, isolation, timeout, structured-output, and
   evidence invariants. `SKILL.md` provides semantic privacy and reconciliation
   judgment, which the calling agent must report.
3. Keep `SKILL.md` at or below 150 lines and 10,500 bytes, the description at or
   below 400 characters, the product at exactly two files and at or below
   45,000 bytes, with zero references, evals, README files, or sidecars.

