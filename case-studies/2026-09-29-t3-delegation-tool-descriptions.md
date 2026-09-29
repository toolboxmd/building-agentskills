# Case study: T3 delegation tool descriptions

- **Date:** 2026-09-29
- **Subject:** why a Claude Code agent in T3 Code started a review with `codex exec` in the shell instead of the `spawn_thread` tool, and what changed its choice
- **Record and fix:** [toolboxmd/chromeria#66](https://github.com/toolboxmd/chromeria/issues/66) (the failure and the fix spec), PR [toolboxmd/chromeria#67](https://github.com/toolboxmd/chromeria/pull/67), merged 2026-09-29 10:59 UTC as [`f8a22e9`](https://github.com/toolboxmd/chromeria/commit/f8a22e9e2678b28635b5890801431cb0a0d2aa06)
- **Evidence after the fix:** [toolboxmd/building-agentskills#4](https://github.com/toolboxmd/building-agentskills/issues/4): the [`alwaysLoad` re-check](https://github.com/toolboxmd/building-agentskills/issues/4#issuecomment-5899820668) and the [fresh-session check](https://github.com/toolboxmd/building-agentskills/issues/4#issuecomment-5899742984)

An MCP tool description does the same job as a Skill description: the model decides from it whether this is the moment to use the tool. T3 Code's delegation tools were deferred behind Claude Code's tool search, so the model saw their names and nothing else, and the one description it could have found led with mechanics and never named the shell command it was meant to replace. A planner asked for an independent review ran `codex exec` from Bash, where the user could not see it. The fix kept four delegation tools always loaded and rewrote their descriptions to lead with when to use them and to name the shell commands they replace. One fresh session afterwards chose `spawn_thread`. That is one run, and it cannot say which part of the fix mattered.

## Ship summary

T3 Code (the fork [toolboxmd/chromeria](https://github.com/toolboxmd/chromeria)) runs agent harnesses such as Claude Code, Codex, OpenCode and Grok inside threads, and exposes 33 `t3-code` MCP tools to them. Four of those tools delegate work: `spawn_thread` starts a child thread for one bounded task, `prism_submit` hands a whole job to the Prism router, and `read_thread` and `message_thread` follow up. A child thread appears in the parent thread's Agents panel; an agent CLI started in the shell does not.

[toolboxmd/chromeria#67](https://github.com/toolboxmd/chromeria/pull/67) changed three things:

1. **Always loaded.** The four delegation tools carry `_meta["anthropic/alwaysLoad"] = true` ([`alwaysLoad.ts`](https://github.com/toolboxmd/chromeria/blob/f8a22e9e2678b28635b5890801431cb0a0d2aa06/apps/server/src/mcp/alwaysLoad.ts)). The other 29 tools stay deferred.
2. **Trigger-first descriptions.** The `spawn_thread` and `prism_submit` descriptions were rewritten to state when to use the tool, then the shell alternative it replaces, then the minimum mechanics (541 and 470 characters at `f8a22e9`).
3. **Launch paragraph.** The `<t3_code_tool_use>` paragraph that T3 appends to every harness's launch prompt names the same shell commands. For Codex, OpenCode and Grok this paragraph is the only channel ([`toolInstructions.ts`](https://github.com/toolboxmd/chromeria/blob/f8a22e9e2678b28635b5890801431cb0a0d2aa06/apps/server/src/mcp/toolInstructions.ts)).

## The failure

Recorded in [toolboxmd/chromeria#66](https://github.com/toolboxmd/chromeria/issues/66) and [#4](https://github.com/toolboxmd/building-agentskills/issues/4), both 2026-09-29:

- **Harness.** Claude Code 2.1.284 inside T3 Code. All 33 `t3-code` tools were deferred behind tool search: names visible, descriptions and schemas not.
- **Routing text in context.** The launch prompt carried the routing paragraph from toolboxmd/chromeria#46 and #53: "Delegate with them, not with agents started in a terminal."
- **What happened.** The planner, asked for an independent Luna review of toolboxmd/agentsmd PR #163, ran `codex exec -m gpt-5.6-luna ...` from Bash. The user could not see the run in the Agents panel.

The causes come from the planner's own account after the fact, not from an experiment:

1. **A ready recipe in memory.** A memory note held a copyable `codex exec` command. A concrete command beat an abstract routing sentence.
2. **The trigger did not match.** The planner classified a review as "running a command", not as "delegating", so the paragraph's delegation trigger never matched.
3. **The description named no alternative.** Before the fix, `spawn_thread` began with what it does, and nothing in it names the shell route it exists to replace ([parent commit `26b5c3f`](https://github.com/toolboxmd/chromeria/blob/26b5c3fea14e9c3ea833e4ead877f8532584f64b/apps/server/src/mcp/toolkits/threads/tools.ts#L118-L120)):

   > Start a child thread in this project and send it a task: small direct work such as a quick review or a bounded fix. Pass role (for example reviewer or worker) to apply that Prism role's kit and preferred model, or name a provider instance, model and effort. [...]

   And because the tool was deferred, the model would only have read even this after choosing to search for it.

## The fix, in the descriptions

After [`f8a22e9`](https://github.com/toolboxmd/chromeria/blob/f8a22e9e2678b28635b5890801431cb0a0d2aa06/apps/server/src/mcp/toolkits/threads/tools.ts#L119-L121), `spawn_thread` opens with its trigger and names the rationalized alternative:

> Use when another agent should do one bounded task, such as a review, a second opinion, a check or a small fix, or when a specific model and effort is wanted. Use it instead of starting codex exec, claude -p, opencode run or grok in the shell: the user cannot see those runs, while a child thread shows in this thread's Agents panel. [...]

The review is named as a delegation case ("a review, a second opinion"), which answers cause 2, and the shell commands are named, which answers cause 3. The launch paragraph changed "not with agents started in a terminal" to "never by starting codex exec, claude -p, opencode run or grok in the shell: the user cannot see those runs."

The fix left out two options. A `PreToolUse` hook that blocks agent CLIs was rejected by the user as a first fix and kept as a last resort. A server-wide `alwaysLoad` was rejected because it would load all 33 tools on every turn and make startup wait for the server ([toolboxmd/chromeria#66](https://github.com/toolboxmd/chromeria/issues/66), Elon record).

## What `alwaysLoad` does

Claude Code defers MCP tools by default: "Only tool names and server instructions load at session start" ([MCP docs, tool search](https://code.claude.com/docs/en/mcp), read 2026-09-29). The same page documents two exemptions, under "Exempt a server from deferral":

- `alwaysLoad: true` in a server's configuration loads every tool of that server at session start, and makes startup wait for the server's tools, capped at the 5-second connect timeout.
- A server can mark one tool instead: "including `"anthropic/alwaysLoad": true` in the tool's `_meta` object, which has the same effect for that tool only."

The PR's own check reported "`0/19 deferred tools` with the mark and `0/20` without" from a Claude Code 2.1.284 debug log. Read as "zero deferred", that shows nothing. The [re-check on #4](https://github.com/toolboxmd/building-agentskills/issues/4#issuecomment-5899820668) ran a local stdio server with two tools, one marked, on Claude Code 2.1.284 with Opus 5.5, one run per arm:

| Arm | Debug line | Tools the model saw with full schema |
| --- | --- | --- |
| `probe_marked` has the mark | `Dynamic tool loading: 0/1 deferred tools included` | `probe_marked`; `probe_plain` by name only |
| no mark | `Dynamic tool loading: 0/2 deferred tools included` | none; both by name only |

The line counts deferred tools included in the request by a tool search (X) out of all deferred tools (Y). The original "0/19 and 0/20" therefore means 19 deferred tools with the marked tool exempt, against 20 without the mark. With the `ToolSearch` tool unavailable, the log says `Tool search disabled` and `0/0`, so such a test only means something while tool search is on.

A session in T3 on the evening of 2026-09-29 showed the four delegation tools loaded at start, with the new wording, and the rest deferred ([#4 ticket packet](https://github.com/toolboxmd/building-agentskills/issues/4), status). T3 connects over HTTP; the debug-log check used stdio.

## The fresh-session check

Recorded on [#4](https://github.com/toolboxmd/building-agentskills/issues/4#issuecomment-5899742984): a new T3 Claude Code thread (Opus 5.5, effort medium) got the prompt "Please get a second opinion from a different model on whether the README at ~/dev/toolboxmd/model-router/README.md explains installation clearly, and tell me what it says. Don't edit any files." It called `spawn_thread` with role `reviewer`, which started a Codex `gpt-6-luna` child thread, instead of a shell CLI. T3's thread list shows that child with the session as its parent.

## What the evidence does not prove

- **One run.** n=1. A single success does not give a rate, and the routing benchmarks show single samples can mislead (see [Trigger benchmarks](/docs/06-testing/trigger-benchmarks)).
- **Not a user-typed session.** A planner thread started the session with `spawn_thread`, not the user in a new window.
- **Not the failing prompt.** The check asked for a second opinion on a README, not an independent review of a PR diff, and the session did not carry the failing planner's context.
- **No attribution.** There was no run of the same prompt before the fix, and the fix changed loading, description wording and the launch paragraph at once. The result does not say which change mattered, or whether the session would have chosen `spawn_thread` anyway.
- **The memory cause is untested.** No run placed a `codex exec` recipe in memory and checked whether the new descriptions outrank it.
- **One host.** Codex, OpenCode and Grok receive only the launch paragraph and were not checked.
- **Transport.** The `_meta` debug-log check ran over stdio; for T3's HTTP connection there is only the observed tool list above.

## What worked

- **Writing the tool description as a trigger.** The chromeria#67 descriptions follow the rule for Skill descriptions: state when to use it, not the internal workflow. See [Triggers](/docs/05-authoring/triggers), "Tool descriptions are activation contracts too".
- **Keeping only the decision-point tools loaded.** Four tools out of 33 carry the mark, so the context cost stays small and startup does not wait on the whole server.
- **Prose before mechanism.** The hook stayed a last resort. This follows the order in [Mechanism vs decoration](/docs/07-mechanism-vs-decoration), "Measure, reword, mechanism last", which holds the AgentsMD evidence for when rewording was and was not enough.

## What failed

- **A routing sentence with no reachable description.** The launch paragraph was in context and did not fire; the description that could have backed it was hidden until a search the model had no reason to make.
- **A memory note with a command.** A stored recipe gave the model a finished answer before any routing text could apply. See [Anti-patterns](/docs/10-anti-patterns), "Shell recipe in memory outranking the host's routing".

## What this case study changes in this repo

- [Triggers](/docs/05-authoring/triggers) gains "Tool descriptions are activation contracts too".
- [Anti-patterns](/docs/10-anti-patterns) gains two entries: a shell recipe in memory that outranks the host's routing, and a decision-point tool deferred behind tool search.
- The loader Skill routes "Before writing or changing an MCP tool description" to Triggers.

## Sources

- toolboxmd/chromeria [#66](https://github.com/toolboxmd/chromeria/issues/66) and PR [#67](https://github.com/toolboxmd/chromeria/pull/67); files at merge [`f8a22e9`](https://github.com/toolboxmd/chromeria/tree/f8a22e9e2678b28635b5890801431cb0a0d2aa06/apps/server/src/mcp) and at its parent [`26b5c3f`](https://github.com/toolboxmd/chromeria/tree/26b5c3fea14e9c3ea833e4ead877f8532584f64b/apps/server/src/mcp).
- toolboxmd/building-agentskills [#4](https://github.com/toolboxmd/building-agentskills/issues/4): the failure record, the [`alwaysLoad` re-check](https://github.com/toolboxmd/building-agentskills/issues/4#issuecomment-5899820668) and the [fresh-session check](https://github.com/toolboxmd/building-agentskills/issues/4#issuecomment-5899742984).
- Claude Code [MCP docs](https://code.claude.com/docs/en/mcp), "Scale with MCP tool search" and "Exempt a server from deferral", read 2026-09-29.

Cross-links: [Triggers](/docs/05-authoring/triggers), [Anti-patterns](/docs/10-anti-patterns), [Mechanism vs decoration](/docs/07-mechanism-vs-decoration), [AgentsMD routing benchmarks](/case-studies/2026-09-29-agentsmd-routing-benchmarks).
