# Docs Hotfix: Paths, Links, Sources Glossary, "Fires on This" Rewrite — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Strip private path leaks and convert broken backtick-chip "links" to real Markdown links across the deployed docs site, add a sources-labels glossary, rewrite the "what fires on this" jargon for first-time readers, trim an inaccurate timing claim, and add two CI gates against future regressions.

**Architecture:** Two coupled PRs. Step A is a one-file companion PR to `toolboxmd/karpathy-wiki` (seeds the canonical concept page that three of our docs cite). Step B is the unified content fix in this repo plus two new CI gates, all in a single commit. Step B's PR MUST NOT open until Step A is merged (preflight gate).

**Tech Stack:** Markdown + Mintlify v4 (deployed at building-agentskills.toolbox.md). Bash for CI gates. The existing `tests/run-all.sh` dispatcher convention runs all `*.test.sh` files. No new runtime dependencies.

**Spec:** `docs/superpowers/specs/2026-05-06-docs-hotfix-paths-and-links-design.md` (v1.3, commit `de2c3b0`).

---

## File Structure

**Files modified in this repo (Step B — single commit):**
- `docs/00-overview.md` — `Sources` block rewrite + chip conversions + on-ramp prose for "fires on it"
- `docs/03-three-questions.md` — on-ramp insertion + chip conversions + back-reference to glossary
- `docs/09-evolution.md` — delete the "Four cycles in six months" sentence + chip conversions
- `docs/10-anti-patterns.md` — path-leak fix + chip conversions
- `docs/12-update-mechanism.md` — two path-leak fixes + chip conversions
- `docs/08-packaging-as-plugin.md` — path-leak fix + chip conversions
- `docs/11-cross-platform/claude-code.md` — path-leak fix + chip conversions
- `case-studies/2026-04-25-karpathy-wiki-v2.2.md` — two path-leak fixes (one with anchor format fix) + chip conversions

**Files created in this repo (Step C — same commit as B):**
- `scripts/check-no-bare-paths.sh` — helper script the bare-paths gate calls
- `tests/check-no-absolute-paths.test.sh` — `*.test.sh` file picked up by `run-all.sh`
- `tests/check-no-bare-paths.test.sh` — `*.test.sh` file with fixture self-tests

**Files NOT modified in this repo:**
- `README.md` — already clean; uses GitHub-relative form (correct for GitHub-rendered file)
- `docs.json` — sidebar group renaming is out of scope
- All other `docs/`, `case-studies/`, `examples/` files not listed above

**Files in companion repo `toolboxmd/karpathy-wiki` (Step A):**
- `wiki/concepts/claude-code-plugin-root-substitution.md` — new file, byte-for-byte copy of `~/wiki/concepts/claude-code-plugin-root-substitution.md`

---

## Conventions used throughout this plan

These are locked in the spec; reproduced here so the implementer doesn't need to flip back.

- **In-repo navigational link** (within `docs/`, `case-studies/`, `examples/`): `[text](/docs/<basename>)`, `[text](/case-studies/<basename>)`, `[text](/examples/<basename>)`. No `.md` extension.
- **Cross-repo link, stable target** (e.g., the wiki concept page Step A creates): `https://github.com/<org>/<repo>/blob/main/<path>`.
- **Cross-repo link, v2.2-historical target** (anything describing karpathy-wiki *as it was at v2.2*): `https://github.com/toolboxmd/karpathy-wiki/blob/4f4c00d/<path>`.
- **Line-range anchor**: append `?plain=1#L<n>` or `?plain=1#L<n>-L<m>`.
- **Heading anchor within Mintlify**: `/docs/00-overview#sources` (lowercase slug from heading text).
- **README.md exception**: keep its existing GitHub-relative form `[text](docs/X.md)` — do NOT convert to Mintlify form.

**Diff-scope rule (binding):** Only touch lines listed in the per-task tables. Do not reformat unrelated lines. If you notice an unrelated improvement, do NOT make it; instead append `## Implementer concerns` to the PR description with a `DONE_WITH_CONCERNS:` line per concern. Subagent reformatting hazard is a documented anti-pattern in this repo.

---

## Task 0: Step zero — verify URL convention against the live site

**Files:** none (preflight check only)

This is a five-minute sanity check. The spec's URL convention assumes Mintlify routes preserve the `docs/` prefix (`/docs/03-three-questions`, NOT `/03-three-questions`). If the deployed site disagrees, every link rewrite is wrong. Verify before touching any file.

- [ ] **Step 1: Probe the correct URL form**

Run:
```bash
curl -sI https://building-agentskills.toolbox.md/docs/03-three-questions | head -1
```
Expected output (status code on first line): `HTTP/2 200` (or `HTTP/1.1 200`).

- [ ] **Step 2: Probe the wrong URL form to confirm 404**

Run:
```bash
curl -sI https://building-agentskills.toolbox.md/03-three-questions | head -1
```
Expected output: `HTTP/2 404`.

- [ ] **Step 3: HALT if either probe disagrees**

If Step 1 returns 404 or Step 2 returns 200, **HALT and report to the reviewer**. The URL convention is wrong; proceeding would break ~50–80 links on the live site. The reviewer will adjust the spec and restart.

- [ ] **Step 4: Probe the cross-repo SHA-pinned URLs**

The spec uses `4f4c00d` as the v2.2 pin and `main` for stable artifacts. Verify all five distinct cross-repo URLs that will appear in the diff resolve:
```bash
curl -sI https://github.com/toolboxmd/karpathy-wiki/blob/4f4c00d/skills/karpathy-wiki/SKILL.md | head -1                              # expect: 200
curl -sI https://github.com/toolboxmd/karpathy-wiki/blob/4f4c00d/docs/superpowers/specs/2026-04-24-karpathy-wiki-v2.2-design.md | head -1   # expect: 200
curl -sI https://github.com/toolboxmd/karpathy-wiki/blob/4f4c00d/docs/planning/2026-04-24-karpathy-wiki-v2.2-audit.md | head -1       # expect: 200
curl -sI https://github.com/toolboxmd/karpathy-wiki/blob/main/TODO.md | head -1                                                       # expect: 200
curl -sI https://github.com/obra/superpowers | head -1                                                                                # expect: 200 or 301
```

The wiki concept-page URL is checked separately in Task 2 (after Step A merges).

- [ ] **Step 5: Note success and proceed**

If all probes match expected, the spec's conventions are validated. Proceed to Task 1.

(No commit. This is a verification step, not a code change.)

---

## Task 1: Step A — companion PR to toolboxmd/karpathy-wiki

**Files:**
- Source: `~/wiki/concepts/claude-code-plugin-root-substitution.md` (author's local file)
- Create: `toolboxmd/karpathy-wiki/wiki/concepts/claude-code-plugin-root-substitution.md`

The hotfix in our repo will link to this file at `https://github.com/toolboxmd/karpathy-wiki/blob/main/wiki/concepts/claude-code-plugin-root-substitution.md`. That URL must resolve before Step B's PR opens.

- [ ] **Step 1: Confirm the local file exists and read it**

Run:
```bash
test -f ~/wiki/concepts/claude-code-plugin-root-substitution.md && echo "FOUND" || echo "MISSING"
wc -l ~/wiki/concepts/claude-code-plugin-root-substitution.md
```
Expected: `FOUND` plus a line count (currently around 100–200 lines).

If the file is missing, halt and report. The implementer cannot proceed without the source content.

- [ ] **Step 2: Clone or check out the karpathy-wiki repo**

Run:
```bash
test -d ~/dev/toolboxmd/karpathy-wiki || git clone https://github.com/toolboxmd/karpathy-wiki ~/dev/toolboxmd/karpathy-wiki
cd ~/dev/toolboxmd/karpathy-wiki
git checkout main && git pull --ff-only
```

- [ ] **Step 3: Create the target directory**

Run:
```bash
cd ~/dev/toolboxmd/karpathy-wiki
mkdir -p wiki/concepts
```

- [ ] **Step 4: Copy the file byte-for-byte**

Run:
```bash
cp ~/wiki/concepts/claude-code-plugin-root-substitution.md ~/dev/toolboxmd/karpathy-wiki/wiki/concepts/claude-code-plugin-root-substitution.md
```

Verify byte-identical with diff:
```bash
diff -q ~/wiki/concepts/claude-code-plugin-root-substitution.md ~/dev/toolboxmd/karpathy-wiki/wiki/concepts/claude-code-plugin-root-substitution.md
```
Expected output: silent (no diff).

**Do NOT edit the frontmatter.** The `quality:`, `sources:`, and `related:` fields stay as-is per the spec, even though some `related:` targets do not exist in the public repo (they are inert YAML, not rendered as broken HTML links).

- [ ] **Step 5: Create a feature branch and commit**

Run:
```bash
cd ~/dev/toolboxmd/karpathy-wiki
git checkout -b seed-wiki-concepts-plugin-root
git add wiki/concepts/claude-code-plugin-root-substitution.md
git commit -m "docs: seed wiki/concepts with plugin-root substitution page

This page documents the \${CLAUDE_PLUGIN_ROOT} config-time-token-vs-shell-env-var
gotcha. Three pages in toolboxmd/building-agentskills (10-anti-patterns,
08-packaging-as-plugin, 11-cross-platform/claude-code) cite it. Seeding
it here gives those citations a public canonical home.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 6: Push and open the PR**

Run:
```bash
cd ~/dev/toolboxmd/karpathy-wiki
git push -u origin seed-wiki-concepts-plugin-root
gh pr create --repo toolboxmd/karpathy-wiki --title "docs: seed wiki/concepts with plugin-root substitution page" --body "$(cat <<'EOF'
## Summary

- Adds `wiki/concepts/claude-code-plugin-root-substitution.md` as the canonical public concept page for the `${CLAUDE_PLUGIN_ROOT}` config-time-token gotcha.
- Three pages in `toolboxmd/building-agentskills` cite this concept; seeding it here gives those citations a public, byte-stable URL.

## Test plan

- [ ] File renders cleanly on GitHub blob view.
- [ ] After merge, the URL `https://github.com/toolboxmd/karpathy-wiki/blob/main/wiki/concepts/claude-code-plugin-root-substitution.md` returns 200.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Note the PR number returned. The next task uses it.

- [ ] **Step 7: Get this PR merged**

This is a one-file PR. Have it reviewed and merged before proceeding to Task 2. **Do not proceed past this step until the PR is merged.**

If review takes longer than expected, the implementer can pause this plan, work on something else, and resume at Task 2 once the PR is merged.

(The Step-A commit is on a separate branch in a separate repo. No commit happens in `building-agentskills` for this task.)

---

## Task 2: Step-A preflight verification

**Files:** none (preflight check only)

Before opening Step B's PR, verify Step A merged and the new wiki concept-page URL resolves on `main`.

- [ ] **Step 1: Confirm Step A's PR is merged**

Run (replacing `<PR-number>` with the number from Task 1 Step 6):
```bash
gh pr view <PR-number> --repo toolboxmd/karpathy-wiki --json state -q .state
```
Expected output: `MERGED`.

If output is anything else (`OPEN`, `CLOSED`), halt and report.

- [ ] **Step 2: Confirm the file is reachable on `main`**

Run:
```bash
curl -sI https://github.com/toolboxmd/karpathy-wiki/blob/main/wiki/concepts/claude-code-plugin-root-substitution.md | head -1
```
Expected output: `HTTP/2 200`.

If 404, halt and report. The merge may not have propagated, or the path is wrong.

- [ ] **Step 3: Note success and proceed**

If both checks pass, Step B is unblocked. Proceed to Task 3.

(No commit. Verification step.)

---

## Task 3: Create the hotfix branch

**Files:** none (branch creation only)

All Step B and Step C work happens on one branch in this repo, in one commit at the end.

- [ ] **Step 1: Verify clean working tree**

Run:
```bash
cd ~/dev/toolboxmd/building-agentskills
git status --short
```
Expected: empty output (or only `?? PLAN-v0.1-mintlify.md` which is intentionally untracked).

If there are uncommitted changes, halt and report.

- [ ] **Step 2: Create the hotfix branch**

Run:
```bash
git checkout main
git pull --ff-only
git checkout -b docs-hotfix-paths-and-links
```

(No commit yet. The single commit lands at Task 14.)

---

## Task 4: Rewrite docs/00-overview.md

**Files:**
- Modify: `docs/00-overview.md` (lines 60–65, 79, 83, 87–92)

Two prose rewrites (line 60 on-ramp; lines 87–92 Sources block) plus four chip conversions on lines 61–64, three on line 79, one on line 83.

The current file has 92 lines. After the Sources block expansion, it'll be slightly longer.

- [ ] **Step 1: Verify the current state of line 60**

Run:
```bash
sed -n '60p' docs/00-overview.md
```
Expected output: starts with `- Decoration vs mechanism. Every threshold or invariant in your SKILL.md must answer "what fires on it?"` and ends with ``Documented in `07-mechanism-vs-decoration.md`.``

If the line content has drifted, the implementer must reconcile against the spec before editing.

- [ ] **Step 2: Replace line 60 with the on-ramp prose**

Use Edit tool (or equivalent) to replace exactly:
```
- Decoration vs mechanism. Every threshold or invariant in your SKILL.md must answer "what fires on it?" If the answer is "the agent decides," wire it to a script, validator exit code, hook, or captured artifact. Documented in `07-mechanism-vs-decoration.md`.
```
With:
```
- Decoration vs mechanism. Every threshold or invariant in your SKILL.md must answer one question: *if this rule is broken, what code will notice and stop the agent?* If the answer is "nothing — the agent decides," rewrite the rule into something concrete: a script, validator exit code, hook, or captured artifact. We use the shorthand "what fires on it?" for this question throughout the docs. Documented in [Mechanism vs decoration](/docs/07-mechanism-vs-decoration).
```

- [ ] **Step 3: Convert chip on line 61**

Replace:
```
- The three-question framework. Who invokes? What fires on rules? What is the token budget? The hero mental model. See `03-three-questions.md`.
```
With:
```
- The three-question framework. Who invokes? What fires on rules? What is the token budget? The hero mental model. See [Three questions](/docs/03-three-questions).
```

- [ ] **Step 4: Convert chip on line 62**

Replace:
```
- Heredoc-in-prose silent correctness bugs. Snippets in SKILL.md prose are production code when a headless subprocess executes them; test verbatim. See `05-authoring/prose-discipline.md`.
```
With:
```
- Heredoc-in-prose silent correctness bugs. Snippets in SKILL.md prose are production code when a headless subprocess executes them; test verbatim. See [Prose discipline](/docs/05-authoring/prose-discipline).
```

- [ ] **Step 5: Convert chip on line 63**

Replace:
```
- TDD inversions. Regression-pin and mechanism-rehearsal as legitimate "tests pass immediately" cases. See `06-testing/tests-that-pass-immediately.md`.
```
With:
```
- TDD inversions. Regression-pin and mechanism-rehearsal as legitimate "tests pass immediately" cases. See [Tests that pass immediately](/docs/06-testing/tests-that-pass-immediately).
```

- [ ] **Step 6: Convert chip on line 64**

Replace:
```
- Subagent reformatting hazard. Implementer subagents reformat unrelated lines as a "quality gesture"; the cure is an explicit Diff Scope clause. See `10-anti-patterns.md`.
```
With:
```
- Subagent reformatting hazard. Implementer subagents reformat unrelated lines as a "quality gesture"; the cure is an explicit Diff Scope clause. See [Anti-patterns](/docs/10-anti-patterns).
```

**Do NOT touch line 65** — the `docs/11-cross-platform/` chip is a directory reference, not a single-file navigational chip. Stays as bare backticks.

- [ ] **Step 7: Convert three chips on line 79**

Replace:
```
The three blocker docs (`docs/01-quickstart.md`, `docs/02-mental-model.md`, `docs/04-token-economics.md`) close the audience gap a layered repo would otherwise leave: a first-time author needs to know how to ship a hello-world skill, when a skill is the right primitive at all, and why the constraints exist. Read those three first. The rest of the docs make sense once those are in place.
```
With:
```
The three blocker docs ([01 quickstart](/docs/01-quickstart), [02 mental model](/docs/02-mental-model), [04 token economics](/docs/04-token-economics)) close the audience gap a layered repo would otherwise leave: a first-time author needs to know how to ship a hello-world skill, when a skill is the right primitive at all, and why the constraints exist. Read those three first. The rest of the docs make sense once those are in place.
```

- [ ] **Step 8: Convert chip on line 83**

Replace:
```
This repo is not a tutorial. It does not walk you through writing your first ten skills, does not pick a stack for you, does not have opinions about your project layout. It is a reference structured as docs you read on demand. The hero framework (`03-three-questions.md`) is the only doc you should read end-to-end on first contact; everything else is a destination you arrive at when a specific question forces you there.
```
With:
```
This repo is not a tutorial. It does not walk you through writing your first ten skills, does not pick a stack for you, does not have opinions about your project layout. It is a reference structured as docs you read on demand. The hero framework ([03 three questions](/docs/03-three-questions)) is the only doc you should read end-to-end on first contact; everything else is a destination you arrive at when a specific question forces you there.
```

**Do NOT touch line 85** — the `docs/11-cross-platform/` chip there is a directory reference. Leaves as bare backticks.

- [ ] **Step 9: Replace the Sources block (lines 87–92)**

The current block (verified by `sed -n '87,92p' docs/00-overview.md` at HEAD `de2c3b0`):
```
## Sources

- `LANDSCAPE` (`/Users/lukaszmaj/dev/bigbrain/research/building-agentskills/2026-04-24-skill-authoring-landscape-2026.md`) sections 1.1, 1.2, 1.3, 7.1.
- `REVIEWER` (`/Users/lukaszmaj/dev/bigbrain/research/building-agentskills/2026-04-24-analyzer-review.md`), Verdict and What the analyzer got right.

Cross-links: README.md, docs/03-three-questions.md.
```

Replace with:
```
## Sources

Throughout these docs we cite three nicknames for the private research notes this site was distilled from. The nicknames let us label provenance without reprinting the source material:

- `LANDSCAPE` — a 2026 survey of skill-authoring practice and tooling.
- `REVIEWER` — an adversarial-review pass over the Layer-3 patterns.
- `LESSONS` — the karpathy-wiki v2.2 ship retrospective.

These three documents are private; the citations are for honesty about what each claim rests on, not actionable links. Where a public source exists (Anthropic docs, agent-skills spec, GitHub commits), we cite it directly with a working link.

For this page specifically:

- `LANDSCAPE` sections 1.1, 1.2, 1.3, 7.1.
- `REVIEWER`, "Verdict" and "What the analyzer got right."

Cross-links: [README](https://github.com/toolboxmd/building-agentskills/blob/main/README.md), [Three questions](/docs/03-three-questions).
```

This rewrite removes the two `/Users/` path leaks for this file (they were on lines 89 and 90 of the original block).

- [ ] **Step 10: Verify the file**

Run:
```bash
grep -n '/Users/' docs/00-overview.md
```
Expected: empty output (no matches).

Run:
```bash
grep -nE '`(docs/|case-studies/|examples/)' docs/00-overview.md
```
Expected: only line 65 (`docs/11-cross-platform/`) and line 85 (`docs/11-cross-platform/`) — both directory references that we deliberately left as bare backticks.

(No commit yet. The single commit lands at Task 14.)

---

## Task 5: Rewrite docs/03-three-questions.md

**Files:**
- Modify: `docs/03-three-questions.md` (line 16, line 19, line 23, insert-after-29, line 34, line 48, line 58, line 66, line 78, line 90, line 98, line 100)

Many chip conversions plus an on-ramp insertion plus a back-reference. Lines 27–29 stay as-is; the on-ramp goes between line 29 and line 31.

- [ ] **Step 1: Convert chip on line 16**

Replace:
```
- **User only.** Set `disable-model-invocation: true` (Claude Code; see `docs/11-cross-platform/claude-code.md` for the field reference). The skill appears in `/skills` and on `/skill-name` invocation but the agent will not auto-fire. Use for side-effecting workflows: deploys, releases, commits.
```
With:
```
- **User only.** Set `disable-model-invocation: true` (Claude Code; see [the Claude Code field reference](/docs/11-cross-platform/claude-code)). The skill appears in `/skills` and on `/skill-name` invocation but the agent will not auto-fire. Use for side-effecting workflows: deploys, releases, commits.
```

- [ ] **Step 2: Convert two chips on line 19**

Replace:
```
The deeper why is in `docs/02-mental-model.md` (skills vs CLAUDE.md vs hooks vs slash commands). The taxonomy is in `docs/05-authoring/frontmatter.md`.
```
With:
```
The deeper why is in [Mental model](/docs/02-mental-model) (skills vs CLAUDE.md vs hooks vs slash commands). The taxonomy is in [Frontmatter reference](/docs/05-authoring/frontmatter).
```

- [ ] **Step 3: Convert chip on line 23 (cross-repo, v2.2-pinned)**

Replace:
```
Karpathy-wiki is **agent only** (auto-trigger). The description (lines 3-12 of `karpathy-wiki/skills/karpathy-wiki/SKILL.md`) opens with "Load at the start of EVERY conversation"
```
With:
```
Karpathy-wiki is **agent only** (auto-trigger). The description ([lines 3–12 of the v2.2 karpathy-wiki SKILL.md](https://github.com/toolboxmd/karpathy-wiki/blob/4f4c00d/skills/karpathy-wiki/SKILL.md?plain=1#L3-L12)) opens with "Load at the start of EVERY conversation"
```

(SHA-pinned because the path was deleted post-v2.4-split. Verified in Task 0 Step 4.)

- [ ] **Step 4: Insert the on-ramp text after line 29**

The current line 29 ends with "what enforces the claim?". Line 30 is blank. Line 31 starts the bullet list with "- **Decoration.**".

Insert these two lines (one prose line plus a blank line) immediately after line 29 — i.e., before line 30:

```

> One-line plain-English form: *if this rule is broken, what code will notice and stop the agent?* If nothing — rewrite the rule. We shorten this question to "what fires on it?" everywhere it appears below.
```

The blockquote `>` markdown ensures the on-ramp visually pops as a definition rather than blending into surrounding prose.

After this insert, the original line 31 (the `- **Decoration.**` bullet) is now line 33.

- [ ] **Step 5: Convert chip on what is now line 36 (was 34)**

Original line 34 read:
```
The full deep dive is in `docs/07-mechanism-vs-decoration.md`. The audit method: grep your SKILL.md for "must," "always," "never," and any digits. For each hit, ask "what fires on this if violated?" If the answer is "the agent decides," wire it.
```

After Step 4's insert, this same prose now lives 2 lines down. Find it (use `grep -n "The full deep dive"`) and replace with:
```
The full deep dive is in [Mechanism vs decoration](/docs/07-mechanism-vs-decoration). The audit method: grep your SKILL.md for "must," "always," "never," and any digits. For each hit, ask "what fires on this if violated?" If the answer is "the agent decides," wire it.
```

The shorthand `"what fires on this if violated?"` stays — the on-ramp at Step 4 has already defined it.

- [ ] **Step 6: Convert two chips on the line that was line 48**

Original line 48 read:
```
The auditor named decoration vs mechanism as "the strongest signal for what v2.2-hardening should fix" (`karpathy-wiki/docs/planning/2026-04-24-karpathy-wiki-v2.2-audit.md:366`). Three wirings later, the rule's authority is evidenced; see `docs/07-mechanism-vs-decoration.md` for the full case studies.
```

Find it (use `grep -n "auditor named decoration"`) and replace with:
```
The auditor named decoration vs mechanism as "the strongest signal for what v2.2-hardening should fix" ([karpathy-wiki v2.2 audit, line 366](https://github.com/toolboxmd/karpathy-wiki/blob/4f4c00d/docs/planning/2026-04-24-karpathy-wiki-v2.2-audit.md?plain=1#L366)). Three wirings later, the rule's authority is evidenced; see [Mechanism vs decoration](/docs/07-mechanism-vs-decoration) for the full case studies.
```

The cross-repo URL is **v2.2-pinned** (the prose describes the v2.2 audit state). The original chip used IDE-style `:366` line citation; the rewrite uses `?plain=1#L366` per the line-range-anchors convention.

- [ ] **Step 7: Convert chip on the line that was line 58**

Original line 58 read:
```
The full numerical breakdown is in `docs/04-token-economics.md`, which gives you a calculator: input your SKILL.md size, your loading mechanism (description-trigger vs hook), your per-session firing rate, and you get an estimated cost.
```

Find it (`grep -n "full numerical breakdown"`) and replace with:
```
The full numerical breakdown is in [Token economics](/docs/04-token-economics), which gives you a calculator: input your SKILL.md size, your loading mechanism (description-trigger vs hook), your per-session firing rate, and you get an estimated cost.
```

- [ ] **Step 8: Convert chip on the line that was line 66**

Original line 66 ended with: `is the conscious trade-off discussed in \`docs/04-token-economics.md\`.`

Find it (`grep -n "conscious trade-off"`) and replace the chip:
```
... the conscious trade-off discussed in [Token economics](/docs/04-token-economics).
```

- [ ] **Step 9: Convert three chips on the line that was line 78**

Original line 78 read:
```
The three blocker docs in this repo (`01-quickstart.md`, `02-mental-model.md`, `04-token-economics.md`) each unblock one of the three audiences who hit one of the three failures. Read those three; then come back here.
```

Find it (`grep -n "three blocker docs in this repo"`) and replace with:
```
The three blocker docs in this repo ([01 quickstart](/docs/01-quickstart), [02 mental model](/docs/02-mental-model), [04 token economics](/docs/04-token-economics)) each unblock one of the three audiences who hit one of the three failures. Read those three; then come back here.
```

- [ ] **Step 10: Add back-reference at the top of Sources block (was line 90)**

The original `## Sources` heading was at line 90. Find it (`grep -n "^## Sources"`).

Insert a new line and a blank line immediately after the `## Sources` line, BEFORE the existing first bullet:
```

> See [Overview → Sources](/docs/00-overview#sources) for what `LANDSCAPE`, `REVIEWER`, and `LESSONS` refer to.
```

The existing source bullets (`- \`REVIEWER\`, "Stress test of the decoration vs mechanism headline,"...`) stay unchanged.

- [ ] **Step 11: Convert four chips on the cross-links line (was line 98)**

Original line 98 read:
```
Cross-links: `docs/02-mental-model.md` (Q1 deep dive), `docs/07-mechanism-vs-decoration.md` (Q2 deep dive), `docs/04-token-economics.md` (Q3 deep dive), `case-studies/2026-04-25-karpathy-wiki-v2.2.md` (the worked answers above expanded).
```

Find it (`grep -n "^Cross-links: "`) and replace with:
```
Cross-links: [Mental model](/docs/02-mental-model) (Q1 deep dive), [Mechanism vs decoration](/docs/07-mechanism-vs-decoration) (Q2 deep dive), [Token economics](/docs/04-token-economics) (Q3 deep dive), [v2.2 case study](/case-studies/2026-04-25-karpathy-wiki-v2.2) (the worked answers above expanded).
```

- [ ] **Step 12: Convert six chips on the reverse-cross-links line (was line 100)**

Original line 100 read:
```
Reverse cross-links to honor: every doc that answers one of the three questions MUST link back here. Currently linking back: `docs/00-overview.md`, `docs/02-mental-model.md`, `docs/04-token-economics.md`, `docs/07-mechanism-vs-decoration.md`, `docs/10-anti-patterns.md`, `case-studies/2026-04-25-karpathy-wiki-v2.2.md`. The README also references the three questions verbatim.
```

Find it (`grep -n "Reverse cross-links"`) and replace with:
```
Reverse cross-links to honor: every doc that answers one of the three questions MUST link back here. Currently linking back: [00 overview](/docs/00-overview), [02 mental model](/docs/02-mental-model), [04 token economics](/docs/04-token-economics), [07 mechanism vs decoration](/docs/07-mechanism-vs-decoration), [10 anti-patterns](/docs/10-anti-patterns), [v2.2 case study](/case-studies/2026-04-25-karpathy-wiki-v2.2). The README also references the three questions verbatim.
```

**Do NOT touch line 44** — the `index.md` chip there is topical (discussing a wiki's index file). Pattern C; leaves as bare backticks.

- [ ] **Step 13: Verify the file**

Run:
```bash
grep -n '/Users/' docs/03-three-questions.md
```
Expected: empty.

Run:
```bash
grep -nE '`(docs/|case-studies/|examples/|karpathy-wiki/)' docs/03-three-questions.md
```
Expected: empty (or only the rewritten lines now containing them inside `[](...)` link syntax — but not as bare backtick chips).

(No commit yet.)

---

## Task 6: Trim 09-evolution.md timing claim and convert chips

**Files:**
- Modify: `docs/09-evolution.md` (line 17, line 78, line 88)

Smallest task. One sentence deletion plus three chip conversions.

- [ ] **Step 1: Delete the "Four cycles in six months" sentence on line 17**

Original line 17 reads:
```
Cycle cadence: typically per major-version ship. Karpathy-wiki ran the cycle for v2 (Tasks 1-29), v2-hardening (Tasks 30-44), v2.1 (missed-capture patch), and v2.2 (Tasks 50-62). Four cycles in six months. Each cycle produced lessons that fed the next.
```

Replace with (deleting only the "Four cycles in six months." sentence; leaving surrounding text intact):
```
Cycle cadence: typically per major-version ship. Karpathy-wiki ran the cycle for v2 (Tasks 1-29), v2-hardening (Tasks 30-44), v2.1 (missed-capture patch), and v2.2 (Tasks 50-62). Each cycle produced lessons that fed the next.
```

- [ ] **Step 2: Convert chip on line 78**

Original line 78 read:
```
Per `docs/12-update-mechanism.md`: case studies, per-ship retrospectives, reader-submitted issues. The audit cycle is not strictly required for every contribution (a small typo fix does not need a brainstorming pass), but for non-trivial ships it is the proven pattern.
```

Replace with:
```
Per [Update mechanism](/docs/12-update-mechanism): case studies, per-ship retrospectives, reader-submitted issues. The audit cycle is not strictly required for every contribution (a small typo fix does not need a brainstorming pass), but for non-trivial ships it is the proven pattern.
```

- [ ] **Step 3: Convert two chips on line 88**

Original line 88 read:
```
Cross-links: `docs/12-update-mechanism.md`, `case-studies/2026-04-25-karpathy-wiki-v2.2.md`.
```

Replace with:
```
Cross-links: [Update mechanism](/docs/12-update-mechanism), [v2.2 case study](/case-studies/2026-04-25-karpathy-wiki-v2.2).
```

- [ ] **Step 4: Verify the file**

Run:
```bash
grep -n '/Users/' docs/09-evolution.md
grep -n "Four cycles in six months" docs/09-evolution.md
grep -nE '`(docs/|case-studies/|examples/)' docs/09-evolution.md
```
Expected: all three return empty.

(No commit yet.)

---

## Task 7: Rewrite docs/10-anti-patterns.md

**Files:**
- Modify: `docs/10-anti-patterns.md` (lines 5, 11, 17, 29, 47, 53, 59, 64, 71, 98)

One path-leak fix at line 64; nine chip conversions on the rest. Line 65 (directory reference) is intentionally left untouched.

- [ ] **Step 1: Convert chip on line 5**

Original line 5 contained:
```
For the positive form of each pattern, follow the cross-link. Many of these anti-patterns are concrete failures of the second hero question (what fires on rules?) from the three-question framework; see `docs/03-three-questions.md` for the framework that this catalog inverts.
```

Replace with:
```
For the positive form of each pattern, follow the cross-link. Many of these anti-patterns are concrete failures of the second hero question (what fires on rules?) from the three-question framework; see [Three questions](/docs/03-three-questions) for the framework that this catalog inverts.
```

- [ ] **Step 2: Convert chip on line 11**

Find:
```
- **Counter.** Every threshold or invariant must answer "what fires on it?" Wire to a script, validator, hook, or captured artifact. See `docs/07-mechanism-vs-decoration.md`.
```

Replace with:
```
- **Counter.** Every threshold or invariant must answer "what fires on it?" Wire to a script, validator, hook, or captured artifact. See [Mechanism vs decoration](/docs/07-mechanism-vs-decoration).
```

- [ ] **Step 3: Convert chip on line 17**

Find:
```
- **Counter.** Test the snippet by rehearsing the verbatim copy. Paste the bytes from SKILL.md into the test; do not retype. Add an assertion on the rendered output's first byte (e.g., `head -1 file == '---'`). See `docs/05-authoring/prose-discipline.md`.
```

Replace with:
```
- **Counter.** Test the snippet by rehearsing the verbatim copy. Paste the bytes from SKILL.md into the test; do not retype. Add an assertion on the rendered output's first byte (e.g., `head -1 file == '---'`). See [Prose discipline](/docs/05-authoring/prose-discipline).
```

- [ ] **Step 4: Convert chip on line 29 (preserving the inline command chip)**

Find:
```
- **Counter.** When a task modifies a contract, the regression-test scope is the FULL test suite (`bash tests/run-all.sh`), not the test for the immediate file. See `docs/06-testing/unit-tests.md`.
```

Replace with (note: the `bash tests/run-all.sh` chip is Pattern C — a command, not a navigational chip — and is preserved):
```
- **Counter.** When a task modifies a contract, the regression-test scope is the FULL test suite (`bash tests/run-all.sh`), not the test for the immediate file. See [Unit tests](/docs/06-testing/unit-tests).
```

- [ ] **Step 5: Convert chip on line 47**

Find:
```
- **Counter.** When modifying a script's interface, the plan's modify set should include the script's own docstring, own help string, and any READMEs that mention the interface. See `docs/06-testing/unit-tests.md`.
```

Replace with:
```
- **Counter.** When modifying a script's interface, the plan's modify set should include the script's own docstring, own help string, and any READMEs that mention the interface. See [Unit tests](/docs/06-testing/unit-tests).
```

- [ ] **Step 6: Convert chip on line 53 (preserving the `\`skill\` tool` chip)**

Find:
```
- **Counter.** Description starts with triggers ("Use when...") and lists 3-7 concrete trigger conditions. Skip the workflow summary; that lives in the body. See `docs/05-authoring/triggers.md`. (Flag: this anti-pattern is most acute on Claude Code, where the description is the primary activation signal. Other harnesses with explicit invocation, like OpenCode's `skill` tool, are less affected.)
```

Replace with (note: the `` `skill` tool `` chip is Pattern C — code reference — and is preserved):
```
- **Counter.** Description starts with triggers ("Use when...") and lists 3-7 concrete trigger conditions. Skip the workflow summary; that lives in the body. See [Triggers](/docs/05-authoring/triggers). (Flag: this anti-pattern is most acute on Claude Code, where the description is the primary activation signal. Other harnesses with explicit invocation, like OpenCode's `skill` tool, are less affected.)
```

- [ ] **Step 7: Convert chip on line 59**

Find:
```
- **Counter.** Pressure scenarios for discipline skills; verbatim-snippet tests for prose-with-snippets; `skills-ref validate` for spec compliance. See `docs/06-testing/unit-tests.md`.
```

Replace with (note: the `` `skills-ref validate` `` chip is Pattern C — command reference — and is preserved):
```
- **Counter.** Pressure scenarios for discipline skills; verbatim-snippet tests for prose-with-snippets; `skills-ref validate` for spec compliance. See [Unit tests](/docs/06-testing/unit-tests).
```

- [ ] **Step 8: Fix path leak on line 64**

This is the only path-leak fix in this file. Original line 64 ended with:
```
... See `/Users/lukaszmaj/wiki/concepts/claude-code-plugin-root-substitution.md`. (`LANDSCAPE` 4.5.)
```

Replace with:
```
... See [the plugin-root substitution wiki page](https://github.com/toolboxmd/karpathy-wiki/blob/main/wiki/concepts/claude-code-plugin-root-substitution.md). (`LANDSCAPE` 4.5.)
```

This URL only resolves because Step A (Task 1) merged. Task 2 verified resolution. The link uses `main` (not a SHA pin) because the wiki concept page is a long-lived stable artifact.

**Do NOT touch line 65** — the `docs/11-cross-platform/` chip is a directory reference, not a single-file chip.

- [ ] **Step 9: Convert chip on line 71**

Find:
```
- **Counter.** Mark "test passes immediately" tasks explicitly. State whether the test is a regression-pin or a mechanism-rehearsal, and link the relevant doc. See `docs/06-testing/tests-that-pass-immediately.md`.
```

Replace with:
```
- **Counter.** Mark "test passes immediately" tasks explicitly. State whether the test is a regression-pin or a mechanism-rehearsal, and link the relevant doc. See [Tests that pass immediately](/docs/06-testing/tests-that-pass-immediately).
```

- [ ] **Step 10: Convert seven chips on line 98**

Find:
```
Cross-links: `docs/03-three-questions.md`, `docs/07-mechanism-vs-decoration.md`, `docs/05-authoring/prose-discipline.md`, `docs/06-testing/unit-tests.md`, `docs/06-testing/tests-that-pass-immediately.md`, `docs/05-authoring/triggers.md`, `case-studies/2026-04-25-karpathy-wiki-v2.2.md`.
```

Replace with:
```
Cross-links: [Three questions](/docs/03-three-questions), [Mechanism vs decoration](/docs/07-mechanism-vs-decoration), [Prose discipline](/docs/05-authoring/prose-discipline), [Unit tests](/docs/06-testing/unit-tests), [Tests that pass immediately](/docs/06-testing/tests-that-pass-immediately), [Triggers](/docs/05-authoring/triggers), [v2.2 case study](/case-studies/2026-04-25-karpathy-wiki-v2.2).
```

- [ ] **Step 11: Verify the file**

Run:
```bash
grep -n '/Users/' docs/10-anti-patterns.md
grep -nE '`(docs/[^`]+\.md|case-studies/[^`]+\.md|examples/[^`]+\.md)' docs/10-anti-patterns.md
```
Expected: both empty (or the second only matches lines where chips appear inside `[](...)` link syntax, which this regex would not isolate — eyeball the output).

(No commit yet.)

---

## Task 8: Rewrite docs/12-update-mechanism.md

**Files:**
- Modify: `docs/12-update-mechanism.md` (lines 11, 28, 49, 72, 73, 83)

Two path-leak fixes (lines 11 and 49) plus four chip conversions. Lines 15, 42 are intentionally untouched (template path, directory reference).

- [ ] **Step 1: Fix path leak on line 11**

Original line 11 read:
```
The v2.2 lessons report (`/Users/lukaszmaj/dev/bigbrain/research/building-agentskills/2026-04-24-lessons-from-v2.2-ship.md`) is the seed instance of this format. It enumerates per-skill load-bearing analysis, patterns the existing meta-skills do not cover, the brainstorming-spec-plan-execute pipeline as gestalt, RED-GREEN-REFACTOR for prose, and case studies of reviewer-driven fix-ups. The shape is a reference for what a retrospective looks like.
```

Replace with:
```
The v2.2 lessons report — the document we cite as `LESSONS` (see [Overview → Sources](/docs/00-overview#sources)) — is the seed instance of this format. It enumerates per-skill load-bearing analysis, patterns the existing meta-skills do not cover, the brainstorming-spec-plan-execute pipeline as gestalt, RED-GREEN-REFACTOR for prose, and case studies of reviewer-driven fix-ups. The shape is a reference for what a retrospective looks like.
```

- [ ] **Step 2: Convert chip on line 28**

Original line 28 read:
```
The v2.2 case study (`case-studies/2026-04-25-karpathy-wiki-v2.2.md`) is the worked example.
```

Replace with:
```
The [v2.2 case study](/case-studies/2026-04-25-karpathy-wiki-v2.2) is the worked example.
```

(Note: the original sentence had the format "case study (path) is the worked example" — collapsing the redundant parenthetical into a clean linked-noun form is the cleaner pattern. Avoids the awkward repetition that a literal chip-substitution would produce.)

- [ ] **Step 3: Fix path leak on line 49**

Original line 49 read:
```
The v2.2 ship's landscape report (`/Users/lukaszmaj/dev/bigbrain/research/building-agentskills/2026-04-24-skill-authoring-landscape-2026.md`) is the seed instance. It enumerates state of the art, who is writing skill-authoring guides, the harness landscape, anatomy of a "good" skill, anti-patterns observed in the wild, the quality bar for 2026, source catalog.
```

Replace with:
```
The v2.2 ship's landscape report — `LANDSCAPE` in our citations (see [Overview → Sources](/docs/00-overview#sources)) — is the seed instance. It enumerates state of the art, who is writing skill-authoring guides, the harness landscape, anatomy of a "good" skill, anti-patterns observed in the wild, the quality bar for 2026, source catalog.
```

- [ ] **Step 4: Convert chip on line 72 (cross-repo, GitHub-rendered)**

Original line 72 read:
```
- The loader skill (`skills/building-agentskills/SKILL.md`).
```

Replace with (note: `skills/` is NOT in `docs.json`'s navigation tree, so the file is GitHub-rendered, not Mintlify-rendered — use absolute GitHub URL):
```
- [The loader skill](https://github.com/toolboxmd/building-agentskills/blob/main/skills/building-agentskills/SKILL.md).
```

- [ ] **Step 5: Convert chip on line 73 (Mintlify-rendered)**

Original line 73 read:
```
- The example skill (`examples/minimal-skill/SKILL.md`).
```

Replace with (`examples/minimal-skill/SKILL` IS in `docs.json:79`, so it's Mintlify-rendered):
```
- [The minimal example skill](/examples/minimal-skill/SKILL).
```

- [ ] **Step 6: Convert chip on line 83**

Original line 83 read:
```
Cross-links: `case-studies/2026-04-25-karpathy-wiki-v2.2.md`.
```

Replace with:
```
Cross-links: [v2.2 case study](/case-studies/2026-04-25-karpathy-wiki-v2.2).
```

**Do NOT touch line 15** (template path with angle brackets, Pattern C) **or line 42** (directory reference).

- [ ] **Step 7: Verify the file**

Run:
```bash
grep -n '/Users/' docs/12-update-mechanism.md
```
Expected: empty.

(No commit yet.)

---

## Task 9: Rewrite docs/08-packaging-as-plugin.md

**Files:**
- Modify: `docs/08-packaging-as-plugin.md` (lines 47, 56, 69, 77)

One path-leak fix (line 77) plus three chip conversions. Lines 5, 105, 108, 117 intentionally untouched.

- [ ] **Step 1: Convert chip on line 47**

Find:
```
The `version` follows semantic versioning. Note: a description-string change in your skills can break implicit triggering (the description is the activation contract); a description change is conceptually a major-version shift even if the body is unchanged. See `docs/09-evolution.md`.
```

Replace with:
```
The `version` follows semantic versioning. Note: a description-string change in your skills can break implicit triggering (the description is the activation contract); a description change is conceptually a major-version shift even if the body is unchanged. See [Evolution](/docs/09-evolution).
```

- [ ] **Step 2: Convert chip on line 56**

Find:
```
- **`references/`.** Heavy reference docs loaded on demand. One level deep from SKILL.md; never nested. See `docs/05-authoring/line-budget.md`.
```

Replace with:
```
- **`references/`.** Heavy reference docs loaded on demand. One level deep from SKILL.md; never nested. See [Line budget](/docs/05-authoring/line-budget).
```

- [ ] **Step 3: Convert two chips on line 69**

Find:
```
Per-scope priority for Claude Code skills (per `docs/04-token-economics.md` and `docs/11-cross-platform/claude-code.md`):
```

Replace with:
```
Per-scope priority for Claude Code skills (per [Token economics](/docs/04-token-economics) and [Claude Code cross-platform notes](/docs/11-cross-platform/claude-code)):
```

- [ ] **Step 4: Fix path leak on line 77**

Original line 77 read:
```
Source: `REVIEWER` G3, "wiki concept page references" (`/Users/lukaszmaj/wiki/concepts/claude-code-plugin-root-substitution.md`).
```

Replace with:
```
Source: `REVIEWER` G3, "wiki concept page references" ([wiki concept page](https://github.com/toolboxmd/karpathy-wiki/blob/main/wiki/concepts/claude-code-plugin-root-substitution.md)).
```

**Do NOT touch lines 5, 105, 108, 117** — directory references and topical chips.

- [ ] **Step 5: Verify the file**

Run:
```bash
grep -n '/Users/' docs/08-packaging-as-plugin.md
```
Expected: empty.

(No commit yet.)

---

## Task 10: Rewrite docs/11-cross-platform/claude-code.md

**Files:**
- Modify: `docs/11-cross-platform/claude-code.md` (lines 40, 52, 74, 88, 98)

One path-leak fix (line 40) plus four chip conversions.

- [ ] **Step 1: Fix path leak on line 40**

Original line 40 read:
```
Source: `REVIEWER` G3; `/Users/lukaszmaj/wiki/concepts/claude-code-plugin-root-substitution.md`.
```

Replace with:
```
Source: `REVIEWER` G3; [plugin-root substitution wiki page](https://github.com/toolboxmd/karpathy-wiki/blob/main/wiki/concepts/claude-code-plugin-root-substitution.md).
```

- [ ] **Step 2: Convert chip on line 52**

Find:
```
See `docs/08-packaging-as-plugin.md` for the full discussion.
```

Replace with:
```
See [Packaging as a plugin](/docs/08-packaging-as-plugin) for the full discussion.
```

- [ ] **Step 3: Convert chip on line 74**

Find:
```
This taxonomy is the foundational design question for any new skill (Question 1 of the hero framework, `docs/03-three-questions.md`). Decide explicitly; do not let the defaults answer for you.
```

Replace with:
```
This taxonomy is the foundational design question for any new skill (Question 1 of the hero framework, [Three questions](/docs/03-three-questions)). Decide explicitly; do not let the defaults answer for you.
```

- [ ] **Step 4: Convert two chips on line 88**

Find:
```
See `docs/05-authoring/frontmatter.md` for the field reference; `docs/07-mechanism-vs-decoration.md` for the broader pattern.
```

Replace with:
```
See [Frontmatter reference](/docs/05-authoring/frontmatter) for the field reference; [Mechanism vs decoration](/docs/07-mechanism-vs-decoration) for the broader pattern.
```

- [ ] **Step 5: Convert two chips on line 98**

Find:
```
Cross-links: `docs/04-token-economics.md` (the SessionStart-hook injection cost), `docs/08-packaging-as-plugin.md` (the plugin manifest and the substitution gotcha).
```

Replace with:
```
Cross-links: [Token economics](/docs/04-token-economics) (the SessionStart-hook injection cost), [Packaging as a plugin](/docs/08-packaging-as-plugin) (the plugin manifest and the substitution gotcha).
```

- [ ] **Step 6: Verify the file**

Run:
```bash
grep -n '/Users/' docs/11-cross-platform/claude-code.md
```
Expected: empty.

(No commit yet.)

---

## Task 11: Rewrite case-studies/2026-04-25-karpathy-wiki-v2.2.md

**Files:**
- Modify: `case-studies/2026-04-25-karpathy-wiki-v2.2.md` (lines 12, 33, 37, 63, 75, 81, 87, 93, 109, 118, 124–130, 134, 153–159)

Two path-leak fixes (lines 12 and 33) plus many chip conversions. Lines 10, 45, 165 intentionally untouched.

- [ ] **Step 1: Fix path leak on line 12**

Original line 12 read:
```
The full retrospective lives in `LESSONS` (`/Users/lukaszmaj/dev/bigbrain/research/building-agentskills/2026-04-24-lessons-from-v2.2-ship.md`). This case study is the public-audience version, written for readers who landed here from a search.
```

Replace with:
```
The full retrospective lives in the document we cite as `LESSONS` (see [Overview → Sources](/docs/00-overview#sources)). This case study is the public-audience version, written for readers who landed here from a search.
```

- [ ] **Step 2: Fix path leak + anchor format on line 33 (v2.2-pinned URL)**

Original line 33 read:
```
The architectural decision is documented in the v2.2 spec doc (`/Users/lukaszmaj/dev/toolboxmd/karpathy-wiki/docs/superpowers/specs/2026-04-24-karpathy-wiki-v2.2-design.md:30-65`) with an explicit "Architectural decision: kill `sources/`" section and a job-vs-replacement table. Without brainstorming, v2.2 would have shipped 7+ patches plus 31 stub-improvement passes; instead it shipped one architectural cut + 5 mechanism-wirings.
```

Replace with (SHA-pinned because the prose describes the v2.2-tip state of the spec doc; `?plain=1#L30-L65` is the correct GitHub anchor format, not `:30-65`):
```
The architectural decision is documented in the [v2.2 spec doc, lines 30–65](https://github.com/toolboxmd/karpathy-wiki/blob/4f4c00d/docs/superpowers/specs/2026-04-24-karpathy-wiki-v2.2-design.md?plain=1#L30-L65), with an explicit "Architectural decision: kill `sources/`" section and a job-vs-replacement table. Without brainstorming, v2.2 would have shipped 7+ patches plus 31 stub-improvement passes; instead it shipped one architectural cut + 5 mechanism-wirings.
```

- [ ] **Step 3: Convert chip on line 37**

Find:
```
For your own skills: when an audit lists multiple findings that share a category, ask whether the category itself is the right abstraction. If the answer is no, the brainstorming output is "delete the category" rather than "fix each finding." See `docs/02-mental-model.md` for the broader frame.
```

Replace with:
```
For your own skills: when an audit lists multiple findings that share a category, ask whether the category itself is the right abstraction. If the answer is no, the brainstorming output is "delete the category" rather than "fix each finding." See [Mental model](/docs/02-mental-model) for the broader frame.
```

- [ ] **Step 4: Convert chip on line 63**

Find:
```
This is honest evidence that the decoration-vs-mechanism rule is a spectrum. Sometimes you wire fully; sometimes you wire partially. See `docs/07-mechanism-vs-decoration.md`.
```

Replace with:
```
This is honest evidence that the decoration-vs-mechanism rule is a spectrum. Sometimes you wire fully; sometimes you wire partially. See [Mechanism vs decoration](/docs/07-mechanism-vs-decoration).
```

- [ ] **Step 5: Convert chip on line 75**

Find:
```
Lesson for the building-agentskills repo: contract-touching changes default to the full test suite scope. See `docs/06-testing/unit-tests.md`.
```

Replace with:
```
Lesson for the building-agentskills repo: contract-touching changes default to the full test suite scope. See [Unit tests](/docs/06-testing/unit-tests).
```

- [ ] **Step 6: Convert chip on line 81**

Find:
```
Lesson: prose-deletion tasks need to enumerate ALL related patterns. See `docs/06-testing/red-green-for-prose.md`.
```

Replace with:
```
Lesson: prose-deletion tasks need to enumerate ALL related patterns. See [Red-green for prose](/docs/06-testing/red-green-for-prose).
```

- [ ] **Step 7: Convert chip on line 87**

Find:
```
Lesson: when modifying a script's interface, the plan's modify set should include the script's own docstring, help string, and any READMEs that mention the interface. See `docs/10-anti-patterns.md`.
```

Replace with:
```
Lesson: when modifying a script's interface, the plan's modify set should include the script's own docstring, help string, and any READMEs that mention the interface. See [Anti-patterns](/docs/10-anti-patterns).
```

- [ ] **Step 8: Convert chip on line 93**

Find:
```
Lesson: snippets in SKILL.md prose are production code when a headless subprocess executes them. See `docs/05-authoring/prose-discipline.md`.
```

Replace with:
```
Lesson: snippets in SKILL.md prose are production code when a headless subprocess executes them. See [Prose discipline](/docs/05-authoring/prose-discipline).
```

- [ ] **Step 9: Convert two chips on line 109 (one cross-repo, one in-repo)**

Find:
```
These are Layer 2 patterns from `obra/superpowers`. We did not invent them; we applied them and they worked. See `docs/00-overview.md` for the layer distinction.
```

Replace with (cross-repo `obra/superpowers` becomes a GitHub URL; the in-repo chip becomes a Mintlify link):
```
These are Layer 2 patterns from [obra/superpowers](https://github.com/obra/superpowers). We did not invent them; we applied them and they worked. See [00 overview](/docs/00-overview) for the layer distinction.
```

- [ ] **Step 10: Convert chip on line 118**

Find:
```
Each of these surfaces a pattern the existing canon does not cover, documented in `docs/10-anti-patterns.md`.
```

Replace with:
```
Each of these surfaces a pattern the existing canon does not cover, documented in [Anti-patterns](/docs/10-anti-patterns).
```

- [ ] **Step 11: Convert seven chips in the bullet block on lines 124–130**

These seven bullets all end with "See `docs/<...>.md`." Convert each. Find each bullet by its leading text (the bold pattern label) and replace its trailing chip:

- Line 124: `... documented in [Mechanism vs decoration](/docs/07-mechanism-vs-decoration).`
- Line 125: `... See [Prose discipline](/docs/05-authoring/prose-discipline).`
- Line 126: `... See [Tests that pass immediately](/docs/06-testing/tests-that-pass-immediately).`
- Line 127: `... See [Anti-patterns](/docs/10-anti-patterns).` (Note: the in-prose chip `` `subagent-driven-development` `` on this line is Pattern C — code reference — and is preserved.)
- Line 128: `... See [Unit tests](/docs/06-testing/unit-tests).`
- Line 129: `... See [Anti-patterns](/docs/10-anti-patterns).`
- Line 130: `... See [Evolution](/docs/09-evolution).`

- [ ] **Step 12: Convert cross-repo chip on line 134**

Original line 134 read:
```
The v2.2 ship was good but not perfect. Two known imperfections shipped, documented in `karpathy-wiki/TODO.md` with `status: open / labels: [known-imperfection]`:
```

Replace with (using `main`, NOT `4f4c00d`, because the prose is about the *current* state of TODO.md — readers want to see whether items are still open or have been resolved):
```
The v2.2 ship was good but not perfect. Two known imperfections shipped, documented in [karpathy-wiki TODO.md](https://github.com/toolboxmd/karpathy-wiki/blob/main/TODO.md) with `status: open / labels: [known-imperfection]`:
```

- [ ] **Step 13: Convert seven chips in the cross-links list on lines 153–159**

This is the `## Cross-links` section. Each line is a bullet of the form `- \`docs/X.md\` (description)`. Convert each:

- Line 153: `- [Three questions](/docs/03-three-questions) (the hero framework; karpathy-wiki's worked answers expanded)`
- Line 154: `- [Mechanism vs decoration](/docs/07-mechanism-vs-decoration) (the three v2.2 wirings in detail)`
- Line 155: `- [Prose discipline](/docs/05-authoring/prose-discipline) (the Task 56 heredoc bugs)`
- Line 156: `- [Update mechanism](/docs/12-update-mechanism) (per-ship retrospective format)`
- Line 157: `- [Anti-patterns](/docs/10-anti-patterns) (every fix-up commit corresponds to an anti-pattern)`
- Line 158: `- [Mental model](/docs/02-mental-model) (when a skill is the right primitive at all; karpathy-wiki is auto-trigger by design)`
- Line 159: `- [Evolution](/docs/09-evolution) (reviewer fix-up rate at 26.3% is healthy)`

**Do NOT touch line 10** (`toolboxmd/building-agentskills` repo-name reference, Pattern C), **line 45** (`index.md` topical, Pattern C), or **line 165** (`skills/pdf` topic reference, Pattern C).

- [ ] **Step 14: Verify the file**

Run:
```bash
grep -n '/Users/' case-studies/2026-04-25-karpathy-wiki-v2.2.md
grep -n ':30-65' case-studies/2026-04-25-karpathy-wiki-v2.2.md
```
Expected: both empty (no path leaks; the IDE-style `:30-65` anchor is gone).

(No commit yet.)

---

## Task 12: Implement scripts/check-no-bare-paths.sh

**Files:**
- Create: `scripts/check-no-bare-paths.sh`

The helper script the bare-paths gate calls. Per the spec, it greps for `.md(:[0-9]+(-[0-9]+)?)?` chips wrapped in backticks; classifies as either inside a Markdown link (allowed), allowlisted topical (allowed), or violating (flagged).

This script is exercised by `tests/check-no-bare-paths.test.sh` (Task 13). Build the script first, then build the test, then iterate until both pass.

- [ ] **Step 1: TDD inversion note**

This task creates the script implementation; Task 13 creates its self-test fixtures. We do this in inverted order because the test's argument-handling shape is documented in the spec (`bash check-no-bare-paths.sh path1 path2 ...`), so writing the script first does not violate "test first" — the test contract is fixed by the spec. Task 13 verifies the script's actual behavior against fixtures; if any fixture fails, iterate on Task 12's script (this is the GREEN phase from the test's perspective). See `docs/06-testing/tests-that-pass-immediately.md` (the "mechanism rehearsal" pattern) for the legitimate TDD inversion this represents.

- [ ] **Step 2: Write the script**

Create `scripts/check-no-bare-paths.sh` with this content:
```bash
#!/usr/bin/env bash
# Check for bare backtick-wrapped path chips (`docs/X.md`) that should be Markdown links.
#
# Default scope: docs/, case-studies/, examples/, README.md (excluding docs/superpowers/specs/).
# Argument mode: takes one or more paths and greps only those.
#
# A chip is flagged unless:
#   - It appears inside Markdown link syntax: [...`<chip>`...](...) or [...](.../`<chip>`...).
#   - Its payload matches the allowlist of known-topical filenames.
#
# Out of scope (NOT flagged):
#   - Non-.md filename chips (.sh, .py, .json, etc.) — implicitly Pattern C topical.
#   - GitHub-form #L<n> anchors appended to chips — known regex gap; rely on review.
#   - Reference-style links and multi-line links — known false-positive shapes; add to allowlist if encountered.
#
# Exit codes:
#   0 — no violations.
#   1 — one or more violations; emit file:line:violation lines on stdout.

set -euo pipefail

# Allowlist: backtick-payload exact-match strings that are always topical references, never navigational.
ALLOWLIST=(
  "SKILL.md"
  "plugin.json"
  "hooks.json"
  "marketplace.json"
  ".claude-plugin/plugin.json"
  "index.md"
  "GEMINI.md"
  "LICENSE"
)

# Determine scan paths.
if [[ $# -gt 0 ]]; then
  scan_paths=("$@")
else
  scan_paths=("docs" "case-studies" "examples" "README.md")
fi

# Build grep exclusion args (only relevant for the default tree scan).
grep_exclude_args=(--exclude-dir=superpowers)

# The chip regex: backtick-wrapped path ending in .md, optionally followed by :<line> or :<start>-<end>.
# Captures both `docs/X.md` and `docs/X.md:48` and `docs/X.md:30-65`.
chip_regex='`[A-Za-z0-9._/-]+\.md(:[0-9]+(-[0-9]+)?)?`'

violations_found=0

while IFS= read -r match; do
  [[ -z "$match" ]] && continue

  # match is like: docs/file.md:42:...the matched line content...
  file=$(echo "$match" | cut -d: -f1)
  lineno=$(echo "$match" | cut -d: -f2)
  line_content=$(echo "$match" | cut -d: -f3-)

  # Extract the chip payload (without surrounding backticks).
  chip=$(echo "$line_content" | grep -oE "$chip_regex" | head -1 | sed 's/^`//; s/`$//')

  # Strip optional :<line> or :<line>-<line> suffix to get the bare filename for allowlist comparison.
  chip_payload=$(echo "$chip" | sed -E 's/:[0-9]+(-[0-9]+)?$//')

  # Check allowlist (exact-match against payload).
  is_allowlisted=0
  for allowed in "${ALLOWLIST[@]}"; do
    if [[ "$chip_payload" == "$allowed" ]]; then
      is_allowlisted=1
      break
    fi
  done
  if [[ $is_allowlisted -eq 1 ]]; then
    continue
  fi

  # Check if the chip appears inside Markdown link syntax on the same line.
  # Heuristic: the chip's backticks fall inside a [...](...)  block.
  # Two valid forms:
  #   [...`chip`...](...)    — chip in link text
  #   [...](.../`chip`...)   — chip in link target (rare but valid)
  # Implementation: a line that contains both `]` and `(` adjacent to the chip is treated as a link.
  if echo "$line_content" | grep -qE '\[[^]]*`[A-Za-z0-9._/-]+\.md(:[0-9]+(-[0-9]+)?)?`[^]]*\]\([^)]*\)'; then
    continue
  fi
  if echo "$line_content" | grep -qE '\[[^]]+\]\([^)]*`[A-Za-z0-9._/-]+\.md(:[0-9]+(-[0-9]+)?)?`[^)]*\)'; then
    continue
  fi

  # Not allowlisted, not inside a link — violation.
  echo "${file}:${lineno}: bare chip \`${chip}\` outside link syntax: ${line_content}"
  violations_found=1
done < <(grep -rnE "$chip_regex" "${grep_exclude_args[@]}" "${scan_paths[@]}" 2>/dev/null || true)

if [[ $violations_found -eq 1 ]]; then
  exit 1
fi

exit 0
```

- [ ] **Step 3: Make the script executable**

Run:
```bash
chmod +x scripts/check-no-bare-paths.sh
```

- [ ] **Step 4: Spot-check by running it against the live tree**

Run:
```bash
bash scripts/check-no-bare-paths.sh
```

Expected: exit 0 (the prior tasks 4–11 should have left no bare-chip violations in the docs/case-studies tree).

If the script reports violations, investigate each one. They are either:
- A bare chip the prior tasks missed (fix it; do not edit the script).
- A false positive of the heuristic (add to the allowlist if topical; document in the script's `Out of scope` comment if a known regex gap).

- [ ] **Step 5: Spot-check by running it on README.md**

Run:
```bash
bash scripts/check-no-bare-paths.sh README.md
```

Expected: README.md is GitHub-rendered and uses GitHub-relative `[text](docs/X.md)` form. Most of its links should be detected by the heuristic as inside link syntax. **However**, the chip-detection regex looks for backtick-wrapped chips. README.md uses `[`docs/X.md`](docs/X.md)` form — backticks inside link text. The script's link-detection heuristic should pass these. Verify.

If the script flags README.md lines, the heuristic needs tuning. The simplest fix: ensure the link-text-form regex matches README's actual prose. If it doesn't, the test in Task 13 will catch it via fixture #2; this is also the realistic shape of the linked-chip case.

(No commit yet. The script is staged but uncommitted; it'll go in the unified commit at Task 14.)

---

## Task 13: Implement the two CI gate test files

**Files:**
- Create: `tests/check-no-absolute-paths.test.sh`
- Create: `tests/check-no-bare-paths.test.sh`

These are picked up automatically by `tests/run-all.sh` (which globs `*.test.sh`).

- [ ] **Step 1: Verify the existing test harness convention**

Run:
```bash
cat tests/run-all.sh
ls tests/*.test.sh
```

Confirm that `run-all.sh` is a `*.test.sh` dispatcher (each test file is self-contained, exits 0 on pass and non-zero on fail).

- [ ] **Step 2: Create `tests/check-no-absolute-paths.test.sh`**

Create the file with this content:
```bash
#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$here/.." && pwd)"
cd "$repo_root"

# Scope: published doc surface only. Excludes docs/superpowers/specs/ (unpublished design docs).
violations=$(grep -rn '/Users/' docs/ case-studies/ examples/ README.md \
  --exclude-dir=superpowers \
  2>/dev/null || true)

if [[ -n "$violations" ]]; then
  echo "FAIL: absolute /Users/ paths found in published docs:"
  echo "$violations"
  exit 1
fi

echo "PASS: no absolute paths in published docs"
```

- [ ] **Step 3: Make it executable and spot-test**

Run:
```bash
chmod +x tests/check-no-absolute-paths.test.sh
bash tests/check-no-absolute-paths.test.sh
```

Expected: `PASS: no absolute paths in published docs` and exit 0.

- [ ] **Step 4: Inject a temporary violation and confirm the test fails**

Run:
```bash
# Inject a violation in a known-safe location.
echo "" >> docs/00-overview.md
echo "TEMP-LEAK: /Users/test/file.md" >> docs/00-overview.md

# Run the test — expect failure.
if bash tests/check-no-absolute-paths.test.sh; then
  echo "BUG: gate did not catch the injected leak" >&2
  # Revert injection before halting.
  git checkout -- docs/00-overview.md
  exit 1
else
  echo "GOOD: gate caught the injected leak"
fi

# Revert the injection.
git checkout -- docs/00-overview.md

# Re-run to confirm clean state restored.
bash tests/check-no-absolute-paths.test.sh
```

Expected: the gate caught the injected leak (exit non-zero), then after revert it passes again.

- [ ] **Step 5: Create `tests/check-no-bare-paths.test.sh`**

Create the file with this content:
```bash
#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$here/.." && pwd)"
cd "$repo_root"

# Run the gate against the live tree.
if ! bash scripts/check-no-bare-paths.sh; then
  echo "FAIL: bare backtick path chips found"
  exit 1
fi

# Self-test the gate against fixtures: it must flag bare chips, allow linked chips, and allow allowlisted topical mentions.
fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT

# Fixture 1: bare chip — should be flagged.
echo 'See `docs/03-three-questions.md` for details.' > "$fixture_dir/bare.md"

# Fixture 2: linked chip — should be allowed.
# IMPORTANT: this fixture MUST contain a backtick-wrapped chip *inside* link
# syntax. A plain Markdown link without a backticked path is NOT a valid test
# of the link-detection logic — the script's grep would find zero chips and
# return 0 by absence rather than by correctly recognizing the link context.
# Per the Pattern A rule, the chip lives as link-text inside [..](..).
echo 'See [`docs/03-three-questions.md`](/docs/03-three-questions) for details.' > "$fixture_dir/linked.md"

# Fixture 3: topical mention (allowlisted) — should be allowed.
echo 'Your `SKILL.md` should be under 500 lines.' > "$fixture_dir/topical.md"

# Fixture 4: chip with single-line suffix (e.g. `something.md:366`) — should be flagged.
echo 'See `docs/03-three-questions.md:48` for the audit reference.' > "$fixture_dir/bare-with-line.md"

# Fixture 5: chip with line-range suffix (e.g. `something.md:30-65`) — should be flagged.
echo 'See `docs/03-three-questions.md:30-65` for the architectural decision.' > "$fixture_dir/bare-with-range.md"

# Self-test mode: the script accepts a path argument for fixture-mode testing.
if bash scripts/check-no-bare-paths.sh "$fixture_dir/linked.md"; then
  echo "PASS: linked chip not flagged"
else
  echo "FAIL: linked chip incorrectly flagged"; exit 1
fi

if bash scripts/check-no-bare-paths.sh "$fixture_dir/topical.md"; then
  echo "PASS: topical mention not flagged"
else
  echo "FAIL: topical mention incorrectly flagged"; exit 1
fi

if ! bash scripts/check-no-bare-paths.sh "$fixture_dir/bare.md"; then
  echo "PASS: bare chip flagged"
else
  echo "FAIL: bare chip not flagged"; exit 1
fi

if ! bash scripts/check-no-bare-paths.sh "$fixture_dir/bare-with-line.md"; then
  echo "PASS: bare chip with single-line suffix flagged"
else
  echo "FAIL: bare chip with single-line suffix not flagged (gate missed .md:<line> pattern)"; exit 1
fi

if ! bash scripts/check-no-bare-paths.sh "$fixture_dir/bare-with-range.md"; then
  echo "PASS: bare chip with line-range suffix flagged"
else
  echo "FAIL: bare chip with line-range suffix not flagged (gate missed .md:<start>-<end> pattern)"; exit 1
fi

echo "PASS: all bare-paths gate fixtures verified"
```

- [ ] **Step 6: Make it executable and run it**

Run:
```bash
chmod +x tests/check-no-bare-paths.test.sh
bash tests/check-no-bare-paths.test.sh
```

Expected: all six PASS lines (the live-tree pass plus the five fixtures), then `PASS: all bare-paths gate fixtures verified`, exit 0.

If any FAIL line appears:
- "linked chip incorrectly flagged" — script's link-detection heuristic is wrong; debug Task 12 Step 2.
- "topical mention incorrectly flagged" — allowlist is missing `SKILL.md` (it shouldn't be, but verify).
- "bare chip not flagged" — script isn't detecting chips at all; check the chip_regex.
- "bare chip with single-line suffix not flagged" — chip_regex is missing the `(:[0-9]+...)?` group.
- "bare chip with line-range suffix not flagged" — chip_regex is missing the `(-[0-9]+)?` inner group.

Iterate on `scripts/check-no-bare-paths.sh` until all five fixtures pass.

- [ ] **Step 7: Run the full test suite**

Run:
```bash
bash tests/run-all.sh
```

Expected: all four `*.test.sh` files pass (the two existing — `build-llms.test.sh` and `check-llms-coverage.test.sh` — plus the two new ones).

(No commit yet.)

---

## Task 14: Single commit for Step B + Step C

**Files:** all the modified docs from Tasks 4–11, plus the three new files from Tasks 12 and 13.

The diff-scope rule: only files in the per-task tables. No reformatting, no surprises.

- [ ] **Step 1: Run the diff-scope sanity check**

Run:
```bash
git status --short
git diff --stat
```

Expected `git status` output (modified, plus new):
```
 M docs/00-overview.md
 M docs/03-three-questions.md
 M docs/08-packaging-as-plugin.md
 M docs/09-evolution.md
 M docs/10-anti-patterns.md
 M docs/11-cross-platform/claude-code.md
 M docs/12-update-mechanism.md
 M case-studies/2026-04-25-karpathy-wiki-v2.2.md
?? scripts/check-no-bare-paths.sh
?? tests/check-no-absolute-paths.test.sh
?? tests/check-no-bare-paths.test.sh
```

If anything else appears in `git status` (e.g., README.md modified, an unrelated file changed, a stray reformat), halt and investigate. Either revert the unintended change or document it as a DONE_WITH_CONCERNS in the PR description. Do not commit drift.

- [ ] **Step 2: Run the full test suite from a clean state**

Run:
```bash
bash tests/run-all.sh
```

Expected: all four test files pass.

- [ ] **Step 3: Stage all changes**

Run:
```bash
git add docs/00-overview.md \
        docs/03-three-questions.md \
        docs/08-packaging-as-plugin.md \
        docs/09-evolution.md \
        docs/10-anti-patterns.md \
        docs/11-cross-platform/claude-code.md \
        docs/12-update-mechanism.md \
        case-studies/2026-04-25-karpathy-wiki-v2.2.md \
        scripts/check-no-bare-paths.sh \
        tests/check-no-absolute-paths.test.sh \
        tests/check-no-bare-paths.test.sh
git status --short
```

Expected: all eleven files in the staged column.

- [ ] **Step 4: Create the commit**

Run:
```bash
git commit -m "$(cat <<'EOF'
fix(docs): hotfix path leaks, link rewrites, sources glossary, fires-on-this onramp

Strips nine /Users/ private path leaks across six files. Converts ~50
bare-backtick path "chips" into real Markdown links across all docs and
case studies. Adds a sources-labels glossary (LANDSCAPE / REVIEWER /
LESSONS) to docs/00-overview.md so first-time readers know what those
nicknames refer to. Rewrites the "what fires on this if violated?"
shorthand with a plain-English on-ramp the first time it appears in
docs/03-three-questions.md, then keeps the shorthand for subsequent
uses. Trims the inaccurate "Four cycles in six months" timing claim
from docs/09-evolution.md without committing to a duration. Fixes the
v2.2 spec-doc citation's anchor format from IDE-style :30-65 to the
GitHub-correct ?plain=1#L30-L65.

Cross-repo links: stable artifacts use /blob/main/, v2.2-historical
artifacts use /blob/4f4c00d/ (the v2.2 tip per the case study).

Adds two CI gates (tests/check-no-absolute-paths.test.sh and
tests/check-no-bare-paths.test.sh, plus the helper scripts/check-no-bare-paths.sh)
to prevent regressions: future contributors can't accidentally paste a
/Users/ path or write a bare-backtick chip that should be a Markdown
link without the gate flagging it. The bare-paths gate ships with five
fixture self-tests (bare, linked, topical-allowlisted, bare-with-line,
bare-with-range) that run on every test invocation.

Companion PR (toolboxmd/karpathy-wiki, merged before this opens):
seeded wiki/concepts/claude-code-plugin-root-substitution.md so three
docs in this repo can link to it.

Spec: docs/superpowers/specs/2026-05-06-docs-hotfix-paths-and-links-design.md
Plan: docs/superpowers/plans/2026-05-06-docs-hotfix-paths-and-links.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 5: Verify the commit**

Run:
```bash
git log --oneline -1
git diff HEAD~1 --stat
```

Expected: commit message starts with `fix(docs): hotfix path leaks, ...`. Stat output shows the eleven staged files.

---

## Task 15: Open Step B's PR

**Files:** none (PR creation only)

- [ ] **Step 1: Run all gates one more time**

Run:
```bash
bash tests/run-all.sh
```

Expected: all pass.

- [ ] **Step 2: Push the branch**

Run:
```bash
git push -u origin docs-hotfix-paths-and-links
```

- [ ] **Step 3: Open the PR**

Run:
```bash
gh pr create --title "fix(docs): hotfix path leaks, link rewrites, sources glossary, fires-on-this onramp" --body "$(cat <<'EOF'
## Summary

Strips private path leaks, converts bare-backtick path "chips" into real Markdown links, adds a sources-labels glossary, rewrites the "what fires on this if violated?" jargon for first-time readers, trims an inaccurate timing claim, and adds two CI gates to prevent regressions.

Companion PR: [toolboxmd/karpathy-wiki — seed wiki/concepts](https://github.com/toolboxmd/karpathy-wiki/pulls?q=is%3Apr+seed-wiki-concepts) (merged; required preflight for this PR's external links to resolve).

## Test plan

- [ ] `bash tests/run-all.sh` passes (four `*.test.sh` files: existing build-llms and check-llms-coverage, plus new check-no-absolute-paths and check-no-bare-paths).
- [ ] `! grep -rn '/Users/' docs/ case-studies/ examples/ README.md --exclude-dir=superpowers` returns no matches.
- [ ] Visual walkthrough on `localhost:3000` (Mintlify dev server): /docs/00-overview, /docs/03-three-questions, /docs/09-evolution, /docs/10-anti-patterns, /docs/12-update-mechanism, /docs/08-packaging-as-plugin, /docs/11-cross-platform/claude-code, /case-studies/2026-04-25-karpathy-wiki-v2.2 — every rewritten link clicks through to its target.
- [ ] All cross-repo karpathy-wiki links return HTTP/2 200 against `main` and `4f4c00d`.

## Spec and plan

- Spec: `docs/superpowers/specs/2026-05-06-docs-hotfix-paths-and-links-design.md`
- Plan: `docs/superpowers/plans/2026-05-06-docs-hotfix-paths-and-links.md`
- Reviewer convergence: Opus + Codex independent passes on v1.0, v1.1, v1.2; v1.3 cleans up minor findings before plan.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

If during implementation any DONE_WITH_CONCERNS notes accumulated, append them to the PR description under a `## Implementer concerns` heading before merging. Do NOT include them in the commit message.

---

## Task 16: Verification on the deployed site

**Files:** none (verification only; runs after Step B's PR merges)

- [ ] **Step 1: Wait for Mintlify deployment**

After merge, the Mintlify auto-deploy typically takes 1–3 minutes. Watch the deployment status (Mintlify dashboard or wait a few minutes).

- [ ] **Step 2: Verify path leaks are gone on the live site**

Run:
```bash
curl -s https://building-agentskills.toolbox.md/docs/00-overview | grep -c '/Users/'
curl -s https://building-agentskills.toolbox.md/docs/12-update-mechanism | grep -c '/Users/'
curl -s https://building-agentskills.toolbox.md/case-studies/2026-04-25-karpathy-wiki-v2.2 | grep -c '/Users/'
```
Expected: each command returns `0`.

- [ ] **Step 3: Visual walkthrough of the changed pages**

Open in a browser and click through:
- `/docs/00-overview` — confirm Sources block reads cleanly and shows the LANDSCAPE/REVIEWER/LESSONS glossary; click each rewritten link.
- `/docs/03-three-questions` — confirm the "fires on it" on-ramp blockquote appears between the Q2 intro paragraph and the bullets; the back-reference to Sources renders.
- `/docs/09-evolution` — confirm the "Four cycles in six months." sentence is gone.
- `/docs/10-anti-patterns` — click the "plugin-root substitution wiki page" link; confirm it lands on github.com.
- `/case-studies/2026-04-25-karpathy-wiki-v2.2` — click the "v2.2 spec doc, lines 30–65" link; confirm GitHub renders the file with line numbers and highlights lines 30–65.

- [ ] **Step 4: Verify cross-repo links return 200**

Run:
```bash
for url in \
  "https://github.com/toolboxmd/karpathy-wiki/blob/main/wiki/concepts/claude-code-plugin-root-substitution.md" \
  "https://github.com/toolboxmd/karpathy-wiki/blob/4f4c00d/skills/karpathy-wiki/SKILL.md" \
  "https://github.com/toolboxmd/karpathy-wiki/blob/4f4c00d/docs/superpowers/specs/2026-04-24-karpathy-wiki-v2.2-design.md" \
  "https://github.com/toolboxmd/karpathy-wiki/blob/4f4c00d/docs/planning/2026-04-24-karpathy-wiki-v2.2-audit.md" \
  "https://github.com/toolboxmd/karpathy-wiki/blob/main/TODO.md"
do
  status=$(curl -sI "$url" | head -1 | awk '{print $2}')
  echo "$status $url"
done
```
Expected: each row starts with `200`.

- [ ] **Step 5: Confirm the CI gates run on every push**

After the next PR (any PR), the test suite includes the two new gates. CI passes mean no path leaks or bare-chip regressions. CI fails point at the offending file:line.

---

## Acceptance criteria summary

The hotfix is complete when ALL of these hold:

1. **Mechanical:** `! grep -rn '/Users/' docs/ case-studies/ examples/ README.md --exclude-dir=superpowers` returns zero matches.
2. **Mechanical:** `bash tests/run-all.sh` exits 0 (all four test files pass).
3. **Mechanical:** `git diff --stat HEAD~1..HEAD` shows ONLY the eleven files in this plan's per-file change list. No README.md changes. No reformatting drift.
4. **Mechanical:** every cross-repo URL in the diff returns HTTP 200 (Step A merged; SHA pins valid).
5. **Editorial:** the deployed site shows clean Sources blocks, working cross-page links, the new glossary in `/docs/00-overview#sources`, the "fires on it" blockquote in Question-2 of `/docs/03-three-questions`, and the trimmed `09-evolution` paragraph (no "Four cycles in six months").
6. **Mechanical:** the companion karpathy-wiki PR is merged.

---

## Out of scope (explicitly deferred)

- Republishing the private research docs (`LANDSCAPE`, `REVIEWER`, `LESSONS`) — labels-glossary handles reader confusion; out of scope.
- Sidebar group label cleanup (renaming `Authoring`/`Testing`/`Cross-platform` to include numeric prefixes) — `docs.json` rewrite touching every page entry; separate ship.
- Source-document version stamping (commit SHA, document hash, retrieval date in citations) — v0.2 idea.
- Cross-repo seed wiki feature for karpathy-wiki — Step A adds one file; the broader question is a karpathy-wiki design decision tracked separately.
- Linking `docs/08-packaging-as-plugin.md:117`'s `Cross-links: docs/11-cross-platform/` directory reference to the four sub-pages explicitly — directory references stay as bare backticks; cleaner per-page enumeration is a future polish.
