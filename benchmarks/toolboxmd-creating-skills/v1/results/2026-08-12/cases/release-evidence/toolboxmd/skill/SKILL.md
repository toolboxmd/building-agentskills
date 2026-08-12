---
name: drafting-evidence-backed-releases
description: Draft public release notes from an evidence bundle containing implementation, acceptance, plan, rejection, failure, or observation records. Use when release communication must keep claims traceable, scoped, and candid about unsupported requests. Do not use to decide whether code ships, alter evidence status, invent user impact, publish content, or enforce a publication gate.
---

# Draft evidence-backed releases

Turn supplied evidence into a publication-ready **draft**, not a shipping decision or publication action. Work offline from the current bundle only. Do not rely on memory, earlier drafts, another agent, or unstated product knowledge.

## Required inputs

Require:

- an evidence bundle whose records have stable identifiers, types, statuses, summaries, and any relevant scope or environment;
- the requested release claims or release-note objective; and
- the local writing contract, if one is supplied.

Treat a supplied writing contract as authoritative for citation syntax and evidence use. If it conflicts with this skill, follow the supplied contract while preserving the boundaries below.

## Default path

1. Inventory every evidence record without changing its status.
2. Split the requested message into atomic claims. Separate what changed, an observed result, a user benefit, a performance statement, a guarantee, and future work rather than allowing one supported phrase to carry an unsupported phrase.
3. Classify each claim with the procedure below.
4. Draft only supported claims, retaining material scope and measurement qualifiers.
5. Put every requested but unusable claim in `Withheld or unsupported claims`; never silently omit uncertainty.
6. Audit each release-note bullet against its cited records, then return exactly the two required sections.

## Evidence hierarchy

Apply this order; a lower class cannot substitute for a higher one:

1. **Shipped implementation record:** supports what changed, only within its stated feature scope. It does not by itself prove a benefit, reliability, performance, or behavior in an unmentioned environment.
2. **Passed acceptance artifact:** supports only the observed result, setup, environment, sample, and measurement boundaries recorded in that artifact. It does not automatically generalize to production or other platforms, inputs, or repetitions.
3. **Explicit inference from usable evidence:** may be included only when the writing contract permits it, it is useful, and it is labeled as an inference rather than a measured fact. Cite its supporting records. Default to withholding inferred user benefits when the request merely asks for broader or more exciting language.
4. **Plan, rejected proposal, failed result, unverified observation, or assertion without usable evidence:** cannot support a shipped public claim. Withhold it with its identifier when available and explain why.

More evidence identifiers do not cure a semantic mismatch. A shipped commit plus a narrow acceptance result still cannot support an unlimited guarantee.

## Claim-classification procedure

For each atomic claim:

1. **Resolve identity and status.** Find the exact record identifiers. If a required public claim has no stable identifier, stop and request evidence. If records conflict about status, stop and request resolution; do not select the convenient status.
2. **Match meaning.** Compare the claim's subject, action or result, scope, environment, population or fixture, sample size, measurement, and certainty with the records.
3. **Assign one class:**
   - `supported change` — a shipped implementation record directly establishes the scoped change;
   - `supported observed result` — a passed acceptance artifact directly establishes the stated observation and conditions;
   - `labeled inference` — usable evidence supports a clearly marked inference, without presenting it as measured fact;
   - `withheld` — evidence is planned, rejected, failed, unverified, missing, uncited, contradicted, or too narrow for the requested wording;
   - `blocked` — a required identifier is missing or source statuses conflict.
4. **Narrow before discarding.** If the evidence supports a smaller truthful claim, draft that narrower claim and list the broader requested claim as withheld with the gap. Do not turn “implemented” into “improved,” a single fixture into universal reliability, or an impression into a measured speedup.
5. **Cite support, not context.** Use only identifiers in the supplied bundle that actually support the sentence. Never cite a plan, rejection, failed result, or unverified observation as support for a shipped claim.

## Qualifiers

Keep every qualifier that materially bounds truth, including:

- feature or source scope;
- operating system or execution environment;
- synthetic versus production data;
- fixture or population size;
- number and kind of trials, interruptions, or observations; and
- whether a statement is observed, measured, inferred, planned, or guaranteed.

Place qualifiers in the claim itself, not only in the citation or withheld explanation. Prefer a narrow useful sentence over a broad benefit statement. Never imply that absence of duplicate records in one test proves zero data loss, production reliability, or behavior across all import sources.

## Citation rules

End every factual release-note bullet with exactly one citation group in this form:

```text
[evidence: ID, ID]
```

Use the exact stable identifiers from the current evidence bundle, separated by a comma and one space. Put no prose or punctuation after the citation group. One identifier is valid, for example `[evidence: COMMIT-CA-184]`. Cite one or more records sufficient for the whole bullet. If a bullet contains claims with different support, split it.

The withheld section must name available identifiers and give the reason, but its entries are not public release-note claims and need not end in a support citation group.

## Output contract

Return these two sections in this order, even when one has no substantive entries:

```markdown
## Release notes

- <narrow factual public claim> [evidence: ID]

## Withheld or unsupported claims

- Claim: <requested claim>
  Reason: <specific missing, conflicting, unusable, or scope-limited evidence; include relevant ID when available>
```

Use `- None.` when a section has no entries. Do not put plans, caveats masquerading as claims, or unsupported marketing language in `Release notes`. Do not hide an unsupported part of a compound request after drafting its supported part.

## Stop conditions and boundaries

Stop the affected drafting work and request evidence or resolution when:

- a required public claim lacks a stable evidence identifier;
- source records conflict about status; or
- the evidence bundle or applicable writing contract is missing or unreadable.

Withhold rather than stop the entire draft when an optional requested claim is merely planned, rejected, failed, unverified, contradicted, or broader than its evidence. Continue with independently supported claims.

Do not decide whether code is safe or ready to ship, change an evidence record or status, manufacture identifiers, infer unstated user impact, execute publication, or claim that this draft is approved. If asked to do one of these, state the boundary and provide only the in-scope evidence-backed draft when possible.

## Review versus enforcement

This procedure performs **semantic review**: it asks an agent to judge whether prose is actually supported and properly qualified. That judgment is advisory. This `SKILL.md` cannot prevent a person, agent, or publishing tool from ignoring it or publishing unsupported text.

A deterministic structural checker may flag a missing citation group, malformed identifier syntax, or an identifier absent from a supplied register. It cannot decide that a cited record semantically proves the prose.

Use an external mechanism when failure must block a lifecycle action:

- a pre-commit or editor hook for immediate structural feedback;
- a CI citation check in a protected workflow to reject mechanically invalid artifacts;
- a required human approval gate for semantic sign-off; or
- publishing-system permissions or an external publishing control to prevent unapproved release.

Hard enforcement requires the relevant mechanism to run on the publication path and fail closed. Even then, semantic truth still requires evidence-aware review unless the rule is fully deterministic.
