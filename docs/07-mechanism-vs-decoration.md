# Mechanism vs decoration: the strongest single signal

Every threshold, invariant, or rule in your SKILL.md is either decoration or mechanism. Decoration is fine for guidance prose. For invariants (words like "must," "always," "never," numeric thresholds), decoration is a wish; mechanism is a contract. This page is the standalone deep dive on the rule, the audit method, and the v2.2 case studies that prove the rule is load-bearing.

This is Question 2 of the hero framework (`docs/03-three-questions.md`). The auditor named the pattern "decoration vs mechanism" and called it "the strongest signal for what v2.2-hardening should fix" (`karpathy-wiki/docs/planning/2026-04-24-karpathy-wiki-v2.2-audit.md:366`).

## The rule (sharpened)

Source: `REVIEWER` "Stress test of the decoration vs mechanism headline," Recommendation closing.

> Every threshold, invariant, or rule in your SKILL.md is either decoration (the agent reads it and decides whether to act) or mechanism (a script, validator exit code, hook, or captured artifact fires on it). Decoration is fine for guidance prose. For invariants (words like "must," "always," "never," numeric thresholds), decoration is a wish; mechanism is a contract. Any line containing "must" or a numeric threshold should answer the question "what fires on this if violated?" If the answer is "the agent decides," rewrite as guidance or wire to a mechanism.

The audit method: grep your SKILL.md for "must," "always," "never," and any digits. For each hit, ask "what fires on this if violated?" If the answer is "the agent decides," wire it.

The four mechanism flavors:

- **Script.** A subprocess that does the work and returns exit codes. Wiki-manifest.py validate is one of these.
- **Validator exit code.** A linter or validator returning non-zero on violation. The skill checks the exit code and acts.
- **Hook.** A harness-side event handler (PreToolUse, PostToolUse, Stop). Hooks are the canonical "block the tool call before it runs" mechanism.
- **Captured artifact.** A file whose presence or content the next turn checks. Karpathy-wiki's `.wiki-pending/` files are this shape; the next turn's "check pending captures" loop fires on them.

If a rule cannot be wired to one of these four, it is decoration. Decoration is fine for guidance ("when in doubt, prefer simpler"); it is dangerous for invariants ("the manifest origin must never be empty").

## Three karpathy-wiki v2.2 wirings

Each one is decoration becoming mechanism. Each one cites the v2.2 commit that did the wiring.

### Wiring 1: index-size threshold (commit `dabf10a`, finalized in `0e0f815`)

Source: `LESSONS` 2.1.

Pre-v2.2 SKILL.md said:

> Split or atom-ize `index.md` when it exceeds ~200 entries / 8KB / 2000 tokens. Orientation degrades beyond that.

This was decoration. The agent read the line and decided whether to act. The live wiki was 25 KB (3x over the 8 KB threshold). Across 30+ ingests, zero schema-proposal captures fired. The decoration-form invariant was a wish that the agent never granted.

v2.2 wired the threshold to ingest step 7.6:

```bash
size="$(wc -c < "${WIKI_ROOT}/index.md" | tr -d ' ')"
if [[ ${size} -gt 8192 ]]; then
    recent="$(find "${WIKI_ROOT}/.wiki-pending/schema-proposals" -name '*-index-split.md' -mtime -1 2>/dev/null | head -1)"
    if [[ -z "${recent}" ]]; then
        ts="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
        cat > "${WIKI_ROOT}/.wiki-pending/schema-proposals/${ts}-index-split.md" <<EOF
...
EOF
    fi
fi
```

The `wc -c` measures size. The `[[ ${size} -gt 8192 ]]` fires on the threshold. The `cat > ...` writes a schema-proposal capture file. The mechanism is bash, the artifact is the capture file, and the next turn's "check pending captures" loop will surface it.

Decoration-form: "agent should split when over 8 KB."  
Mechanism-form: "bash measures, bash writes capture, next turn sees capture, schema proposal happens."

The threshold is now a contract. The 25 KB wiki produces a capture; the agent cannot rationalize past it.

The first version of this wiring shipped with two silent correctness bugs (heredoc indent leak, `wc -c` whitespace). The reviewer caught them in `0e0f815`. The bugs are documented in `docs/05-authoring/prose-discipline.md`.

### Wiring 2: manifest origin contract (commit `36f0aa8`, Iron Rule strengthened in `d325dda`)

Source: `LESSONS` 2.1.

Iron Rule #7 (pre-v2.2 SKILL.md line ~287) enumerated valid `origin` values: `"file"`, `"mixed"`, evidence-type, absolute path. It did not enumerate the empty string. Two live entries (`raw/2026-04-24-copyparty-serve-deny-limits.md`, `raw/2026-04-24-yazi-install-gotchas.md`) had `"origin": ""`; outside the rule's enumeration but accepted by the validator (which never checked origin).

Decoration-form: "Iron Rule #7 enumerates valid origins."  
The validator was decoration too; it did not check.

v2.2 added `wiki-manifest.py validate` (commit `36f0aa8`) returning exit 1 on empty/typename/relative-path origins. SKILL.md Iron Rule #7 strengthened in commit `d325dda` to enumerate the empty string explicitly.

Mechanism-form: "validator exits 1 on bad origin; commit gate refuses to run if validator non-zero."

The Iron Rule is now backed by a script with an exit code. The empty-origin regression cannot recur silently; the validator catches it.

### Wiring 3: validator-blocks-commit (commit `d325dda`, paired with code-block-link skip fix `f72bfc3`)

Source: `LESSONS` 2.1.

Pre-v2.2 SKILL.md ingest step 12 said:

> Do NOT commit a wiki state where the validator fails.

This was decoration. The audit (Finding 04) traced 7 broken links in 5 live pages to the ingester emitting `## [...] ingest |` log lines without follow-up validator-failure log lines. The success log fired before the validator was consulted (or its failure was ignored).

v2.2 strengthened the prose to:

> the ingester MUST NOT call `wiki-commit.sh` if the validator exits non-zero for any touched page.

This is still mostly prose. The mechanism here is the existing validator (`wiki-validate-page.py`) plus the strengthened SKILL.md rule that the ingester reads and complies with. Wiring 3 is the weakest of the three; it is closer to "tighter decoration" than to full mechanism. The pairing with `f72bfc3` (code-block-link skip fix) reduces the false-positive rate so the validator's signals are trustworthy when the rule fires.

The full wiring would be: a hook on the ingester's commit step that runs the validator and blocks the commit on non-zero exit. v2.2 did not implement that; the strengthened prose is the interim step. A future ship could add the hook.

This is honest evidence that the decoration-vs-mechanism rule is a spectrum, not a binary. Sometimes you wire fully; sometimes you wire partially; "tighter decoration plus a future-ship plan to wire fully" is acceptable when the cost of the full mechanism is not yet justified.

## The audit method

For your own SKILL.md:

1. Grep for "must," "always," "never," and any digits.
2. For each hit, write down "fires on: [name of script / validator / hook / captured-artifact]."
3. Anything that resolves to "the agent decides" is decoration.
4. For each decoration, decide: rewrite as guidance (if it is not actually an invariant) or wire to a mechanism (if it is).

The rewrite-as-guidance path is legitimate. Not every must-statement is an invariant. "When in doubt, prefer the simpler approach" reads like a rule but is actually guidance; it is fine as decoration. The audit forces you to make the choice consciously.

## `paths:` glob as activation gate (decoration vs mechanism in reverse)

Source: `REVIEWER` G8.

The Claude Code `paths:` frontmatter field accepts glob patterns that limit when a skill activates: "Glob patterns that limit when this skill is activated. Accepts a comma-separated string or a YAML list. When set, Claude loads the skill automatically only when working with files matching the patterns."

This is decoration-vs-mechanism in reverse. A skill author can mechanically gate their skill's activation by file paths, instead of relying on description-keyword matching (which is a softer gate). For example, karpathy-wiki could declare `paths: ["**/*.md"]` to ensure it only auto-loads in markdown contexts.

The mechanism-form (`paths:` glob) is more reliable than the decoration-form (description triggers); the harness handles the gating. The trade-off: `paths:` is Claude Code only; description triggers work everywhere.

## When decoration is the right answer

Not every rule should be wired to a mechanism. Decoration is the right answer when:

- The rule is guidance, not an invariant. "Prefer X over Y" is guidance; "must use X" is an invariant.
- The mechanism cost exceeds the violation cost. A nightly batch job that reports drift is enough; you do not need a real-time validator.
- The mechanism is not yet built. Strengthening the prose is the interim step; the full mechanism comes in a future ship.

The audit's question is not "is every rule a mechanism?" but "is every rule that should be a mechanism, a mechanism?" The answer is sometimes "no, and that is fine." But the answer must be conscious.

## Sources

- `LESSONS` 2.1 (the three v2.2 wirings; commits `dabf10a`, `36f0aa8`, `d325dda`).
- `REVIEWER` "What the analyzer got right" #4 (decoration-vs-mechanism is named in the audit; not in superpowers / agent-skills / Anthropic docs).
- `REVIEWER` "Stress test of the decoration vs mechanism headline" (the sharpened framing used in this doc).
- `REVIEWER` G8 (`paths:` glob as activation gate).

Cross-links: `docs/03-three-questions.md` (Q2), `docs/10-anti-patterns.md` (decoration without mechanism is the headline anti-pattern), `case-studies/2026-04-25-karpathy-wiki-v2.2.md` (the three wirings as ship narrative).
