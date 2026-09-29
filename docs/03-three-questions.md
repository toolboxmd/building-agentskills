# The three-question framework

Authoring a skill well requires answering three questions. They are the hero mental model for this repo. Every other doc anchors back to one of them.

1. **Who invokes?** Is the skill auto-triggered by the agent, user-invoked only, or both?
2. **What fires on rules?** Is each invariant in your SKILL.md decoration (the agent reads and decides) or mechanism (a script, validator exit code, hook, or captured artifact fires on it)?
3. **What is the token budget?** Does your skill fit the auto-compaction floor (under ~5,000 tokens / ~500 lines), each host's description-listing limit (1,536 characters per entry on Claude Code, 400 bytes on Grok Build), and the per-session cost ceiling you can afford?

These three questions are independent. A skill can pass the budget question but fail the firing-mechanism question (decoration without enforcement). It can pass the mechanism question but fail the invocation question (the right rules with no one to apply them). All three must answer correctly for the skill to land.

## Question 1: who invokes?

The agent, the user, or both. The choice determines the frontmatter.

- **Agent only (auto-trigger).** The default for skills. The description names triggering conditions, and the agent may load the skill when a request matches them. Set nothing extra in frontmatter. Whether matching is enough depends on the shape of the need (below).
- **User only.** Set `disable-model-invocation: true` (Claude Code; see [the Claude Code field reference](/docs/11-cross-platform/claude-code)). The skill appears in `/skills` and on `/skill-name` invocation but the agent will not auto-fire. Use for side-effecting workflows: deploys, releases, commits.
- **Both.** Set `user-invocable: true` in addition to (or instead of) `disable-model-invocation`. The agent may auto-fire AND the user may invoke explicitly.

### Topic-shaped and moment-shaped needs

Description matching works when the request names the topic: "ping skill", "fill in this PDF", "what do we know about X". The agent sees the words the description lists and loads the skill.

It is not enough when the skill must be read at a moment: before an edit, a commit or a pull request. The request names the task, not the moment, and the agent starts acting. On Claude Code, Opus 5.5 never loaded the AgentsMD `operations` skill from its description on naive prompts (0 of 40 runs, [toolboxmd/agentsmd#164](https://github.com/toolboxmd/agentsmd/issues/164)). A session-start pointer, a short always-loaded note naming the skill and the actions, took the target read before the first edit from 3 of 20 to 20 of 20 ([toolboxmd/agentsmd#174](https://github.com/toolboxmd/agentsmd/issues/174)). Codex and Grok Build loaded the same skill without a pointer, so the gap is host- and model-specific.

For a moment-shaped skill, answer Question 1 with three parts: the description, a session-start pointer on the hosts that need it, and before-clauses in the routing table that name each action. The setup and numbers are in the [routing case study](/case-studies/2026-09-29-agentsmd-routing-benchmarks); the wording rules are in [Triggers](/docs/05-authoring/triggers).

The deeper why is in [Mental model](/docs/02-mental-model) (skills vs CLAUDE.md vs hooks vs slash commands). The taxonomy is in [Frontmatter reference](/docs/05-authoring/frontmatter).

### Worked answer for karpathy-wiki

Karpathy-wiki is **agent only** (auto-trigger). The description ([lines 3–12 of the v2.2 karpathy-wiki SKILL.md](https://github.com/toolboxmd/karpathy-wiki/blob/4f4c00d/skills/karpathy-wiki/SKILL.md?plain=1#L3-L12)) opens with "Load at the start of EVERY conversation" and then enumerates eight event-shaped triggers ("any research agent or research subagent completes or returns a file; new factual information is found; ...") and three question-shaped triggers ("user asks 'what do we know about X' / 'how do we handle Y'"). The user never types `/karpathy-wiki`; the agent picks it up because the description matches the moment.

The choice is load-bearing. If karpathy-wiki were user-invoked, the user would have to remember to type `/wiki` every time a research agent returned a file (the dominant trigger). The wiki would gain a few entries per week instead of dozens. The auto-trigger is the entire point.

## Question 2: what fires on rules?

Every line in your SKILL.md containing "must," "always," "never," or a numeric threshold is making a claim about behavior. The question is: what enforces the claim?

> One-line plain-English form: *if this rule is broken, what code will notice and stop the agent?* If nothing — rewrite the rule. We shorten this question to "what fires on it?" everywhere it appears below.

- **Decoration.** The agent reads the line and decides whether to act on it. Acceptable for guidance prose ("when in doubt, prefer simpler"). Dangerous for invariants ("must validate the manifest before commit"). Decoration is a wish.
- **Mechanism.** A script, a validator exit code, a hook, or a captured artifact whose presence the next turn checks fires on the line. The validator exits non-zero, the hook blocks the tool call, the captured file shows up in `.wiki-pending/`. Mechanism is a contract.

The full deep dive is in [Mechanism vs decoration](/docs/07-mechanism-vs-decoration). The audit method: grep your SKILL.md for "must," "always," "never," and any digits. For each hit, ask "what fires on this if violated?" If the answer is "the agent decides," wire it.

The reviewer's sharpened framing (`REVIEWER`, "Stress test of the decoration vs mechanism headline"):

> Every threshold, invariant, or rule in your SKILL.md is either decoration or mechanism. Decoration is fine for guidance prose. For invariants (words like "must," "always," "never," numeric thresholds), decoration is a wish; mechanism is a contract. Any line containing "must" or a numeric threshold should answer the question "what fires on this if violated?" If the answer is "the agent decides," rewrite as guidance or wire to a mechanism.

### Worked answer for karpathy-wiki

Karpathy-wiki has three production wirings of decoration to mechanism, all in v2.2 (commits cited from `LESSONS` 2.1):

- **Index-size threshold.** Pre-v2.2 SKILL.md said "Split or atom-ize `index.md` when it exceeds ~200 entries / 8KB / 2000 tokens." The live wiki was 25 KB (3x over) and the agent never wrote a single schema-proposal capture across 30+ ingests because nothing measured. Commit `dabf10a` wired ingest step 7.6 to compute size and write a schema-proposal capture file when over. The threshold became a mechanism. Finalized in `0e0f815` after the heredoc whitespace bug.
- **Manifest origin contract.** Iron Rule #7 enumerated valid `origin` values without enumerating the empty string; two live entries had `origin: ""` because the validator did not check. Commit `36f0aa8` added `wiki-manifest.py validate` returning exit 1 on empty/typename/relative-path origins; SKILL.md Iron Rule #7 strengthened in commit `d325dda`. Decoration became script-with-exit-code.
- **Validator-blocks-commit.** Pre-v2.2 SKILL.md said "Do NOT commit a wiki state where the validator fails." The audit traced 7 broken links to the ingester ignoring validator output. Commit `d325dda` strengthened the prose to "the ingester MUST NOT call `wiki-commit.sh` if the validator exits non-zero for any touched page." This is still mostly prose, but it is paired with a code-block-link skip fix (`f72bfc3`) so the validator stops producing false positives that the ingester might rationalize ignoring.

The auditor named decoration vs mechanism as "the strongest signal for what v2.2-hardening should fix" ([karpathy-wiki v2.2 audit, line 366](https://github.com/toolboxmd/karpathy-wiki/blob/4f4c00d/docs/planning/2026-04-24-karpathy-wiki-v2.2-audit.md?plain=1#L366)). Three wirings later, the rule's authority is evidenced; see [Mechanism vs decoration](/docs/07-mechanism-vs-decoration) for the full case studies.

## Question 3: what is the token budget?

Three budgets. All three matter.

- **Auto-compaction budget.** Claude Code carries skills forward across compaction within a 25,000-token shared budget, keeping the first 5,000 tokens of each. A 500-line SKILL.md is roughly 5,000 tokens (the conversion is approximate but useful as a rule of thumb). A skill above that ceiling is silently truncated after compaction. Source: [Claude Code Skills docs](https://code.claude.com/docs/en/skills), re-read 2026-09-29.
- **Description listing budget.** Every host lists each skill's description, and each caps it differently: Claude Code cuts the combined `description` and `when_to_use` at 1,536 characters and gives the whole listing 1% of the context window; Codex, Grok Build and OpenCode have their own limits. The agent-skills spec caps the `description` field at 1,024 characters. The per-host table is in [Token economics](/docs/04-token-economics).
- **Per-session cost.** Every description in the listing is paid every session. Session-start injection adds its full text every session: the whole `using-superpowers` SKILL.md cost about 17,800 tokens over 57 hours and 13 firings ([obra/superpowers#1220](https://github.com/obra/superpowers/issues/1220)), while the AgentsMD pointer is about 105 tokens.

The full numerical breakdown is in [Token economics](/docs/04-token-economics), which gives you a calculator: input your SKILL.md size, your loading mechanism (description-trigger, pointer or full-body hook), your per-session firing rate, and you get an estimated cost.

### Worked answer for karpathy-wiki

Karpathy-wiki's SKILL.md is 476 lines as of v2.2 (`REVIEWER` verification table). At ~10 tokens per line, that is roughly 4,800 tokens, just under the 5,000-token auto-compaction floor. The audit checked the cap during planning; v2.2's net change was +21 lines (well within budget).

The description (lines 3-12) is approximately 750 characters, well under the 1,024 spec cap. Combined with `when_to_use` (not used here), it is well under the 1,536-character listing cap.

Karpathy-wiki uses description-triggered loading (no SessionStart hook injection in the skill itself), so per-session cost is the description in the listing when the skill does not fire and ~5,000 tokens more when it does. The skill fires often (typical session has 1-3 captures), but the cost amortizes against the value of the captured knowledge. The cost would be different (and probably unacceptable) if it used SessionStart injection; that is the conscious trade-off discussed in [Token economics](/docs/04-token-economics).

The number to remember: 476 lines, ~5k tokens, fits the 25k auto-compaction budget with room for at least four other concurrently active skills before truncation kicks in.

## Why these three questions

They are independent. They are minimal (no fourth question is forced by any v2.2 evidence). They cover the three classes of failure the v2.2 ship surfaced:

- A skill that the agent never invokes is a Question 1 failure (description does not name triggers, a moment-shaped skill relies on its description alone, or invocation taxonomy is wrong).
- A skill whose rules are decoration is a Question 2 failure (the audit found three of these in v2.2).
- A skill that bloats the budget is a Question 3 failure (the auto-compaction floor is the silent killer; a 1,200-line skill survives one turn and gets truncated after compaction).

The three blocker docs in this repo ([01 quickstart](/docs/01-quickstart), [02 mental model](/docs/02-mental-model), [04 token economics](/docs/04-token-economics)) each unblock one of the three audiences who hit one of the three failures. Read those three; then come back here.

## Authoring loop using the framework

When designing a new skill or auditing an existing one:

1. Answer Question 1 explicitly. Write down "this skill is invoked by [agent / user / both]." Pick the frontmatter accordingly. If the agent must read it before a specific action, also write down which hosts get a session-start pointer.
2. Grep your SKILL.md for "must," "always," "never," and digits. For each hit, write "fires on: [name of script / hook / captured file]." Anything that resolves to "the agent decides" is decoration; either rewrite as guidance or wire it to a mechanism.
3. `wc -l SKILL.md`. If over 500, push detail to `references/`. Count the description's characters; if over 1,024 for description alone, over 1,536 combined on Claude Code, or over 400 bytes for a Grok Build entry, tighten.

If you do this honestly, the skill ships ready. If you skip a question, the next audit will find it.

## Sources

> See [Overview → Sources](/docs/00-overview#sources) for what `LANDSCAPE`, `REVIEWER`, and `LESSONS` refer to.

- `REVIEWER`, "Stress test of the decoration vs mechanism headline," recommendation (the three-question framing).
- `LESSONS` 2.1 (the three karpathy-wiki decoration-to-mechanism wirings, commits `dabf10a`, `36f0aa8`, `d325dda`).
- `REVIEWER` G10 (the user-invocable / disable-model-invocation taxonomy).
- `REVIEWER` G2 (the 25k auto-compaction budget, the 5k per-skill survival floor).
- Per-host listing limits: [Claude Code](/docs/11-cross-platform/claude-code), [Codex](/docs/11-cross-platform/codex), [Grok Build and OpenCode](/docs/11-cross-platform/others), checked 2026-09-29.
- [Routing case study](/case-studies/2026-09-29-agentsmd-routing-benchmarks) (0/40 without a pointer, 3/20 to 20/20 with one, the 105-token pointer).
- [obra/superpowers#1220](https://github.com/obra/superpowers/issues/1220) (17,800 tokens over 57 hours and 13 firings).

Cross-links: [Mental model](/docs/02-mental-model) (Q1 deep dive), [Mechanism vs decoration](/docs/07-mechanism-vs-decoration) (Q2 deep dive), [Token economics](/docs/04-token-economics) (Q3 deep dive), [v2.2 case study](/case-studies/2026-04-25-karpathy-wiki-v2.2) (the worked answers above expanded).

Reverse cross-links to honor: every doc that answers one of the three questions MUST link back here. Currently linking back: [00 overview](/docs/00-overview), [02 mental model](/docs/02-mental-model), [04 token economics](/docs/04-token-economics), [07 mechanism vs decoration](/docs/07-mechanism-vs-decoration), [10 anti-patterns](/docs/10-anti-patterns), [v2.2 case study](/case-studies/2026-04-25-karpathy-wiki-v2.2). The README also references the three questions verbatim.
