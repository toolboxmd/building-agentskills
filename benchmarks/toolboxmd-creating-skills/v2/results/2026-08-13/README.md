# ToolboxMD creating-skills benchmark v2 result

## Decision

The result is **mixed, 1 to 1**. Neither creator is generally better on this evidence, and the frozen `toolboxmd-creating-skills` candidate is not promoted.

The current built-in creator remains the default because the challenger did not clear the frozen two-win promotion rule. This is a release decision, not proof that the built-in creator is universally superior.

| Case | No-skill qualification | Built-in | ToolboxMD | Operational outcome |
|---|---:|---:|---:|---|
| `meeting-followups` | 2/8 critical checks | 7/8, loaded, 18,550 runtime tokens | 7/8, loaded, 21,609 runtime tokens | Built-in cost tie-break, low confidence |
| `weekly-status-deck` | 7/8 critical checks | 8/8, loaded, 30,228 runtime tokens | 8/8, loaded, 23,982 runtime tokens | ToolboxMD cost tie-break, low confidence |

Both near-miss sessions were clean. None of the four installed target skills loaded for general advice prompts.

The reserve case did not run. After four authoring attempts were discarded for the Python bytecode boundary failure, only one session remained below the 17-session hard limit. The reserve required five sessions. Running it would have violated the precommitted budget.

## What is actually better

### Downstream quality

There is no observed quality winner. The meeting outputs are byte-identical across treatments. Both deck outputs pass all eight assertions and differ only in harmless template whitespace and title-slide phrasing.

The one failed meeting assertion is shared. Both treatments preserved terminal periods from the source action text, while the exact CSV fixture expected those periods to disappear. The source contract never required punctuation removal. The raw 7/8 grades remain unchanged, but this check is non-diagnostic and must not be presented as a creator regression.

### Trigger descriptions

ToolboxMD produced substantially shorter descriptions while matching the built-in creator's observed activation behavior:

| Case | Built-in description | ToolboxMD description | ToolboxMD delta | Positive load | Near-miss load |
|---|---:|---:|---:|---|---|
| Meeting | 533 characters | 376 characters | -29.5% | Both loaded | Neither loaded |
| Deck | 554 characters | 337 characters | -39.2% | Both loaded | Neither loaded |

This is a real ToolboxMD strength for the always-listed context layer. One positive and one related near miss per skill are still too small to prove a general description-optimization advantage.

### Package size and authoring behavior

The built-in creator produced smaller packages and shorter activated cores:

| Case | Built-in package | ToolboxMD package | Built-in `SKILL.md` | ToolboxMD `SKILL.md` |
|---|---:|---:|---:|---:|
| Meeting | 4 files, 15,161 bytes | 4 files, 19,664 bytes | 30 lines, 2,141 bytes | 40 lines, 2,390 bytes |
| Deck | 5 files, 12,689 bytes | 7 files, 19,530 bytes | 33 lines, 2,714 bytes | 44 lines, 3,097 bytes |

ToolboxMD used the extra space mostly for eval artifacts, focused script tests, and more explicit input and boundary prose. The built-in creator used optional `agents/openai.yaml` sidecars instead. The sidecars did not affect implicit triggering in this benchmark.

ToolboxMD authoring was slower in both cases: 345 versus 309 seconds for meeting, and 372 versus 236 seconds for deck. Its authoring token cost was lower for meeting but higher for deck, so no consistent authoring-token advantage exists.

### Repeated-use cost

The repeated-use result also splits:

- Meeting: ToolboxMD used 16.5% more uncached input plus output tokens and six more commands. Both outputs were identical.
- Deck: ToolboxMD used 20.7% fewer uncached input plus output tokens, despite one additional command. Both outputs passed fully.

Because each treatment ran once per case, these cost wins have low confidence. They are frozen operational tie-breaks, not variance-backed performance claims.

## Product conclusion

`toolboxmd-creating-skills` is viable, but not yet a better default than the built-in creator. Its strongest demonstrated property is compact, precise activation metadata. Its main weakness is that it converts proportional testing and delivery discipline into larger packages and longer authoring runs even when downstream quality does not improve.

The next candidate should preserve the description pattern and validation discipline while removing default package bloat, undefined working-directory assumptions, and unconditional Git delivery checks. The evidence-to-change map is in [recommendations.md](recommendations.md).

## Benchmark integrity

- Codex CLI: `0.147.0`
- Model: `gpt-5.6-sol`
- Reasoning effort: `medium`
- Same model, prompt, source files, sandbox, and runner configuration across treatments
- Positive prompts did not name a skill or `SKILL.md`
- Four of four positive runs loaded the full target `SKILL.md` before output creation
- Zero false-positive loads in two aggregate near-miss sessions
- Network probe blocked with curl exit code 6
- Plugins, apps, memories, bundled skills, web search, and nested delegation disabled
- Sixteen decision sessions, including four discarded authoring attempts
- 728,273 uncached-input-plus-output runtime tokens across decision sessions
- 2,759 cumulative session seconds

The first authoring batch was discarded before downstream use because both built-in runs created Python bytecode under the protected creator tree. The corrected runner disabled bytecode writes and repeated all four authoring arms symmetrically. The exact failed-attempt hashes are retained in `discarded-authoring/failure.json`.

Two eligible ToolboxMD authoring traces also recorded a `git status` warning: the command listed names from the ancestor worktree, but did not read file contents, another treatment, or grader data. This did not determine either case result. It is retained as a product and harness limitation.

The protocol commitment did not include the supporting grader and event-audit scripts. Those tools were implemented and tested before the scored downstream runs, and `manifest.json` records their at-result hashes. The evidence does not independently prove that every supporting script stayed byte-identical across the whole execution. Future runs must include every scoring and eligibility tool in the pre-run commitment.

The tracked result retains every JSONL stream, stderr file, and run-metadata record alongside generated packages, downstream outputs, deterministic grades, event audits, boundary audits, package inspections, no-skill outputs, and preflight evidence. `session-usage.json` independently records a SHA-256 hash and byte count for every decision-session stream.

## Claim boundary

This is a one-run operational comparison on Codex CLI 0.147.0 with `gpt-5.6-sol` at medium reasoning for two daily-use case families. It does not estimate variance, establish cross-provider behavior, or rank all skill creators. The valid conclusion is narrow: no general winner was established, ToolboxMD should not be promoted from this candidate, and the observed evidence supports the changes in `recommendations.md`.
