# Aster weekly status deck contract

Use this contract when the user asks to create or update a leadership status deck from weekly notes.

## Artifact format

Write results under `output/` and do not modify source files.

Create `output/status-deck.md` as Marp Markdown with exactly this frontmatter:

```yaml
---
marp: true
theme: default
paginate: true
footer: Aster Weekly | Internal
---
```

Create exactly five slides separated by `---`. Use exactly these slide headings in order:

1. `# Aster Weekly Status`
2. `# Outcomes`
3. `# Work in progress`
4. `# Risks`
5. `# Decisions and asks`

The title slide must include the reporting range in ISO dates.

## Status vocabulary

- `DONE`: verified completed work.
- `ON TRACK`: in-progress work with no stated blocker.
- `BLOCKED`: work that cannot proceed because of a stated dependency.
- `UNCONFIRMED`: an observation without a comparable baseline or sufficient evidence.

Do not replace these labels with synonyms.

## Evidence and claims

- Every factual bullet ends with its bracketed source identifier, such as `[W3]`.
- Preserve numeric qualifiers and time comparisons.
- A current measurement without a comparable baseline is `UNCONFIRMED`; do not call it an improvement or trend.
- An `[IDEA]` without evidence is not a factual outcome and must not appear in the deck.
- Never invent a result, owner, date, budget, comparison, or confidence level.

## Validation receipt

Create `output/deck-check.json` with exactly these keys:

- `schema_version`: integer `1`
- `slide_count`: integer count
- `required_sections`: the five slide headings without `#`, in order
- `evidence_ids`: unique identifiers used in the deck, sorted numerically
- `unsupported_claims`: integer count, which must be `0`
- `checks`: exactly `frontmatter`, `slide-order`, `evidence`, and `claim-boundary` in that order

Before finishing, verify frontmatter, slide count and order, every factual bullet's evidence marker, preserved qualifiers, and absence of unsupported ideas.
