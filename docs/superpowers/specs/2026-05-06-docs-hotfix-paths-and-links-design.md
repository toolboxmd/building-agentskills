# Docs hotfix: paths, links, sources glossary, "fires on this" rewrite, 09-evolution timing

**Date:** 2026-05-06
**Subject:** building-agentskills v0.1 deployment cleanup
**Companion repo:** `toolboxmd/karpathy-wiki` (one-file PR)
**Status:** v1.3 spec, awaiting user review
**Revision history:**
- **v1.0 → v1.1.** Two independent reviewers (Opus + Codex) found two BLOCKERs and several HIGHs. v1.1 corrects the URL convention (Mintlify routes preserve the `docs/` prefix), replaces the broken line-number enumerations with grep-derived ground-truth tables, scopes the CI gate to exclude `docs/superpowers/specs/`, conforms to the existing `*.test.sh` test-harness convention, adds an explicit README.md exception (GitHub-rendered), makes Step-A merge a hard preflight for Step B, and clarifies the diff-scope rule with an inline DONE_WITH_CONCERNS protocol.
- **v1.1 → v1.2.** Re-review by both reviewers found two new BLOCKERs in v1.1 (a cross-repo URL pointing to a path that 404s post-v2.4-split, and a CI-gate self-test fixture that was logically vacuous). v1.2 pins all karpathy-wiki cross-repo URLs to commit `4f4c00d` (the v2.2 tip per the case study) so they remain byte-stable forever, fixes the linked-chip fixture to actually contain a backticked chip in link syntax, removes a self-contradiction in the Pattern A taxonomy around `skills/`, extends the bare-paths gate to catch `.md:<line>` and `.md:<start>-<end>` suffixes, clarifies the gate's argument-mode contract, scopes the gate to `.md` chips only (excluding `.sh`/`.py`), and corrects an off-by-one `docs.json` line citation.
- **v1.2 → v1.3.** Both reviewers pronounced v1.2 plan-ready with minor fixes; no BLOCKERs. v1.3 cleans up: a stale Risks-section paragraph contradicting the binding table directive (the v2.2 audit doc is in fact public), a new off-by-one in the SHA-pin justification citation, a "three fixtures" → "four fixtures" wording update, a tightening of the "now-defunct `:366`" phrasing, an explicit acknowledgment of the `#Lnnn` regex gap, an additional fixture exercising the line-*range* suffix (not just single-line), and a one-clause justification for keeping `karpathy-wiki/TODO.md` on `main` rather than SHA-pinning.

## Why

The site at building-agentskills.toolbox.md went live and surfaced multiple content issues that the v0.1 ship plan did not anticipate (the plan rule was "no content rewrites in docs/"; review focused on Mintlify config and llms.txt coverage, not page content). The issues cluster as:

1. **Private path leaks.** Source citations in nine doc locations contain absolute `/Users/lukaszmaj/...` filesystem paths from the author's local research directory. These paths expose username and local directory layout to the public site, do not resolve for any reader, and look unprofessional.
2. **Broken backtick "links."** Doc pages reference each other with bare-backtick path chips (e.g., `` `docs/03-three-questions.md` ``). Mintlify renders these as inline code, not Markdown links — they look clickable but do nothing.
3. **Source labels (`LANDSCAPE`, `REVIEWER`, `LESSONS`) used without introduction.** First-time readers see citation labels and have no idea what they refer to.
4. **"What fires on this if violated?" jargon.** The audit-method shorthand is correct but unintroduced. The author re-read the docs and could not parse it on a fresh pass; first-time readers will hit the same wall.
5. **Inaccurate timing claim in `09-evolution.md`.** Reads "four cycles in six months." The actual cadence was tighter; the author does not want to commit to a duration.
6. **Line-anchor format on a v2.2 spec citation.** Uses `:30-65`; correct GitHub format is `?plain=1#L30-L65`.
7. **No CI gate against future regressions.** Nothing prevents the next person from copying a `/Users/` path or a bare-backtick "link" into a doc.

(The earlier v1.0 spec listed "sidebar group label vs body-text number mismatch" as Issue #3. v1.1 drops that issue: addressing it requires a `docs.json` group-rename pass that affects every page entry; the hotfix's link conventions preserve numeric prefixes in link text, which is enough to keep prose and sidebar cross-referenceable. A full sidebar rename is a separate ship.)

## Step zero (mandatory pre-implementation)

Before any rewrite, the implementer MUST verify the deployed Mintlify URL form by probing the live site. The expected URL form for an in-repo page is `/docs/<basename>` (preserving the `docs/` prefix from `docs.json`). To verify:

```bash
curl -sI https://building-agentskills.toolbox.md/docs/03-three-questions | head -1   # expect: 200
curl -sI https://building-agentskills.toolbox.md/03-three-questions | head -1        # expect: 404
```

If the actual responses don't match expected, halt and re-spec. This was the dominant failure mode of v1.0; v1.1's URL convention is grounded in `docs.json:31-72` (every page entry includes the `docs/` prefix; Mintlify v4 maps these onto deployed URLs verbatim).

## What we ship

One unified hotfix split across two repos. Step A must merge before Step B's PR opens (see "Step-A preflight" below).

### Step A: companion PR to `toolboxmd/karpathy-wiki`

Add a new file: `wiki/concepts/claude-code-plugin-root-substitution.md`.

- **Source:** byte-for-byte copy of the author's local `wiki/concepts/claude-code-plugin-root-substitution.md` (the canonical concept page maintained in the author's personal karpathy-wiki).
- **Frontmatter:** unchanged. The `quality:` block, `sources:` field, `related:` field, and ingester-generated metadata stay as-is. Decision rationale: keeping karpathy-wiki ingester provenance intact is on-brand for a karpathy-wiki repo, even if some `related:` targets are not yet present in the public repo (they are inert YAML, not rendered as broken HTML links).
- **Commit message:** `docs: seed wiki/concepts with plugin-root substitution page`.
- **PR scope:** one file. No other karpathy-wiki changes.

### Step A preflight (binding for Step B)

Step B's PR MUST NOT be opened until Step A is merged. The implementer verifies via:

```bash
gh pr view <step-A-PR-number> --repo toolboxmd/karpathy-wiki --json state -q .state    # expect: MERGED
curl -sI https://github.com/toolboxmd/karpathy-wiki/blob/main/wiki/concepts/claude-code-plugin-root-substitution.md | head -1   # expect: 200
```

Both checks must pass before Step B's PR is opened. If Step A is reverted post-merge, Step B's external links would 404 on the live site; the implementer monitors and rolls back Step B if this happens.

### Step B: hotfix PR to `toolboxmd/building-agentskills`

The full content fix. Section "Per-file change list" below enumerates per-file changes. Single commit, message: `fix(docs): hotfix path leaks, link rewrites, sources glossary, fires-on-this onramp`.

### Step C: CI gates (same commit as Step B)

Two new test files, conforming to the existing `tests/run-all.sh` dispatcher convention (which runs every `*.test.sh` in `tests/`). The test files are part of the same commit as the content fix; this prevents the gates from running against pre-fix content.

- **`tests/check-no-absolute-paths.test.sh`** — fails if any `/Users/` string appears under `docs/`, `case-studies/`, or `README.md`. Excludes `docs/superpowers/specs/` (where this spec and future specs live; specs are unpublished design documents).
- **`tests/check-no-bare-paths.test.sh`** — calls a helper script `scripts/check-no-bare-paths.sh` (described below) and exits non-zero on violations. Includes inline fixture tests covering bare-chip, linked-chip, and topical-mention cases.

## Conventions locked

These apply across all link rewrites in this hotfix and become the project standard going forward.

### In-repo links from inside Mintlify-rendered files

Affects: `docs/**/*.md`, `case-studies/**/*.md`, `examples/**/*.md` (everything in `docs.json`'s navigation tree).

- Format: `[link text](/docs/<basename>)` — preserves the `docs/` prefix; drops `.md`.
- Example: `[Three questions](/docs/03-three-questions)`.
- For `case-studies/`: `[Case study](/case-studies/2026-04-25-karpathy-wiki-v2.2)`.
- For nested directories: `[Frontmatter](/docs/05-authoring/frontmatter)`.
- Tradeoff: GitHub blob view 404s on these links. Acceptable; the deployed Mintlify site is the primary reader for these files.

### In-repo links from `README.md`

`README.md` is GitHub-rendered, NOT a Mintlify-rendered page (it is not in `docs.json`'s navigation tree). It already uses GitHub-relative form throughout (e.g., line 11: `[`docs/03-three-questions.md`](docs/03-three-questions.md)`). **This convention is preserved.** Do NOT convert README.md links to Mintlify form — that would break them on github.com (the repo's most-viewed entry surface).

The Step B PR may make zero changes to README.md if the audit confirms no `/Users/` strings or other issues. Currently README.md is clean (no `/Users/` references).

### Cross-repo links

Format: absolute GitHub blob URL. Choose the ref carefully:

- **Use `main`** when the link target is a long-lived, stable artifact whose path is stable across versions (e.g., `wiki/concepts/claude-code-plugin-root-substitution.md` — once Step A creates it, it lives there indefinitely).
- **Use a commit SHA pin** when the link target's path or content is volatile across versions. This applies to anything tied to a specific historical ship — the case-study citations, the v2.2 spec doc, the v2.2 audit doc, the pre-split SKILL.md path. The canonical pin for v2.2-era karpathy-wiki content is **`4f4c00d`** (the v2-rewrite branch tip per `case-studies/2026-04-25-karpathy-wiki-v2.2.md:4`). Pinning to a SHA produces byte-stable permalinks immune to future renames or deletions; this is the pattern GitHub itself recommends ("press `y` for permalink").

Examples:

- Stable: `[plugin-root substitution wiki page](https://github.com/toolboxmd/karpathy-wiki/blob/main/wiki/concepts/claude-code-plugin-root-substitution.md)` — Step A puts this here; it stays.
- v2.2-pinned: `[v2.2 SKILL.md description, lines 3–12](https://github.com/toolboxmd/karpathy-wiki/blob/4f4c00d/skills/karpathy-wiki/SKILL.md?plain=1#L3-L12)` — the path `skills/karpathy-wiki/` was deleted post-v2.4-split (commit `b1bf4e6`); only the SHA-pinned URL resolves.
- v2.2-pinned: `[v2.2 spec doc, lines 30–65](https://github.com/toolboxmd/karpathy-wiki/blob/4f4c00d/docs/superpowers/specs/2026-04-24-karpathy-wiki-v2.2-design.md?plain=1#L30-L65)` — the file is currently public on `main` but pinning to `4f4c00d` ensures the line range matches the v2.2 prose forever.

The decision rule: if our prose describes the file *as it was at v2.2*, pin to `4f4c00d`. If our prose describes the file *as it currently is*, use `main`.

### Line-range anchors on cross-repo Markdown files

Format: append `?plain=1#L<start>-L<end>`. The `?plain=1` is required for GitHub to render Markdown with line numbers and apply the line-range highlight; without it, the Markdown is rendered as prose and the anchor is ignored.

- Example: `[v2.2 spec doc lines 30–65](https://github.com/toolboxmd/karpathy-wiki/blob/4f4c00d/docs/superpowers/specs/2026-04-24-karpathy-wiki-v2.2-design.md?plain=1#L30-L65)` — note the SHA pin, not `main`, per the version-pinning rule above.

### Heading anchors within Mintlify pages

Format: auto-slug from heading text. Lowercase, spaces → hyphens, punctuation stripped.

- Example: `## Sources` → link as `/docs/00-overview#sources`.
- Avoid custom anchor syntax `{#custom-id}`: GitHub does not honor it in blob view.

### External docs (Anthropic, agentskills.io, etc.)

Unchanged. Bare URLs in prose; Mintlify auto-links them.

## Per-file change list

Line numbers reference the current state of the repo (commit `6180799` and later). The change tables below were generated by `grep -n` against actual file content; they are the authoritative ground truth, replacing v1.0's broken line-number enumerations.

### Diff-scope rule (binding for the implementer)

The implementer must:

1. Apply the prose rewrites and path-leak fixes named in this section. Do not invent additional rewrites beyond what is specified.
2. For each file, the change tables list every line that changes. Lines not listed must not be touched.
3. Do not reformat unrelated lines (line wrapping, trailing whitespace cleanup, prose tightening). The acceptable diff is the lines that had to change to satisfy this spec, nothing else.
4. **DONE_WITH_CONCERNS protocol** (inline definition for context-free implementer agents): if you notice an unrelated improvement that you would normally make, do NOT make it. Instead, append a `## Implementer concerns` section to the **PR description** (NOT the commit message — commit messages describe the change, not handoff notes) with one line per concern in the form: "DONE_WITH_CONCERNS: I noticed [issue], at [file:line], which I did not address per the diff-scope rule. Recommended follow-up: [brief description]." The reviewer will decide whether to fold it in. This protocol exists because subagent reformatting hazards (see `docs/10-anti-patterns.md` "Subagent reformatting hazard") have been observed in past ships.
5. **Diff-size sanity check.** After implementing, run `git diff --stat HEAD^..HEAD` and confirm only files in the per-file change list appear. The line counts per file should be in the same order of magnitude as the change-table sizes below (roughly: 00-overview ~30 lines changed; 03-three-questions ~20 lines; 09-evolution ~3 lines; 10-anti-patterns ~12 lines; 12-update-mechanism ~10 lines; 08-packaging-as-plugin ~10 lines; 11-cross-platform/claude-code ~6 lines; case-study ~25 lines).

### Chip-classification rules

Empirically derived from the grep audit, three distinct chip patterns appear in this codebase:

- **Pattern A: Path-prefixed in-repo navigational chip.** Form: `` `docs/<...>.md` ``, `` `case-studies/<...>.md` ``, `` `examples/<...>.md` `` — used as a "see also" reference. **Convert to a Mintlify-form link.** Strip the `.md` and prepend the route per the conventions above. **Note:** `` `skills/<...>.md` `` chips are explicitly NOT Pattern A. The `skills/` directory is not in `docs.json`'s navigation tree, so its files are GitHub-rendered, not Mintlify-rendered. Convert `` `skills/<...>.md` `` chips to absolute GitHub URLs (e.g., `[the loader skill](https://github.com/toolboxmd/building-agentskills/blob/main/skills/building-agentskills/SKILL.md)`).
- **Pattern B: Bare-prefix in-repo navigational chip.** Form: `` `<numeric-prefix>-<name>.md` `` (e.g., `` `07-mechanism-vs-decoration.md` ``, `` `01-quickstart.md` ``) used as a same-section "see also" reference. **Convert to a Mintlify-form link** with the full `/docs/` route inferred from context (these always live under `docs/`). The original spec missed this pattern; v1.1 enumerates it explicitly.
- **Pattern C: Topical / cross-repo chip — DO NOT CONVERT.**
  - Filenames discussed as topics (e.g., `` `SKILL.md` `` in "your `SKILL.md` should be under 500 lines"). These are code references.
  - Configuration filenames in prose (e.g., `` `plugin.json` ``, `` `hooks.json` ``, `` `index.md` ``).
  - Cross-repo references (e.g., `` `karpathy-wiki/TODO.md` ``, `` `obra/superpowers` ``, `` `agentskills/agentskills` ``). When these need to be linkable, use a full GitHub URL.
  - The wiki concept-page references in `karpathy-wiki/docs/...` paths (e.g., line 23 of `03-three-questions.md`).

### `docs/00-overview.md`

| Line | Current state | Action |
|---|---|---|
| 60 | "Decoration vs mechanism. Every threshold or invariant in your SKILL.md must answer 'what fires on it?' …Documented in `` `07-mechanism-vs-decoration.md` ``." (Pattern B) | Replace the entire sentence with the on-ramp prose below. |
| 61 | "The three-question framework. … See `` `03-three-questions.md` ``." (Pattern B) | Convert chip to link: "See [Three questions](/docs/03-three-questions)." |
| 62 | "Heredoc-in-prose silent correctness bugs. … See `` `05-authoring/prose-discipline.md` ``." (Pattern B, with subdir prefix in the bare-form chip — note: this is NOT a `docs/` prefix; it's `05-authoring/`. Convert as if from `docs/`). | Convert: "See [Prose discipline](/docs/05-authoring/prose-discipline)." |
| 63 | "TDD inversions. … See `` `06-testing/tests-that-pass-immediately.md` ``." (Pattern B) | Convert: "See [Tests that pass immediately](/docs/06-testing/tests-that-pass-immediately)." |
| 64 | "Subagent reformatting hazard. … See `` `10-anti-patterns.md` ``." (Pattern B) | Convert: "See [Anti-patterns](/docs/10-anti-patterns)." |
| 65 | "Cross-platform reference frame. Per-harness sections under `` `docs/11-cross-platform/` `` …" (Pattern A, directory not file) | Leave as-is. This is a directory reference, not a single-file navigational chip. |
| 79 | "The three blocker docs (`` `docs/01-quickstart.md` ``, `` `docs/02-mental-model.md` ``, `` `docs/04-token-economics.md` ``)…" (Pattern A, three chips) | Convert all three: `[01 quickstart](/docs/01-quickstart)`, `[02 mental model](/docs/02-mental-model)`, `[04 token economics](/docs/04-token-economics)`. |
| 83 | "The hero framework (`` `03-three-questions.md` ``)…" (Pattern B) | Convert: `[03 three questions](/docs/03-three-questions)`. |
| 85 | "Per-harness specifics live in `` `docs/11-cross-platform/` ``." (Pattern A, directory) | Leave as-is. Directory reference. |
| 87–92 | The current `## Sources` block including the two `/Users/` paths on lines 89 and 90. | Replace the whole block per the new-text spec below. This rewrite is what removes the two `/Users/` leaks for this file. |

**On-ramp rewrite for line 60:**

> Decoration vs mechanism. Every threshold or invariant in your SKILL.md must answer one question: *if this rule is broken, what code will notice and stop the agent?* If the answer is "nothing — the agent decides," rewrite the rule into something concrete: a script, validator exit code, hook, or captured artifact. We use the shorthand "what fires on it?" for this question throughout the docs. Documented in [Mechanism vs decoration](/docs/07-mechanism-vs-decoration).

**Sources block replacement for lines 87–92:**

```markdown
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

(The README cross-link uses an absolute GitHub URL because README.md is not Mintlify-rendered. The other cross-link is in-site.)

### `docs/03-three-questions.md`

| Line | Current state | Action |
|---|---|---|
| 16 | "see `` `docs/11-cross-platform/claude-code.md` `` for the field reference" (Pattern A) | Convert: `[the Claude Code field reference](/docs/11-cross-platform/claude-code)`. |
| 19 | "The deeper why is in `` `docs/02-mental-model.md` ``…The taxonomy is in `` `docs/05-authoring/frontmatter.md` ``." (Pattern A, two chips) | Convert both. |
| 23 | "(lines 3-12 of `` `karpathy-wiki/skills/karpathy-wiki/SKILL.md` ``)" (Pattern C, cross-repo, v2.2-era path) | Convert to GitHub URL with **v2.2 SHA pin** (the path `skills/karpathy-wiki/` was deleted in the v2.4 split, commit `b1bf4e6`; only a pinned link resolves): `[lines 3–12 of the v2.2 karpathy-wiki SKILL.md](https://github.com/toolboxmd/karpathy-wiki/blob/4f4c00d/skills/karpathy-wiki/SKILL.md?plain=1#L3-L12)`. The prose is describing the v2.2-tip state, so the v2.2 pin is correct. Verified: at `4f4c00d`, lines 3–12 of that file are the description block beginning "Load at the start of EVERY conversation." |
| 27–29 | End of "Question 2: what fires on rules?" intro paragraph (line 29 ends "what enforces the claim?"). | Insert the on-ramp sentence (text below) after line 29 but **before** the bullets at line 31, so the definition lands adjacent to its first use. |
| 34 | "ask 'what fires on this if violated?'" + chip `` `docs/07-mechanism-vs-decoration.md` `` (Pattern A) | Convert chip: `[Mechanism vs decoration](/docs/07-mechanism-vs-decoration)`. The shorthand `"what fires on this if violated?"` stays — by this point it's defined. |
| 44 | `` `index.md` `` (Pattern C, topical — discussing a wiki's index file). | Leave as-is. Topical, not navigational. |
| 48 | "(`` `karpathy-wiki/docs/planning/2026-04-24-karpathy-wiki-v2.2-audit.md:366` ``)…see `` `docs/07-mechanism-vs-decoration.md` ``" (one Pattern C cross-repo chip with line anchor; one Pattern A chip) | Cross-repo chip: convert to **v2.2-pinned** GitHub URL: `[karpathy-wiki v2.2 audit, line 366](https://github.com/toolboxmd/karpathy-wiki/blob/4f4c00d/docs/planning/2026-04-24-karpathy-wiki-v2.2-audit.md?plain=1#L366)`. The prose describes the v2.2 audit state. Note that the original chip uses an IDE-style `:366` line citation (the convention used by `grep -n` and many editors), which is NOT a valid GitHub URL anchor; the rewrite must use `?plain=1#L366` per the line-range-anchors convention above. In-repo chip: standard convert. |
| 58 | "is in `` `docs/04-token-economics.md` ``" (Pattern A) | Convert. |
| 66 | "discussed in `` `docs/04-token-economics.md` ``" (Pattern A) | Convert. |
| 78 | "(`` `01-quickstart.md` ``, `` `02-mental-model.md` ``, `` `04-token-economics.md` ``)" (Pattern B, three chips) | Convert all three. |
| 90 | Top of `## Sources` block. | Add a one-line back-reference (text below). |
| 98 | "Cross-links: `` `docs/02-mental-model.md` `` (Q1 deep dive), `` `docs/07-mechanism-vs-decoration.md` `` (Q2 deep dive), `` `docs/04-token-economics.md` `` (Q3 deep dive), `` `case-studies/2026-04-25-karpathy-wiki-v2.2.md` `` (the worked answers above expanded)." (Pattern A, four chips) | Convert all four. |
| 100 | "Currently linking back: `` `docs/00-overview.md` ``, …, `` `case-studies/2026-04-25-karpathy-wiki-v2.2.md` ``…" (Pattern A, six chips) | Convert all six. |

**On-ramp text to insert after line 29 (before line 31's "Decoration." bullet):**

> One-line plain-English form: *if this rule is broken, what code will notice and stop the agent?* If nothing — rewrite the rule. We shorten this question to "what fires on it?" everywhere it appears below.

**Back-reference for top of `## Sources` (line 90):**

> See [Overview → Sources](/docs/00-overview#sources) for what `LANDSCAPE`, `REVIEWER`, and `LESSONS` refer to.

(Existing source-bullet content stays as-is.)

### `docs/09-evolution.md`

| Line | Current state | Action |
|---|---|---|
| 17 | "Cycle cadence: typically per major-version ship. Karpathy-wiki ran the cycle for v2 (Tasks 1-29), v2-hardening (Tasks 30-44), v2.1 (missed-capture patch), and v2.2 (Tasks 50-62). Four cycles in six months. Each cycle produced lessons that fed the next." | Delete the sentence "Four cycles in six months." Surrounding sentences unchanged. No new timing claim. |
| 78 | "Per `` `docs/12-update-mechanism.md` ``…" (Pattern A) | Convert. |
| 88 | "Cross-links: `` `docs/12-update-mechanism.md` ``, `` `case-studies/2026-04-25-karpathy-wiki-v2.2.md` ``." (Pattern A, two chips) | Convert both. |

### `docs/10-anti-patterns.md`

| Line | Current state | Action |
|---|---|---|
| 5 | "see `` `docs/03-three-questions.md` `` for the framework that this catalog inverts" (Pattern A) | Convert. |
| 11 | "See `` `docs/07-mechanism-vs-decoration.md` ``" (Pattern A) | Convert. |
| 17 | "See `` `docs/05-authoring/prose-discipline.md` ``" (Pattern A) | Convert. |
| 29 | "(`` `bash tests/run-all.sh` ``)…See `` `docs/06-testing/unit-tests.md` ``" (one Pattern C, code; one Pattern A) | Leave the `bash tests/run-all.sh` chip (it's a command). Convert the doc chip. |
| 47 | "See `` `docs/06-testing/unit-tests.md` ``" (Pattern A) | Convert. |
| 53 | "See `` `docs/05-authoring/triggers.md` ``" (Pattern A) | Convert. The `` `skill` tool `` chip later on the same line is Pattern C (code reference, leave). |
| 59 | "See `` `docs/06-testing/unit-tests.md` ``" (Pattern A) | Convert. |
| 64 | "See `` `/Users/lukaszmaj/wiki/concepts/claude-code-plugin-root-substitution.md` ``." | **Path leak.** Replace with: "See [the plugin-root substitution wiki page](https://github.com/toolboxmd/karpathy-wiki/blob/main/wiki/concepts/claude-code-plugin-root-substitution.md)." This link only resolves after Step A merges. |
| 65 | "Document harness gotchas in `` `docs/11-cross-platform/` ``." (Pattern A, directory) | Leave as-is. Directory reference. |
| 71 | "See `` `docs/06-testing/tests-that-pass-immediately.md` ``" (Pattern A) | Convert. |
| 98 | "Cross-links: `` `docs/03-three-questions.md` ``, `` `docs/07-mechanism-vs-decoration.md` ``, `` `docs/05-authoring/prose-discipline.md` ``, `` `docs/06-testing/unit-tests.md` ``, `` `docs/06-testing/tests-that-pass-immediately.md` ``, `` `docs/05-authoring/triggers.md` ``, `` `case-studies/2026-04-25-karpathy-wiki-v2.2.md` ``." (Pattern A, seven chips) | Convert all seven. |

### `docs/12-update-mechanism.md`

| Line | Current state | Action |
|---|---|---|
| 11 | "(`` `/Users/lukaszmaj/dev/bigbrain/research/.../2026-04-24-lessons-from-v2.2-ship.md` ``)" | **Path leak.** Rewrite the sentence per text below. |
| 15 | "`` `case-studies/<date>-<ship-name>.md` ``" (Pattern C, template path with angle brackets) | Leave as-is. This is a template/format example, not a navigational link. |
| 28 | "(`` `case-studies/2026-04-25-karpathy-wiki-v2.2.md` ``) is the worked example" (Pattern A) | Convert. |
| 42 | "live in `` `docs/11-cross-platform/` ``" (Pattern A, directory) | Leave as-is. Directory reference. |
| 49 | "(`` `/Users/lukaszmaj/dev/bigbrain/research/.../2026-04-24-skill-authoring-landscape-2026.md` ``)" | **Path leak.** Rewrite per text below. |
| 72 | "The loader skill (`` `skills/building-agentskills/SKILL.md` ``)." (Pattern A) | Convert: `[the loader skill](https://github.com/toolboxmd/building-agentskills/blob/main/skills/building-agentskills/SKILL.md)`. **Note:** `skills/` is NOT in `docs.json`'s navigation tree, so it is GitHub-rendered, not Mintlify-rendered. Use absolute GitHub URL. |
| 73 | "The example skill (`` `examples/minimal-skill/SKILL.md` ``)." | `examples/minimal-skill/SKILL` IS in `docs.json:79`, so this is Mintlify-rendered. Convert: `[the minimal example skill](/examples/minimal-skill/SKILL)`. |
| 83 | "Cross-links: `` `case-studies/2026-04-25-karpathy-wiki-v2.2.md` ``." (Pattern A) | Convert. |

**Line-11 rewrite:**

> The v2.2 lessons report — the document we cite as `LESSONS` (see [Overview → Sources](/docs/00-overview#sources)) — is the seed instance of this format. It enumerates per-skill load-bearing analysis, patterns the existing meta-skills do not cover, the brainstorming-spec-plan-execute pipeline as gestalt, RED-GREEN-REFACTOR for prose, and case studies of reviewer-driven fix-ups. The shape is a reference for what a retrospective looks like.

**Line-49 rewrite:**

> The v2.2 ship's landscape report — `LANDSCAPE` in our citations — is the seed instance. It enumerates state of the art, who is writing skill-authoring guides, the harness landscape, anatomy of a "good" skill, anti-patterns observed in the wild, the quality bar for 2026, source catalog.

### `docs/08-packaging-as-plugin.md`

| Line | Current state | Action |
|---|---|---|
| 5 | "lives in `` `docs/11-cross-platform/` ``" (directory) | Leave as-is. |
| 47 | "See `` `docs/09-evolution.md` ``" (Pattern A) | Convert. |
| 56 | "See `` `docs/05-authoring/line-budget.md` ``" (Pattern A) | Convert. |
| 69 | "(per `` `docs/04-token-economics.md` `` and `` `docs/11-cross-platform/claude-code.md` ``)" (Pattern A, two chips) | Convert both. |
| 77 | "(`` `/Users/lukaszmaj/wiki/concepts/claude-code-plugin-root-substitution.md` ``)" | **Path leak.** Rewrite: `Source: REVIEWER G3, "wiki concept page references" ([wiki concept page](https://github.com/toolboxmd/karpathy-wiki/blob/main/wiki/concepts/claude-code-plugin-root-substitution.md)).` |
| 105 | "`` `GEMINI.md` ``…`` `commands/*.toml` ``" (Pattern C) | Leave. Both are file-format topic references, not navigational. |
| 108 | "Full coverage in `` `docs/11-cross-platform/` ``" (directory) | Leave. |
| 117 | "Cross-links: `` `docs/11-cross-platform/` ``." (directory) | Leave. (Per-page cross-links to a directory are weak; consider in a future ship listing the four sub-pages explicitly. Out of scope for this hotfix.) |

### `docs/11-cross-platform/claude-code.md`

| Line | Current state | Action |
|---|---|---|
| 40 | "Source: REVIEWER G3; `` `/Users/lukaszmaj/wiki/concepts/claude-code-plugin-root-substitution.md` ``." | **Path leak.** Rewrite: `Source: REVIEWER G3; [plugin-root substitution wiki page](https://github.com/toolboxmd/karpathy-wiki/blob/main/wiki/concepts/claude-code-plugin-root-substitution.md).` |
| 52 | "See `` `docs/08-packaging-as-plugin.md` ``" (Pattern A) | Convert. |
| 74 | "(Question 1 of the hero framework, `` `docs/03-three-questions.md` ``)" (Pattern A) | Convert. |
| 88 | "See `` `docs/05-authoring/frontmatter.md` ``…`` `docs/07-mechanism-vs-decoration.md` ``" (Pattern A, two chips) | Convert both. |
| 98 | "Cross-links: `` `docs/04-token-economics.md` `` (the SessionStart-hook injection cost), `` `docs/08-packaging-as-plugin.md` `` (the plugin manifest and the substitution gotcha)." (Pattern A, two chips) | Convert both. |

### `case-studies/2026-04-25-karpathy-wiki-v2.2.md`

| Line | Current state | Action |
|---|---|---|
| 10 | "for `` `toolboxmd/building-agentskills` ``" (Pattern C, repo name) | Leave as-is. Topic reference to the repo as an entity. |
| 12 | "in `` `LESSONS` `` (`` `/Users/lukaszmaj/dev/bigbrain/research/.../2026-04-24-lessons-from-v2.2-ship.md` ``)" | **Path leak.** Rewrite per text below. |
| 33 | "(`` `/Users/lukaszmaj/dev/toolboxmd/karpathy-wiki/docs/superpowers/specs/2026-04-24-karpathy-wiki-v2.2-design.md:30-65` ``)" | **Path leak + wrong anchor format.** Rewrite per text below. |
| 37 | "See `` `docs/02-mental-model.md` ``" (Pattern A) | Convert. |
| 45 | "`` `index.md` ``" (topical) | Leave. |
| 63 | "See `` `docs/07-mechanism-vs-decoration.md` ``" (Pattern A) | **Note:** v1.0 spec missed this line; v1.1 catches it. Convert. |
| 75 | "See `` `docs/06-testing/unit-tests.md` ``" (Pattern A) | Convert. |
| 81 | "See `` `docs/06-testing/red-green-for-prose.md` ``" (Pattern A) | Convert. |
| 87 | "See `` `docs/10-anti-patterns.md` ``" (Pattern A) | Convert. |
| 93 | "See `` `docs/05-authoring/prose-discipline.md` ``" (Pattern A) | Convert. |
| 109 | "Layer 2 patterns from `` `obra/superpowers` ``…See `` `docs/00-overview.md` ``" (one cross-repo Pattern C; one Pattern A) | Cross-repo: convert to `[obra/superpowers](https://github.com/obra/superpowers)`. In-repo: convert. |
| 118 | "documented in `` `docs/10-anti-patterns.md` ``" (Pattern A) | Convert. |
| 124–130 | Bullet list of "What the existing canon missed" patterns, each ending "See `` `docs/<...>.md` ``" (Pattern A, seven chips) | Convert all seven. Line 127 also contains the in-prose chip `` `subagent-driven-development` `` (Pattern C, code reference, leave). |
| 134 | "documented in `` `karpathy-wiki/TODO.md` ``" (cross-repo) | Convert to GitHub URL with `main` ref (NOT `4f4c00d`): `[karpathy-wiki TODO.md](https://github.com/toolboxmd/karpathy-wiki/blob/main/TODO.md)`. The case-study prose says "Two known imperfections shipped, documented in `karpathy-wiki/TODO.md` with `status: open`" — readers want the *current* TODO list (where they can see whether the items are still open or have been resolved), not a frozen v2.2 snapshot. This is a forward-looking citation, so `main` is correct per the version-pinning decision rule above. |
| 153–159 | `## Cross-links` section, seven `docs/...` chips. (Pattern A) | Convert all seven. |
| 165 | "the `` `skills/pdf` `` path correction" (Pattern C, topic reference within a citation; not karpathy-wiki, refers to anthropics/skills) | Leave as-is. Topical. |

**Line-12 rewrite:**

> The full retrospective lives in the document we cite as `LESSONS` (see [Overview → Sources](/docs/00-overview#sources)). This case study is the public-audience version, written for readers who landed here from a search.

**Line-33 rewrite (v2.2-pinned URL):**

> The architectural decision is documented in the [v2.2 spec doc, lines 30–65](https://github.com/toolboxmd/karpathy-wiki/blob/4f4c00d/docs/superpowers/specs/2026-04-24-karpathy-wiki-v2.2-design.md?plain=1#L30-L65), with an explicit "Architectural decision: kill `sources/`" section and a job-vs-replacement table. Without brainstorming, v2.2 would have shipped 7+ patches plus 31 stub-improvement passes; instead it shipped one architectural cut + 5 mechanism-wirings.

### `README.md`

**Action: no changes.** The audit confirms README.md has zero `/Users/` strings and no broken-link issues — its existing GitHub-relative format works correctly on github.com (its primary read context). The Mintlify-form convention does NOT apply to README.md (see "Conventions locked → In-repo links from README.md").

If the implementer's audit during implementation surfaces an issue (e.g., a path leak in a section not currently visible), it is fixed using the GitHub-relative form already used throughout the file, not Mintlify form.

## CI gates (Step C)

### `scripts/check-no-bare-paths.sh`

A Bash script that:

1. Greps `docs/`, `case-studies/`, `examples/`, and `README.md` for backtick-wrapped strings whose payload matches the regex `[A-Za-z0-9._/-]+\.md(:[0-9]+(-[0-9]+)?)?` — i.e., a `.md` path optionally followed by `:<line>` or `:<start>-<end>` (catches both bare chips and chips with line-range suffixes).
2. Excludes the spec directory `docs/superpowers/specs/`.
3. For each match, applies the chip-classification rules from this spec:
   - **Pattern A or B (navigational chip):** check whether the surrounding context is Markdown link syntax. The rule: a backtick-wrapped path is OK only if it appears as the link text inside `[…](…)` syntax, OR if the path is in the link target. Specifically: scan for `[<...>`<path>.md`<...>](<...>)` or `[<text>](<...>`<path>.md`<...>)` — both are link forms.
   - **Pattern C (topical chip):** the script's allowlist contains literal exact-match strings: `SKILL.md`, `plugin.json`, `hooks.json`, `marketplace.json`, `.claude-plugin/plugin.json`, `index.md`, `GEMINI.md`, `TODO.md` (when not preceded by `karpathy-wiki/`), `LICENSE`, template patterns matching `<.*>` (angle-bracket placeholders).
4. Returns 0 if all matches are either inside link syntax or on the allowlist; returns 1 with a list of file:line:violation otherwise.

**Argument mode.** If invoked with one or more positional arguments (`bash scripts/check-no-bare-paths.sh path1 path2 ...`), the script ignores the default scope and greps only the given paths (files or directories). The allowlist and link-detection logic are unchanged. Used for fixture self-testing and ad-hoc per-file checks. The default no-arg invocation is the CI-gate behavior; arg mode is a developer convenience.

**Scope of the gate.** The grep is restricted to backtick-wrapped strings whose payload ends in `.md` (with optional `:<line>` or `:<start>-<end>` suffix). Out of scope:

- **Non-`.md` filename chips** — `.sh`, `.py`, `.ts`, `.json`, `.yaml`, etc. — are implicitly Pattern C. This includes script names like `wiki-commit.sh`, `wiki-validate-page.py`, and `wiki-normalize-frontmatter.py` that appear repeatedly in the case study; the gate does not flag them.
- **GitHub-form anchors `#L<n>` or `#L<n>-L<m>`** appended to chips. Example: `` `foo.md#L48` ``. The gate's regex stops at `.md(:N(-N)?)?` and does not look for `#L`. This is a known gap; rely on review until a future iteration extends the regex. The realistic risk is someone pasting a GitHub permalink into a chip and forgetting to convert it; this would slip past the gate but is caught by the editorial walkthrough in the verification section.
- **Reference-style links** (`` `foo.md` `` followed elsewhere by `[`foo.md`][1]\n[1]: …`). Multi-line/separated link syntax is not detected by the regex-based heuristic. Add to allowlist if encountered. Same for **multi-line links** where the chip and `[…](…)` wrappers span lines.

The script is intentionally simple regex-based (no Markdown AST parser dependency). False positives are tuned by extending the allowlist; false negatives are tuned by review. Initial allowlist is conservative; future extensions are documented in a comment block at the top of the script.

### `tests/check-no-absolute-paths.test.sh`

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

### `tests/check-no-bare-paths.test.sh`

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
# The gate must catch `.md:<line>` suffix patterns.
echo 'See `docs/03-three-questions.md:48` for the audit reference.' > "$fixture_dir/bare-with-line.md"

# Fixture 5: chip with line-range suffix (e.g. `something.md:30-65`) — should be flagged.
# Distinct from fixture 4 because the regex's optional second group `(-[0-9]+)?`
# is exercised only by ranges, not single-line suffixes.
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
  echo "FAIL: bare chip with single-line suffix not flagged (gate missed `.md:<line>` pattern)"; exit 1
fi

if ! bash scripts/check-no-bare-paths.sh "$fixture_dir/bare-with-range.md"; then
  echo "PASS: bare chip with line-range suffix flagged"
else
  echo "FAIL: bare chip with line-range suffix not flagged (gate missed `.md:<start>-<end>` pattern)"; exit 1
fi
```

(The script's argument-handling form — `bash scripts/check-no-bare-paths.sh [path]` — is part of the spec; default behavior is whole-tree scan, with the optional path arg targeting a specific file or directory for fixture testing.)

## Verification

### Pre-implementation (Step zero)

The `curl -sI` check above confirms the URL convention before any rewrite. Mandatory.

### Per-file post-implementation verification

For each changed file:

1. Open the corresponding page on `localhost:3000` (Mintlify dev server) at the expected route (e.g., `localhost:3000/docs/03-three-questions`).
2. Click every rewritten link. Confirm it lands on the expected target.
3. Confirm no `/Users/` strings remain anywhere on the page (visual + the new CI gate).
4. Read the changed prose blocks for tone consistency with surrounding text.

### Cross-repo link verification

After Step A merges and Step B is on a draft branch:

- For each cross-repo karpathy-wiki link in the diff, run `curl -sI <url> | head -1` and confirm 200.
- For the v2.2 spec doc link with `?plain=1#L30-L65`, open it in a browser and confirm GitHub renders the file with line numbers and highlights lines 30–65.

### CI gate verification

- Run `bash tests/run-all.sh` on the hotfix branch. Both new gates plus the existing `build-llms.test.sh` and `check-llms-coverage.test.sh` must pass.
- Manually introduce a violation (a `/Users/` path in `docs/00-overview.md`) and re-run. Confirm `tests/check-no-absolute-paths.test.sh` fails with the offending file:line.
- The `tests/check-no-bare-paths.test.sh` self-tests its five fixture cases (bare, linked, topical-allowlisted, bare-with-single-line-suffix, bare-with-line-range-suffix) on every run, so its correctness is verified inline.

## Risks and known imperfections

### `related:` frontmatter in the copied concept page references absent files

The copied `wiki/concepts/claude-code-plugin-root-substitution.md` has `related:` entries for `concepts/claude-code-skill-autoload-mechanisms.md` and `entities/claude-code-cli-agent-tool.md`. Neither file exists in `toolboxmd/karpathy-wiki/wiki/`. The fields are inert (YAML, not rendered as HTML links), but a future tooling layer that walks `related:` fields would surface broken references. Decision: keep as-is per user direction; documented as known imperfection.

### CI gate false-positive risk

The `check-no-bare-paths.sh` script's allowlist will need tuning. Initial set is conservative (only obvious topical mentions). False positives encountered during initial deploy get added to the allowlist with a one-line justification comment.

### The `karpathy-wiki/docs/planning/2026-04-24-karpathy-wiki-v2.2-audit.md` reference

`docs/03-three-questions.md` line 48 references this file. Verified publicly reachable at both `main` (current) and `4f4c00d` (v2.2 tip) via `curl -sI` returning HTTP/2 200. The per-file change table at line 201 above unconditionally pins this rewrite to `4f4c00d` per the v2.2-historical-citation rule; no fallback condition. If at some future point the file is removed from the public repo, the SHA-pinned link still resolves on GitHub (SHA pins survive branch deletions and rebases).

### CI gates might fail on first push if the hotfix is incomplete

Steps B and C land in the same commit by design — if the implementer pushes Step B's content fix without the gates, the gates would run against intermediate state and not catch their own scope. The implementer should not split.

## Acceptance criteria

The hotfix is done when ALL of these pass:

1. **Mechanical:** `! grep -rn '/Users/' docs/ case-studies/ examples/ README.md --exclude-dir=superpowers` returns no matches (or, equivalently: `bash tests/check-no-absolute-paths.test.sh` exits 0).
2. **Mechanical:** `bash tests/run-all.sh` passes all four test files (the two existing plus the two new ones).
3. **Mechanical:** `git diff --stat HEAD^..HEAD` for the Step-B commit shows ONLY files in this spec's per-file change list. No README.md changes (audit confirms it is clean). No reformatting of unrelated files.
4. **Mechanical:** `curl -sI` against each cross-repo link in the diff returns 200 (after Step A merges).
5. **Editorial (manual):** the deployed site at building-agentskills.toolbox.md (after Step B merges) shows clean `Sources` blocks (no path strings), working cross-page links (each click lands on the right page), the new "About the citations" glossary in `/docs/00-overview#sources`, the on-ramped "fires on it" definition in `/docs/03-three-questions` Question-2 section, and the trimmed `09-evolution.md` paragraph (no "Four cycles in six months").
6. **Mechanical:** the companion karpathy-wiki PR is merged (Step A preflight check passed before Step B opened).

Criteria 1–4 and 6 are scriptable. Criterion 5 is the manual review gate — there is no way to fully mechanize "the prose reads well." It is held to the standard of "another reader on the team can sanity-check by clicking through `/docs/00-overview`, `/docs/03-three-questions`, `/docs/09-evolution` once and report no surprises."

## Out of scope (explicitly deferred)

- **Republishing private research docs (`LANDSCAPE`, `REVIEWER`, `LESSONS`).** The labels-glossary approach handles reader confusion. Out of scope.
- **Sidebar group label cleanup.** Renaming the sidebar groups themselves to include numeric prefixes (e.g., "05 Authoring") is a `docs.json` change touching every page entry; out of scope for this hotfix.
- **Source-document version stamping.** Citation pinning (commit SHA, document hash, retrieval date) is a v0.2 idea, not a hotfix.
- **Cross-repo seed wiki feature for karpathy-wiki.** Step A adds one file. The broader question of whether `toolboxmd/karpathy-wiki` should ship with a fully seeded `wiki/` directory as canonical example content is a karpathy-wiki design question, tracked separately if desired.
- **Linking `docs/08-packaging-as-plugin.md:117` cross-link directory to the four sub-pages.** Currently `Cross-links: docs/11-cross-platform/` is a directory reference. Listing the four sub-pages explicitly would be cleaner; deferred.

## Sources

- User report (image-attached deployment review, 2026-05-06).
- Audit grep across `docs/`, `case-studies/`, `README.md` (9 path-leak occurrences across 6 files).
- Per-file `grep -n` audits replacing v1.0's broken line-number enumerations.
- Mintlify v4 link-resolution research and live-site HTTP probes confirming `/docs/<basename>` URL form (NOT `/<basename>`).
- GitHub Markdown line-range anchor spec (`?plain=1#L<n>-L<m>` format).
- Reviewer convergence (Opus + Codex independent passes, both surfacing the same BLOCKERs in v1.0).
- File reads of all affected docs at commit `6180799`.
- `docs.json` page-entry inspection (lines 31–72) confirming `docs/` prefix preserved on all routes.
- `tests/run-all.sh` inspection confirming `*.test.sh` dispatcher convention.
- `README.md` inspection confirming pre-existing GitHub-relative link form.
