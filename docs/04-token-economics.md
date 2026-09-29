# Token economics: the why of skill constraints

This is Question 3 of the hero framework ([Three questions](/docs/03-three-questions)). What is the token budget for your skill, and what governs it?

The 500-line cap is not a stylistic preference. It is the auto-compaction survival floor. The description is not free: a skill the model may invoke has its description listed in every session on every host (with [exceptions](/docs/11-cross-platform/others)), and each host caps the listing differently. SessionStart-hook injection is not free either; it costs its full text every session, so a 105-token pointer and a full SKILL.md are different decisions. Authors who do not know these numbers ship 1,200-line skills and wonder why the agent stops following the rules after a long session.

This page gives you the numbers, the calculator, and the design choices the numbers force.

## The four budgets

### 1. The auto-compaction budget (25,000 tokens shared, 5,000-token per-skill survival floor)

Source: [Claude Code Skills docs](https://code.claude.com/docs/en/skills), re-read 2026-09-29; first recorded in `REVIEWER` G2.

Claude Code carries invoked skills forward across auto-compaction: it re-attaches the most recent invocation of each skill after the summary, keeping the first 5,000 tokens of each, within a 25,000-token shared budget filled from the most recently invoked skill. Older skills can be dropped after compaction.

- A 500-line SKILL.md is approximately 5,000 tokens (the rule of thumb is ~10 tokens per line for prose; tighter prose runs lower, code-heavy prose runs higher).
- A 500-line skill survives compaction. A 1,000-line skill is truncated to its first half after compaction. The truncated half is the part the agent will not see.
- "Most-recently-invoked first" means the skill you invoked at minute 5 of a 4-hour session may be dropped after compaction; the skill invoked at minute 230 stays.

**Implication.** Keep your SKILL.md under 500 lines (5,000 tokens). If you are over, push detail to `references/<topic>.md`. The body of SKILL.md should be the smallest set of words that the agent needs to act correctly; reference detail goes in sibling files loaded on demand.

### 2. The description listing budget

The agent-skills spec caps the `description` field at 1,024 characters ([agentskills.io/specification](https://agentskills.io/specification)). Each host then lists descriptions under its own limits. Checked 2026-09-29 against the sources the host pages cite:

| Host | Per-entry limit | Whole-listing limit | Source |
|---|---|---|---|
| Claude Code | 1,536 characters of `description` plus `when_to_use` | 1% of the context window; descriptions of the least-invoked skills drop first | [Claude Code](/docs/11-cross-platform/claude-code) |
| Codex | 1,024 characters per description | 2% of the context window, or 8,000 characters when the window is unknown; descriptions shorten first, then skills drop | [Codex](/docs/11-cross-platform/codex) |
| Grok Build | 400 bytes of `description` plus `when-to-use` | 50% of the context window | [Grok Build](/docs/11-cross-platform/others) |
| OpenCode | none found | every available skill is listed in the `skill` tool description | [OpenCode](/docs/11-cross-platform/others) |

**Implication.** Put the trigger first: every cap cuts from the end, and Grok Build keeps only 400 bytes. With many skills installed, the whole-listing limit can drop a description entirely, which removes the words the agent matches on. A listed description is still not a guarantee that the skill loads at the right moment (see section 4).

### 3. The per-skill `model:` and `effort:` overrides

Source: `REVIEWER` G7. Claude Code documents both fields:

- `model:` per-skill model override. Example: a skill that needs Opus reasoning can declare `model: opus` in its frontmatter (an alias, so the example does not pin a dated model ID). The harness applies the override for the rest of the turn the skill is active.
- `effort:` per-skill reasoning level. Example: `effort: high` for a deep-thinking skill.
- Default: `inherit` (use the parent's model and effort).

**Implication.** A skill that is under-budget but needs reasoning power can demand it without forcing the user to choose. A `wiki doctor`-style skill (deep lint pass) that needs Opus does not need the user to manually switch; the skill declares it and the harness complies.

These fields are Claude Code only. Other harnesses do not honor them. See `docs/11-cross-platform/`.

### 4. Session-start injection: full body or pointer

A SessionStart hook's output is paid in every session it fires in, whether or not the skill is used. What it injects is the choice.

- **Full body.** The `using-superpowers` hook reads the SKILL.md, escapes it for JSON and emits it as `hookSpecificOutput.additionalContext`. [obra/superpowers#1220](https://github.com/obra/superpowers/issues/1220) measured 1,370 tokens per firing and about 17,800 tokens over 57 hours and 13 firings in two sessions; its matcher includes `compact`, so it re-fires after every compaction.
- **Pointer.** A short note that names the skill and the actions it governs, and tells the agent to load it and read the procedure its routing table links. The AgentsMD pointer was 417 characters (about 105 tokens), later widened to 482 characters to cover every new kind of action ([routing case study](/case-studies/2026-09-29-agentsmd-routing-benchmarks)).

The pointer's real cost is the reads it causes. On Claude Code, Opus 5.5 mean tokens per run went from 150,264 without the pointer to 182,323 with it; most of that difference is the procedure reads the pointer asks for ([toolboxmd/agentsmd#174 records](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/174-routing-injection/records.jsonl)).

**Which hosts need it.** On naive prompts, Opus 5.5 on Claude Code loaded the skill from its description in 0 of 40 runs; with the pointer the target read before the first edit went from 3 of 20 to 20 of 20. OpenCode (Muse 1.3) went from 16 of 20, a cell scored before refused reads were excluded, to 20 of 20. Codex and Grok Build loaded the skill in 20 of 20 without one, so AgentsMD ships the pointer on Claude Code and OpenCode only. Hook output that exceeds a host's limit does not reach the model intact: Claude Code caps each hook string at 10,000 characters and passes a 2,000-character preview beyond it ([Claude Code](/docs/11-cross-platform/claude-code)); Codex limits each model-visible hook message to about 2,500 tokens ([Codex](/docs/11-cross-platform/codex)); Grok Build ignores SessionStart stdout ([Grok Build](/docs/11-cross-platform/others)).

**Implication.** Description-triggered loading is the default for topic-shaped skills. When a skill must be read before a specific action and the host does not load it from the description, inject a pointer, not the body, and test it on every host it reaches ([Triggers](/docs/05-authoring/triggers)). Inject the full body only when the whole text must be in context from the first turn, and budget for it re-firing after each compaction.

## The calculator

Inputs:

- **S** = SKILL.md size in lines.
- **D** = description + when_to_use combined character count.
- **F** = expected per-session firing rate (typical: 0-3).
- **M** = loading mechanism: description-triggered (default), session-start pointer, or full body injected at session start.
- **P** = pointer size in tokens (the AgentsMD pointer is about 105).
- **N** = number of other concurrently-active skills the agent may have loaded.

Per-skill auto-compaction footprint (approximate tokens):

```
footprint_tokens = S × 10           # ~10 tokens per line of prose
```

Per-session input cost:

```
if M == "full-body-hook":
    cost_tokens = footprint_tokens                  # full body, every session
elif M == "pointer":
    cost_tokens = 100 + P + (footprint_tokens if fired else 0)
                  # description + pointer every session; body when loaded
elif M == "description-triggered":
    cost_tokens = (100 if not_fired else footprint_tokens)
                  # ~100 for description; full body on activation
                  # so per-session: ~100 + (F * 0 if already-activated)
                  # First fire loads body; subsequent fires reuse the loaded body
```

Auto-compaction survival check:

```
if footprint_tokens > 5000:
    after_compaction = "first 5000 tokens only"
else:
    after_compaction = "full body retained"
```

Concurrent-skills check (before compaction kicks in):

```
total_active_token_budget = 25000
your_share = footprint_tokens
remaining_for_others = total_active_token_budget - your_share
how_many_others_at_5k_each = remaining_for_others / 5000
```

A 500-line skill (5,000 tokens) leaves 20,000 tokens for ~4 other concurrently-active skills before compaction starts dropping the oldest. A 1,000-line skill leaves 15,000 tokens and immediately gets truncated to 5,000 after the next compaction.

## Worked example: karpathy-wiki

- **S** = 476 lines (`REVIEWER` verification: 476 not 455, post v2.2).
- **footprint_tokens** ≈ 4,800 (just under the 5,000 floor).
- **D** ≈ 750 chars (description only; no `when_to_use`). Well under the 1,024 spec cap and the 1,536 listing cap.
- **F** ≈ 1-3 captures per typical session.
- **M** = description-triggered. No SessionStart-hook injection.
- Per-session cost when not fired: ~100 tokens (description in listing).
- Per-session cost on first fire: ~4,900 tokens (description + body).
- Subsequent fires same session: 0 (body already loaded).
- Concurrent-skills room: ~20,000 remaining tokens, ~4 other skills at 5,000 tokens each before compaction.

The 476-line cap was a v2.2 design constraint, not an accident. Audit Finding context (`LESSONS` 2.1 framing): "the 500-line SKILL.md is roughly 5,000 tokens, which is the compaction-survival ceiling." Net change in v2.2 was +21 lines (from 455 to 476). The design pressure that kept it under 500 was real.

If karpathy-wiki had grown to 1,200 lines, every long session would silently lose half the iron laws after auto-compaction. The user would see the agent comply for the first hour and then quietly stop following the rules after a compaction event. This is the most insidious cost of overshooting the budget.

## Design choices the numbers force

- **Push detail into `references/`.** The agent reads SKILL.md by default; references load only when the agent decides to read them (or when SKILL.md links to one inline). Heavy reference material (API docs, comprehensive syntax) belongs there. The agent-skills spec rule: file references one level deep from SKILL.md, no nested chains.
- **Front-load triggers in the description.** The 1,536-char listing truncation makes the bottom of long descriptions invisible.
- **Pick description-triggered loading as the default; add a pointer for moments.** A pointer of about 105 tokens made a moment-shaped skill load where its description did not. Full-body injection costs the whole body every session and after each compaction.
- **Use `model:` and `effort:` overrides surgically.** A skill that demands Opus declares it; the user does not need to switch. (Claude Code only; cross-platform skills should not assume this works elsewhere.)
- **Audit your SKILL.md size at every ship.** `wc -l SKILL.md` is the cheapest gate. If it is over 500, the next ship's plan should include a "split to references" task.

## When the numbers do not apply

- The `25,000 / 5,000` re-attach rule is Claude Code's. This repo's [Codex](/docs/11-cross-platform/codex) and [Gemini CLI](/docs/11-cross-platform/gemini-cli) pages record no equivalent; check the host you target. Gemini CLI supports Agent Skills natively (descriptions always listed, bodies on activation), and `GEMINI.md` is always-on context like `CLAUDE.md`.
- The `25,000 / 5,000` numbers match the Claude Code docs as re-read on 2026-09-29. They will change. Re-fetch when shipping.
- Fork-mode skills (`context: fork` + `agent`) do not pay the parent context's compaction tax; the fork has its own context. This is the cost-saving rationale for forking; see [Mental model](/docs/02-mental-model) and `REVIEWER` M3.

## Sources

- `REVIEWER` G2 (the 25k auto-compaction budget; the 5k per-skill survival floor; 500 lines ≈ 5,000 tokens); re-checked against the [Claude Code Skills docs](https://code.claude.com/docs/en/skills) on 2026-09-29.
- `REVIEWER` G7 (per-skill `model:` and `effort:` overrides).
- Per-host listing and hook-output limits: [Claude Code](/docs/11-cross-platform/claude-code), [Codex](/docs/11-cross-platform/codex), [Grok Build and OpenCode](/docs/11-cross-platform/others), each checked 2026-09-29 against the primary sources they cite.
- [obra/superpowers#1220](https://github.com/obra/superpowers/issues/1220) (full-body injection cost; first recorded in `LANDSCAPE` 2.1).
- [Routing case study](/case-studies/2026-09-29-agentsmd-routing-benchmarks) and the [#174 records](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/174-routing-injection/records.jsonl) (pointer size, per-host results, mean tokens per run).
- `LANDSCAPE` 1.3 (Anthropic Claude Code docs lifecycle; auto-compaction behavior).

Cross-links: [Three questions](/docs/03-three-questions) (Q3), [Triggers](/docs/05-authoring/triggers) (when a skill needs a pointer), [Line budget](/docs/05-authoring/line-budget) (the 500-line rule), [Frontmatter reference](/docs/05-authoring/frontmatter) (where `model:` and `effort:` live), [Claude Code cross-platform notes](/docs/11-cross-platform/claude-code) (the SessionStart hook), [Mental model](/docs/02-mental-model) (when to fork).
