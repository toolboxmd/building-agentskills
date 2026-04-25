# Prose discipline: voice and snippet-as-code rules

This page covers two distinct concerns that look like one. First, the voice and conventions for SKILL.md prose (Layer 2 superpowers conventions, mostly). Second, the silent correctness bug class that appears when SKILL.md prose embeds executable snippets (Layer 3, surfaced in karpathy-wiki v2.2 ship). The second is the more dangerous of the two and gets the larger share of this doc.

## Voice and conventions

Layer 2 superpowers convention. These rules apply to the SKILL.md body, not to your README or your CLAUDE.md.

- **Imperative for the agent.** "When you see X, do Y." Not "the user should see X." The skill is talking to the agent that will execute it.
- **Third-person for the description.** "Use when..." not "I help with..." The description is read by another agent (the orchestrator), not by the skill itself.
- **No first-person agent voice in the body.** Never "I capture," always "capture." The agent does not need a self-pronoun to know who is doing the action.
- **No time-sensitive prose.** Avoid "as of 2026" or "currently the latest version is X." A skill is read months after it was written; time-sensitive claims age into wrong claims. If a date matters, put it in a details-collapsed callout.
- **No emojis.** Zero across the 13 superpowers SKILL.md files (`LANDSCAPE` 3.2). Karpathy-wiki follows the same convention. Emojis degrade screen-reader output and signal "marketing" to the agent's pattern matcher.
- **"Your human partner" vs "the user."** Superpowers uses "your human partner" (40+ uses across the skills). Karpathy-wiki uses "the user." Both work; both are conventions, not rules. This repo does not mandate one. Pick a phrasing and stay consistent inside a single skill.

## Snippet-as-code: when SKILL.md prose is production code

This is the load-bearing section. Source: `LESSONS` 2.2 (the karpathy-wiki v2.2 heredoc bugs); `LANDSCAPE` 3.2; karpathy-wiki commits `dabf10a`, `0e0f815`.

When a SKILL.md teaches the agent how to do something by embedding a code snippet (bash heredoc, JSON template, YAML stub), the snippet must be byte-for-byte what the agent will execute. The skill's prose is not just documentation; for skills that drive headless subprocesses, the prose IS production code.

This applies most acutely to the karpathy-wiki shape: a SKILL.md that gets executed by a detached `claude -p` ingester. The ingester reads the SKILL.md prose and runs the bash literally. Subtle textual hazards (leading whitespace, line-ending differences, character substitution by markdown renderers, escape ambiguities) silently corrupt the agent's output without ever failing a test.

For skills whose prose is purely advisory (most superpowers discipline skills), this hazard is lower; the foreground agent has tooling to handle whitespace robustly. But even those skills can have snippets-in-prose that get copied verbatim into commit messages or generated files; the discipline is worth following everywhere.

### The two karpathy-wiki bugs in commit `dabf10a` (caught by reviewer in `0e0f815`)

**Bug 1: 3-space indent leak in heredoc.**

The schema-proposal heredoc body in SKILL.md was 3-space indented to match the markdown numbered-list rendering. Without `<<-EOF`, those leading spaces land in the rendered capture file. The validator (`wiki-validate-page.py:51`) checks `text.startswith("---\n")`; a leading-whitespace `---` becomes "no frontmatter" and the capture is rejected with no useful error.

The diff in `0e0f815`:

```
-   ---
-   title: "Schema proposal: split index.md (size threshold exceeded)"
-   ...
-   ---
+---
+title: "Schema proposal: split index.md (size threshold exceeded)"
+...
+---
```

**Bug 2: `wc -c` whitespace leak.**

macOS `wc -c` outputs `   8192` with leading whitespace. The captured size variable leaked the spaces into the trigger field, producing arithmetic-comparison ambiguity downstream. The fix: append `| tr -d ' '`.

Both bugs would have shipped malformed capture files in production if the reviewer had not caught them. Neither was caught by the original test, because the original test was a hand-cleaned variant of the snippet that hid the bugs.

### The fix: rehearse the snippet verbatim in tests

The fix in `0e0f815` rewrote the test to paste the bytes from SKILL.md into the test (no retyping, no hand-cleaning). It additionally asserted that the rendered capture file's first line is exactly `---`.

The discipline:

> When SKILL.md prose embeds a snippet that the agent will execute (bash heredoc, Python source, YAML template, JSON object), the snippet is production code. Test it by rehearsing the verbatim copy. Paste the bytes from SKILL.md into your test. Do not retype.

See `docs/06-testing/red-green-for-prose.md` for the prose-as-addition discipline that operationalizes this rule.

## The markdown-renders-whitespace hazard

Markdown renderers and code-fenced blocks inside numbered lists vary in how they preserve leading whitespace. The agent reading SKILL.md may see one thing; the agent executing the snippet may see another, depending on which renderer / parser was in the loop.

Mitigations:

- If your snippet's correctness depends on column-0 alignment (heredoc bodies, JSON contents, YAML frontmatter), use `<<-EOF` (which strips leading tabs but not spaces; you must also dedent the snippet manually inside the markdown source).
- Add a verifier: assert `head -1 file == '---'` (or the equivalent for your format).
- Avoid embedding heredocs inside markdown numbered lists if you can place them at top-level instead. The numbered-list indent is the most common source of leak.

## The platform-whitespace hazard

`wc -c`, `wc -l`, `du`, `df`, and similar tools emit different whitespace on BSD/macOS versus GNU/Linux. The macOS variants tend to right-align with leading spaces; the GNU variants tend to left-align with no leading whitespace. A snippet that works on Linux can produce malformed values on macOS without any error.

Mitigations:

- Normalize at the source: `| tr -d ' '` immediately after every `wc -c`, `wc -l`, `du`, `df`.
- Establish the convention everywhere in the skill, not just at the use site that bit you.
- In v2.2, the convention was already in `tests/unit/test-index-threshold-fires.sh:57`; only the SKILL.md snippet had not adopted it. The reviewer caught the gap.

## Auditing your prose

Before shipping a SKILL.md prose change:

- Grep for "I" used as agent self-reference. Replace with imperative.
- Grep for emojis. Remove.
- Grep for date words (`today`, `currently`, `as of`, year numbers in claims). Either remove or move to a dated callout.
- For every embedded snippet, ask: is this snippet copied verbatim into a test? If not, you have not verified it.
- Run the snippet manually in the target environment (macOS / Linux / Windows). The first run flushes platform-specific whitespace bugs.

## Sources

- `LESSONS` 2.2 (the karpathy-wiki v2.2 heredoc bugs; commits `dabf10a`, `0e0f815`).
- `LANDSCAPE` 3.2 (voice conventions across superpowers; the no-emoji rule).

Cross-links: `docs/06-testing/red-green-for-prose.md` (the prose-change testing discipline), `case-studies/2026-04-25-karpathy-wiki-v2.2.md` (the full ship narrative including the heredoc bugs).
