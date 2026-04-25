# Token economics: the why of skill constraints

This is Question 3 of the hero framework (`docs/03-three-questions.md`). What is the token budget for your skill, and what governs it?

The 500-line cap is not a stylistic preference. It is the auto-compaction survival floor. The 1024-character description cap is not arbitrary; it is what fits in the listing the agent reads on every turn. The SessionStart-hook injection pattern is not free; it costs the full SKILL.md per session. Authors who do not know these numbers ship 1,200-line skills and wonder why the agent stops following the rules after a long session.

This page gives you the numbers, the calculator, and the design choices the numbers force.

## The four budgets

### 1. The auto-compaction budget (25,000 tokens shared, 5,000-token per-skill survival floor)

Source: `LANDSCAPE` 1.3 (Anthropic Claude Code docs, https://code.claude.com/docs/en/skills); `REVIEWER` G2.

Claude Code carries activated skills forward across auto-compaction within a 25,000-token shared budget. The mechanism keeps the first 5,000 tokens of each skill, most-recently-invoked first; older skills can be dropped after compaction.

- A 500-line SKILL.md is approximately 5,000 tokens (the rule of thumb is ~10 tokens per line for prose; tighter prose runs lower, code-heavy prose runs higher).
- A 500-line skill survives compaction. A 1,000-line skill is truncated to its first half after compaction. The truncated half is the part the agent will not see.
- "Most-recently-invoked first" means the skill you invoked at minute 5 of a 4-hour session may be dropped after compaction; the skill invoked at minute 230 stays.

**Implication.** Keep your SKILL.md under 500 lines (5,000 tokens). If you are over, push detail to `references/<topic>.md`. The body of SKILL.md should be the smallest set of words that the agent needs to act correctly; reference detail goes in sibling files loaded on demand.

### 2. The description listing budget (1,024 / 1,536 / 8,000)

Three distinct numbers, often conflated. Source: `REVIEWER` B4, G2.

- **1,024 characters.** Hard cap on the `description` field in the agent-skills spec. Per https://agentskills.io/specification: "max 1024 chars."
- **1,536 characters.** Truncation threshold on the combined `description` + `when_to_use` text in Claude Code's skill listing. Per Claude Code docs: "the combined `description` and `when_to_use` text is truncated at 1,536 characters in the skill listing to reduce context usage." Long descriptions ARE accepted but only the first 1,536 chars are shown to the agent on each turn.
- **8,000 characters (or 1% of context window).** Total budget across ALL skills' descriptions, governed by the `SLASH_COMMAND_TOOL_CHAR_BUDGET` environment variable. Default is 1% of context window with an 8,000-character fallback.

**Implication.** Your description must front-load the trigger conditions. The 1,536-char Claude Code truncation ensures the first 1,536 chars are read; everything after is invisible. With many skills installed, the 8,000-char total budget further pressures each skill's description down. A skill whose triggers are at the bottom of a 1,000-char description may never fire because the agent only sees the top.

### 3. The per-skill `model:` and `effort:` overrides

Source: `REVIEWER` G7. Claude Code documents both fields:

- `model:` per-skill model override. Example: a skill that needs Opus reasoning can declare `model: claude-opus-4-7` in its frontmatter. The harness applies the override for the rest of the turn the skill is active.
- `effort:` per-skill reasoning level. Example: `effort: high` for a deep-thinking skill.
- Default: `inherit` (use the parent's model and effort).

**Implication.** A skill that is under-budget but needs reasoning power can demand it without forcing the user to choose. A `wiki doctor`-style skill (deep lint pass) that needs Opus does not need the user to manually switch; the skill declares it and the harness complies.

These fields are Claude Code only. Other harnesses do not honor them. See `docs/11-cross-platform/`.

### 4. The SessionStart-hook injection cost

Source: `LANDSCAPE` 2.1; `REVIEWER` G2; superpowers issue #1220.

A skill that uses the SessionStart-hook injection pattern (the `using-superpowers` shape) costs the FULL SKILL.md as input tokens every session. The hook reads SKILL.md, escapes for JSON, emits as `hookSpecificOutput.additionalContext`. The agent receives the entire body before its first turn.

The empirical anchor: superpowers issue #1220 measured ~17.8k tokens of SessionStart-hook injection over 57 hours across 13 firings of `using-superpowers`. That is ~1,370 tokens per firing on average; the skill body is the floor.

**Implication.** SessionStart injection guarantees the iron laws are in context every turn but costs full body size per session. Description-triggered loading (the default) costs zero when not invoked and ~5,000 tokens when invoked, but does not guarantee in-context presence (the agent may not match the description and skip the body entirely).

Use SessionStart injection only when the skill is the bootstrap (`using-superpowers` is the canonical exception). For a per-skill discipline rule that fires occasionally, description-triggered loading is the right default.

## The calculator

Inputs:

- **S** = SKILL.md size in lines.
- **D** = description + when_to_use combined character count.
- **F** = expected per-session firing rate (typical: 0-3).
- **M** = loading mechanism: description-triggered (default) or SessionStart-hook-injected.
- **N** = number of other concurrently-active skills the agent may have loaded.

Per-skill auto-compaction footprint (approximate tokens):

```
footprint_tokens = S × 10           # ~10 tokens per line of prose
```

Per-session input cost:

```
if M == "session-start-hook":
    cost_tokens = footprint_tokens                  # full body, every session
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
- **Pick description-triggered loading as the default.** SessionStart injection costs full body every session; only justify it when the skill is the bootstrap.
- **Use `model:` and `effort:` overrides surgically.** A skill that demands Opus declares it; the user does not need to switch. (Claude Code only; cross-platform skills should not assume this works elsewhere.)
- **Audit your SKILL.md size at every ship.** `wc -l SKILL.md` is the cheapest gate. If it is over 500, the next ship's plan should include a "split to references" task.

## When the numbers do not apply

- Other harnesses have different (or no) auto-compaction. Codex has no documented auto-compaction model; Gemini's Extensions are always-on (no compaction; everything in `GEMINI.md` loads at session start). Cross-platform numbers are in `docs/11-cross-platform/`.
- The `25,000 / 5,000` numbers are Claude Code-current as of 2026 docs. They will change. Re-fetch when shipping.
- Fork-mode skills (`context: fork` + `agent`) do not pay the parent context's compaction tax; the fork has its own context. This is the cost-saving rationale for forking; see `docs/02-mental-model.md` and `REVIEWER` M3.

## Sources

- `REVIEWER` G2 (the 25k auto-compaction budget; the 5k per-skill survival floor; 500 lines ≈ 5,000 tokens).
- `REVIEWER` G7 (per-skill `model:` and `effort:` overrides).
- `REVIEWER` B4 (the 1024 / 1536 / 8000 description-budget nuance).
- `LANDSCAPE` 2.1 (the SessionStart-hook injection cost; superpowers issue #1220 measurement).
- `LANDSCAPE` 1.3 (Anthropic Claude Code docs lifecycle; auto-compaction behavior).

Cross-links: `docs/03-three-questions.md` (Q3), `docs/05-authoring/line-budget.md` (the 500-line rule), `docs/05-authoring/frontmatter.md` (where `model:` and `effort:` live), `docs/11-cross-platform/claude-code.md` (the SessionStart hook), `docs/02-mental-model.md` (when to fork).
