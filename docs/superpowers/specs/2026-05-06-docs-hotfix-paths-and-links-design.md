# Docs hotfix: paths, links, sources glossary, "fires on this" rewrite, 09-evolution timing

**Date:** 2026-05-06
**Subject:** building-agentskills v0.1 deployment cleanup
**Companion repo:** `toolboxmd/karpathy-wiki` (one-file PR)
**Status:** spec draft, awaiting user review

## Why

The site at building-agentskills.toolbox.md went live and surfaced eight discrete content issues that the v0.1 ship plan did not anticipate (the plan rule was "no content rewrites in docs/"; review focused on Mintlify config and llms.txt coverage, not page content). The issues cluster as:

1. **Private path leaks.** Source citations in nine doc locations contain absolute `/Users/lukaszmaj/...` filesystem paths from the author's local research directory. These paths expose username and local directory layout to the public site, do not resolve for any reader, and look unprofessional.
2. **Broken backtick "links."** Doc pages reference each other with bare-backtick path chips (e.g., `` `docs/03-three-questions.md` ``). Mintlify renders these as inline code, not Markdown links — they look clickable but do nothing.
3. **Sidebar group label vs. body-text number mismatch.** The sidebar shows "Authoring," "Testing," "Cross-platform" as group names (per `docs.json`); the body prose references the same content as `05-…`, `06-…`, `11-…`. A reader cannot easily map between them.
4. **Source labels (`LANDSCAPE`, `REVIEWER`, `LESSONS`) used without introduction.** First-time readers see citation labels and have no idea what they refer to.
5. **"What fires on this if violated?" jargon.** The audit-method shorthand is correct but unintroduced. The author re-read the docs and could not parse it on a fresh pass; first-time readers will hit the same wall.
6. **Inaccurate timing claim in `09-evolution.md`.** Reads "four cycles in six months." The actual cadence was tighter; the author does not want to commit to a duration.
7. **Line-anchor format on a v2.2 spec citation.** Uses `:30-65`; correct GitHub format is `?plain=1#L30-L65`.
8. **No CI gate against future regressions.** Nothing prevents the next person from copying a `/Users/` path or a bare-backtick "link" into a doc.

## What we ship

One unified hotfix split across two repos. The order matters: Step A must merge before Step B's external links resolve.

### Step A: companion PR to `toolboxmd/karpathy-wiki`

Add a new file: `wiki/concepts/claude-code-plugin-root-substitution.md`.

- **Source:** byte-for-byte copy of `/Users/lukaszmaj/wiki/concepts/claude-code-plugin-root-substitution.md`.
- **Frontmatter:** unchanged. The `quality:` block, `sources:` field, `related:` field, and ingester-generated metadata stay as-is. Decision rationale: keeping the karpathy-wiki ingester provenance intact is on-brand for a karpathy-wiki repo, even if some fields don't yet have linkable targets.
- **Commit message:** `docs: seed wiki/concepts with plugin-root substitution page`.
- **PR scope:** one file. No other karpathy-wiki changes.

### Step B: hotfix PR to `toolboxmd/building-agentskills`

The full content fix. Section 4 below enumerates per-file changes. Single commit.

### Step C: CI gates

Two new structural checks added to `tests/run-all.sh`:

- **`no-absolute-paths` gate.** Fails if any `/Users/` string appears anywhere under `docs/`, `case-studies/`, `README.md`. Implementation: one-line grep with `! grep -rn '/Users/' docs/ case-studies/ README.md`.
- **`no-bare-backtick-path-chips` gate.** Fails if any `.md` path appears inside backticks but is NOT inside Markdown link syntax `](...)`. Implementation: small awk/grep script at `scripts/check-no-bare-paths.sh`. Allowlist file extensions and existing-file-name patterns that are intentionally not links (e.g., references to a SKILL.md filename in prose where the file isn't being linked).

## Conventions locked

These apply across all link rewrites in this hotfix and become the project standard going forward.

- **In-repo links** (within building-agentskills):
  - Format: Mintlify root-relative, no `.md`, no `docs/` prefix.
  - Example: `[Three questions](/03-three-questions)`.
  - Tradeoff: GitHub blob view 404s on these links. The deployed Mintlify site is the primary reader; GitHub readers are expected to navigate the file tree directly.
- **Cross-repo links** (to karpathy-wiki, agentskills, anthropics, obra/superpowers, etc.):
  - Format: absolute GitHub blob URL with branch name (typically `main`).
  - Example: `[plugin-root substitution wiki page](https://github.com/toolboxmd/karpathy-wiki/blob/main/wiki/concepts/claude-code-plugin-root-substitution.md)`.
- **Line-range anchors on cross-repo Markdown files:**
  - Format: append `?plain=1#L<start>-L<end>`. The `?plain=1` is required for GitHub to render Markdown with line numbers and apply the line-range highlight; without it, the Markdown is rendered as prose and the anchor is ignored.
  - Example: `[v2.2 spec doc lines 30–65](https://github.com/toolboxmd/karpathy-wiki/blob/main/docs/superpowers/specs/2026-04-24-karpathy-wiki-v2.2-design.md?plain=1#L30-L65)`.
- **Heading anchors within Mintlify pages:**
  - Format: auto-slug from heading text. Lowercase, spaces → hyphens, punctuation stripped.
  - Example: `## About these citations` → link as `/00-overview#about-these-citations`.
  - Avoid custom anchor syntax `{#custom-id}`: GitHub does not honor it in blob view.
- **External docs (Anthropic, agentskills.io, etc.):**
  - Unchanged. They are bare URLs in the prose; Mintlify auto-links them.

## Per-file change list

Line numbers reference the current state of the repo (commit `6180799` and later). All in-repo link rewrites follow the conventions above unless noted otherwise.

**Diff-scope rule (binding for the implementer):** the changes below are exhaustive. The implementer must:

1. Apply the prose rewrites and path-leak fixes named in this section. Do not invent additional rewrites beyond what is specified.
2. For every line where this spec says "convert in-repo backtick path chips to Mintlify-form links," the rule is: any backticked string of the form `` `docs/<...>.md` ``, `` `case-studies/<...>.md` ``, `` `examples/<...>.md` ``, or `` `<filename>.md` `` that is being used as a navigational pointer (i.e., a "see also" reference, not the topic of discussion) becomes a real Markdown link. Backticks around filenames being discussed as topics (e.g., "your `SKILL.md` should be under 500 lines") stay as backticks — they are code references, not links.
3. Do not reformat unrelated lines (line wrapping, trailing whitespace cleanup, prose tightening). Per `docs/10-anti-patterns.md` ("Subagent reformatting hazard"), the acceptable diff is the lines that had to change to satisfy this spec, nothing else. If unrelated improvements are noticed, report them in DONE_WITH_CONCERNS form rather than silently bundling.

### `docs/00-overview.md`

- **Line 60:** add the "what fires on it?" plain-English on-ramp. Replace the existing sentence with:
  > Decoration vs mechanism. Every threshold or invariant in your SKILL.md must answer one question: *if this rule is broken, what code will notice and stop the agent?* If the answer is "nothing — the agent decides," rewrite the rule into something concrete: a script, validator exit code, hook, or captured artifact. We use the shorthand "what fires on it?" for this question throughout the docs. Documented in [`07-mechanism-vs-decoration`](/07-mechanism-vs-decoration).
- **Lines 60–65:** convert backtick path chips throughout the "What Layer 3 adds" bullets to Mintlify-form links. Keep the numeric prefix in link text so the prose's number system stays coherent with the sidebar group labels.
- **Lines 87–93:** rewrite the entire `## Sources` block. New form:
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

  Cross-links: [README](https://github.com/toolboxmd/building-agentskills/blob/main/README.md), [`03-three-questions`](/03-three-questions).
  ```
  Note: README.md is not a Mintlify-rendered page (per `docs.json`); link out to GitHub for it.

### `docs/03-three-questions.md`

- **Lines 27–29:** add the on-ramp at the start of "Question 2: what fires on rules?" Insert a new sentence after line 29 (which ends "...what enforces the claim?"):
  > One-line plain-English form: *if this rule is broken, what code will notice and stop the agent?* If nothing — rewrite the rule. We shorten this question to "what fires on it?" everywhere it appears below.
- **Lines 31–34:** leave the bullets and surrounding prose unchanged. They now read with a definition behind them.
- **Lines 6, 7, 17, 18, 19, 23, 27, 34, 36, 38, 48, 50, 54, 55, 56, 58, 60, 78, 80, 81, 82, 84, 85, 86, 92, 96, 98, 100:** convert every bare-backtick `docs/...` chip and `karpathy-wiki/...` chip to a real Markdown link per the conventions above.
- **Line 90 (top of `## Sources`):** add a one-line back-reference:
  > See [Overview → Sources](/00-overview#sources) for what `LANDSCAPE`, `REVIEWER`, and `LESSONS` refer to.
- **Lines 90–98:** the existing source-bullet content stays as-is; the new back-reference handles the introduction.

### `docs/09-evolution.md`

- **Line 17:** delete the "Four cycles in six months." sentence. Surrounding text stays. New form of the paragraph:
  > Cycle cadence: typically per major-version ship. Karpathy-wiki ran the cycle for v2 (Tasks 1–29), v2-hardening (Tasks 30–44), v2.1 (missed-capture patch), and v2.2 (Tasks 50–62). Each cycle produced lessons that fed the next.
  No new timing claim is added.
- **Line 88:** convert the cross-links footer to real Mintlify links.

### `docs/10-anti-patterns.md`

- **Line 64:** in the `Skills depending on undocumented harness behaviors` evidence bullet, replace the trailing path reference. Current:
  > See `/Users/lukaszmaj/wiki/concepts/claude-code-plugin-root-substitution.md`.
  New:
  > See [the plugin-root substitution wiki page](https://github.com/toolboxmd/karpathy-wiki/blob/main/wiki/concepts/claude-code-plugin-root-substitution.md).
  This link only resolves after Step A merges.
- **Lines 5, 11, 17, 23, 29, 35, 41, 47, 53, 59, 65, 71, 98:** convert in-repo backtick path chips to Mintlify-form links.

### `docs/12-update-mechanism.md`

- **Line 11:** rewrite to use the glossary handoff. Current text references `LESSONS (/Users/lukaszmaj/dev/bigbrain/research/.../2026-04-24-lessons-from-v2.2-ship.md)`. New form:
  > The v2.2 lessons report — the document we cite as `LESSONS` (see [Overview → Sources](/00-overview#sources)) — is the seed instance of this format. It enumerates per-skill load-bearing analysis, patterns the existing meta-skills do not cover, the brainstorming-spec-plan-execute pipeline as gestalt, RED-GREEN-REFACTOR for prose, and case studies of reviewer-driven fix-ups. The shape is a reference for what a retrospective looks like.
- **Line 49:** same treatment for the landscape-report citation:
  > The v2.2 ship's landscape report — `LANDSCAPE` in our citations — is the seed instance. It enumerates state of the art, who is writing skill-authoring guides, the harness landscape, anatomy of a "good" skill, anti-patterns observed in the wild, the quality bar for 2026, source catalog.
- **Lines 15, 28, 42, 75, 83:** convert backtick path chips to Mintlify-form links.

### `docs/08-packaging-as-plugin.md`

- **Line 77:** rewrite. Current: `Source: REVIEWER G3, "wiki concept page references" (/Users/lukaszmaj/wiki/concepts/claude-code-plugin-root-substitution.md).` New:
  > Source: `REVIEWER` G3, ["wiki concept page references"](https://github.com/toolboxmd/karpathy-wiki/blob/main/wiki/concepts/claude-code-plugin-root-substitution.md).
- **Lines 47, 56, 69, 117:** convert in-repo backtick path chips to Mintlify links.

### `docs/11-cross-platform/claude-code.md`

- **Line 40:** rewrite. Current: `Source: REVIEWER G3; /Users/lukaszmaj/wiki/concepts/claude-code-plugin-root-substitution.md.` New:
  > Source: `REVIEWER` G3; [plugin-root substitution wiki page](https://github.com/toolboxmd/karpathy-wiki/blob/main/wiki/concepts/claude-code-plugin-root-substitution.md).
- **Lines 52, 74, 87, 88, 98:** convert in-repo backtick path chips to Mintlify links.

### `case-studies/2026-04-25-karpathy-wiki-v2.2.md`

- **Line 12:** rewrite. Current text references `LESSONS (/Users/lukaszmaj/dev/bigbrain/research/.../2026-04-24-lessons-from-v2.2-ship.md)`. New form:
  > The full retrospective lives in the document we cite as `LESSONS` (see [Overview → Sources](/00-overview#sources)). This case study is the public-audience version, written for readers who landed here from a search.
- **Line 33:** rewrite the architectural-decision citation with a working link and correct anchor format. Current: `(/Users/lukaszmaj/dev/toolboxmd/karpathy-wiki/docs/superpowers/specs/2026-04-24-karpathy-wiki-v2.2-design.md:30-65)`. New:
  > The architectural decision is documented in the [v2.2 spec doc, lines 30–65](https://github.com/toolboxmd/karpathy-wiki/blob/main/docs/superpowers/specs/2026-04-24-karpathy-wiki-v2.2-design.md?plain=1#L30-L65), with an explicit "Architectural decision: kill `sources/`" section and a job-vs-replacement table.
- **Lines 37, 75, 81, 87, 93, 109, 118, 124, 125, 126, 127, 128, 129, 130, 134, 153–159:** convert in-repo backtick path chips to Mintlify links; cross-repo references (e.g., karpathy-wiki commit SHAs in prose) get absolute GitHub URLs where they reference linkable artifacts.

### `README.md`

- Read during implementation. Convert any `/Users/` path strings (none expected per current audit, but verify) and any backtick path chips that should be links per the conventions above. Path-leak audit confirmed README.md has zero `/Users/` references at the time of this spec.

## CI gates (Step C)

### `scripts/check-no-bare-paths.sh`

A small Bash script that:

1. Greps `docs/`, `case-studies/`, `README.md` for backtick-wrapped strings ending in `.md`.
2. For each match, checks whether the surrounding context is Markdown link syntax (the path appears inside `](...)` with a leading `[text]`).
3. Exits 0 if all matches are inside link syntax; exits 1 with a list of violations otherwise.
4. Includes a small allowlist for legitimate non-link mentions (e.g., a discussion of "every plugin must have a `SKILL.md`" where `SKILL.md` is the topic, not a navigable target). Allowlist patterns documented inline in the script.

### `tests/run-all.sh`

Add two new check stanzas:

```bash
echo "Checking for absolute /Users/ paths..."
if grep -rn '/Users/' docs/ case-studies/ README.md; then
  echo "FAIL: absolute paths found"
  exit 1
fi

echo "Checking for bare-backtick path chips..."
bash scripts/check-no-bare-paths.sh
```

Wire these into the existing test harness so `npm test` (and any CI run) gates on them.

## Verification

### Pre-implementation sanity check

Before applying the bulk link rewrite, run `mintlify dev` locally and place one experimental link in the Mintlify root-relative form on a draft branch. Click it. If it 404s on the deployed-style URL, the convention is wrong and needs adjustment before the bulk rewrite. This is a five-minute check that prevents a 50-link-wide mistake.

### Per-file post-implementation verification

For each changed file:

1. Open the corresponding page on `localhost:3000` (Mintlify dev server).
2. Click every rewritten link. Confirm it lands on the expected target.
3. Read the changed prose blocks for tone consistency with surrounding text.
4. Confirm no `/Users/` strings remain anywhere on the page (visual check + the new CI gate).

### Cross-repo link verification

After Step A merges and Step B is on a draft branch:

- Open each cross-repo karpathy-wiki link. Confirm the GitHub blob view loads.
- For the v2.2 spec doc link with `?plain=1#L30-L65`, confirm GitHub renders the file with line numbers and highlights lines 30–65.

### CI gate verification

- Run `npm test` on the hotfix branch. Both new gates must pass.
- Manually introduce a violation (a `/Users/` path in a doc) and re-run. Confirm the gate fails and points at the offending file:line.

## Risks and known imperfections

### Window of broken external links between Step A and Step B

If Step A's PR sits unreviewed for an extended time, Step B's three karpathy-wiki external links 404 on the live docs site. Mitigation: keep Step A as a one-file PR for fast review; merge it immediately before Step B. If preferred, the implementer can gate Step B's merge on Step A's merge.

### `related:` frontmatter in the copied concept page references absent files

The copied `wiki/concepts/claude-code-plugin-root-substitution.md` has `related:` entries for `concepts/claude-code-skill-autoload-mechanisms.md` and `entities/claude-code-cli-agent-tool.md`. Neither file exists in `toolboxmd/karpathy-wiki/wiki/`. The fields are inert (YAML, not rendered as HTML links by GitHub or Mintlify), but a future tooling layer that walks `related:` fields would surface broken references. Decision: keep as-is per user direction; documented here as known imperfection.

### CI gate false-positive risk

The `check-no-bare-paths.sh` script must distinguish between:

- "Link this should be" → flagged as violation.
- "Discussion of the file in prose" → allowlisted.

The allowlist will need tuning over time. Initial set is conservative (only obvious topical mentions like `SKILL.md` and `plugin.json` when used generically); future false positives get added as encountered.

### Mintlify v4 URL prefix uncertainty

The conventions assume `/03-three-questions` is the correct URL form on the deployed site. The Mintlify v4 documentation supports this, but the deployed configuration could in principle differ. The pre-implementation sanity check (above) eliminates this risk.

## Out of scope (explicitly deferred)

- **Republishing private research docs (`LANDSCAPE`, `REVIEWER`, `LESSONS`).** The labels-glossary approach handles reader confusion without requiring document publication. Out of scope.
- **Sidebar group label cleanup.** The "05/06/11 missing from sidebar" perception is partially addressed by keeping numeric prefixes in body-text link text (so "Authoring" group / "05-…" prose still cross-reference cleanly). Renaming the sidebar groups themselves to include numeric prefixes (e.g., "05 Authoring") is a docs.json change that affects every page; out of scope for this hotfix, can be a follow-up if the cross-reference mismatch still confuses readers.
- **Source-document version stamping.** The "v0.2 idea" of citation pinning (commit SHA, document hash, retrieval date) is out of scope. The labels-glossary handles introduction; version stamping is for a future ship.
- **Cross-repo seed wiki feature for karpathy-wiki.** Step A adds one file. The broader question of whether `toolboxmd/karpathy-wiki` should ship with a fully seeded `wiki/` directory as canonical example content is a karpathy-wiki design question, not a building-agentskills hotfix question. Tracked separately if desired.

## Acceptance criteria

The hotfix is done when:

1. `grep -rn '/Users/' docs/ case-studies/ README.md` returns zero matches.
2. The new CI gates pass (`npm test`).
3. Visual walkthrough on `localhost:3000` confirms every rewritten link lands on the right target.
4. The deployed site at building-agentskills.toolbox.md (after Step B merges) shows clean `Sources` blocks, working cross-page links, the new "About the citations" glossary in 00-overview, the on-ramped "fires on it" definition in 03-three-questions, and the trimmed 09-evolution paragraph.
5. The companion karpathy-wiki PR is merged and the cross-repo links resolve.

## Sources

- User report (image-attached deployment review, 2026-05-06).
- Audit grep across `docs/`, `case-studies/`, `README.md` (9 path-leak occurrences across 6 files identified).
- Mintlify v4 link-resolution research (root-relative recommended; `.md` extension dropped on deploy).
- GitHub Markdown line-range anchor spec (`?plain=1#L<n>-L<m>` format).
- File reads of all affected docs at commit `6180799`.
