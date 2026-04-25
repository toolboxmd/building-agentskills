# Iron Laws and the four canonical discipline-prose patterns

This page covers the patterns superpowers added on top of the agent-skills spec for discipline-shaped skills. Layer 2 conventions, all four. None of them are required by the spec; all four are observably effective for skills that need to reliably steer agent behavior.

The patterns:

1. Iron Law (block-quoted code-fenced single sentence).
2. Forbidden-rationalization table (`| Excuse | Reality |`).
3. Red Flag list ("STOP and Start Over").
4. Spirit-vs-letter clause.

Each pattern with one example from karpathy-wiki SKILL.md.

## Iron Law

A non-negotiable rule. Single sentence, all-caps (or close to it), no exceptions, block-quoted with code-fence styling so it visually stands out from prose.

The shape:

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Each Iron Law is one sentence. No qualifiers. No "in most cases." No "unless." If you find yourself wanting to add an exception, the Iron Law is the wrong shape; it should be a guideline.

### Karpathy-wiki Iron Laws

From `karpathy-wiki/skills/karpathy-wiki/SKILL.md` lines 48-60:

```
NO WIKI WRITE IN THE FOREGROUND
```

```
NO PAGE EDIT WITHOUT READING THE PAGE FIRST
```

```
NO SKIPPING A CAPTURE BECAUSE "IT DOESN'T LOOK WIKI-SHAPED"
```

Three Iron Laws. Each one is a sentence. Each one is exception-free. The agent reading the skill should understand each one as a hard constraint, not a default-with-exceptions.

The fourth, called out separately at line 51 ("Iron Rule #7" in the rules section of the same file), reinforces the manifest-origin contract: never set `.manifest.json` `origin` to `"file"`, `"mixed"`, the evidence type, the empty string, or a relative path.

## Forbidden-rationalization table

A two-column markdown table. Left column: verbatim rationalizations the agent might produce under pressure. Right column: the counter to each.

The table is built from observation, not invention. You write down the actual rationalizations you saw in pressure tests or in production failures, then write the counter. Inventing rationalizations does not work; the agent will produce different ones than you guessed.

### Karpathy-wiki rationalization table

From `karpathy-wiki/skills/karpathy-wiki/SKILL.md` lines 435-458 (excerpt; the full table has 16 rows):

```
| Rationalization | Reality |
|---|---|
| "The user will remember this / it's obvious from context" | The user won't; context evaporates. That's the whole point of the wiki. |
| "It's too trivial for the wiki" | If it meets the trigger criteria, capture it. Lint filters noise later. |
| "I'll capture it later / I'm mid-task" | Later means never. Capture is milliseconds. Do it now. |
| ... | ... |
| "I have a good reason to skip this capture" (any rationalization not literally in this table) | Cite the exact SKILL.md line that justifies skipping. If you cannot quote it, you are fabricating. Capture now. |
```

The last row is a meta-row that catches any rationalization not enumerated. It is the spirit-vs-letter clause folded into the table.

The table grows over time. Each ship that surfaces a new rationalization adds a row. v2.1 added "this looks like casual chat / there's no code here / this isn't a wiki context"; v2.2 added the empty-origin and `needs_more_detail` rejection clauses.

## Red Flag list

A bulleted list of thought patterns the agent should recognize as signaling a violation in progress. Each red flag closes with a single action: STOP, expand, capture, etc.

The list is written from the agent's first-person perspective (paradoxically; this is the one place first-person is allowed because the agent is recognizing its own thought).

### Karpathy-wiki red flag example

From `karpathy-wiki/skills/karpathy-wiki/SKILL.md` lines 175-181:

```
### Red flags. STOP and expand the body.

- Capture body under the floor for its evidence_type.
- Numbers rounded away or dropped ("roughly 20 req/min" when the source said exactly 20).
- A "see conversation for full context" or "the user can fill in specifics" phrase appears anywhere.

All of these mean: expand the body before spawning the ingester.
```

Three red flags. One unified action: expand. The bulleted format is the recognition cue; the closing line is the response.

## Spirit-vs-letter clause

A single sentence that closes the loophole "but I followed the letter of the rule." The clause makes the spirit of the rule normative; it forbids rationalization-by-technicality.

The shape:

> Violating the letter of the rules is violating the spirit of the rules.

Or, in the karpathy-wiki shape:

> "I have a good reason to skip this capture" (any rationalization not literally in this table). Cite the exact SKILL.md line that justifies skipping. If you cannot quote it, you are fabricating.

The cure for the technicality loophole is to require explicit citation. If the agent must quote the line that authorizes the deviation, the agent cannot rationalize without leaving evidence.

## When to use which pattern

- **Iron Law.** For absolute invariants. Use sparingly; three Iron Laws are powerful, twenty are noise. Karpathy-wiki has three plus one strengthened rule.
- **Rationalization table.** When you have observed real rationalizations in pressure testing or production. Do not invent rows; observe them.
- **Red Flag list.** For thought patterns the agent should recognize as warning signs. Use when the violation has a recognizable upstream signature.
- **Spirit-vs-letter clause.** Use once per skill, near the rationalization table. It is the meta-rule that protects all the others.

Every Iron Law begs a mechanism question. "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST" is decoration unless something fires when production code lands without a failing test (a hook, a CI check, a pre-commit gate). See `docs/07-mechanism-vs-decoration.md` for the audit method.

## Sources

- `LANDSCAPE` 1.2 (superpowers patterns).
- `LANDSCAPE` 3.4 (the five canonical patterns: this doc covers four; the fifth, the "Don't X. Don't Y. Don't Z." enumeration, is folded into the rationalization table).
- `KP-SKILL` lines 48-60 (Iron Laws block).
- `KP-SKILL` lines 435-458 (rationalization table).
- `KP-SKILL` lines 175-181 (red flag list).

Cross-links: `docs/07-mechanism-vs-decoration.md` (every Iron Law begs a mechanism question).
