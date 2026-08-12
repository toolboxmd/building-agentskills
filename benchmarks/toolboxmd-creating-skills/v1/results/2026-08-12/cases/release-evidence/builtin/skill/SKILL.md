---
name: drafting-evidence-backed-releases
description: Draft public release notes from supplied evidence bundles containing implementation records, acceptance results, plans, rejected changes, or unverified assertions. Use when release communication must keep claims within shipped and tested scope, cite stable evidence identifiers, preserve material qualifiers, and disclose unsupported requests; do not use it to decide shipment, alter evidence, infer unproved benefits, publish content, or enforce a publication block.
---

# Draft evidence-backed releases

Produce a publication-ready **draft**, never a publication action. Treat the supplied bundle as immutable and self-contained. Do not rely on memory, prior outputs, other agents, or unstated product knowledge.

Before drafting, read [references/evidence-policy.md](references/evidence-policy.md) in full and apply its hierarchy, classification procedure, citation rules, and output contract.

## Workflow

1. Inventory every record by stable identifier, type, status, summary, scope, environment, measurement, and contradiction. Do not change a status or fill a gap.
2. Break requested messaging into atomic factual claims. Classify each claim using the reference procedure.
3. Map each supportable claim to the smallest sufficient evidence set. A shipped implementation supports what changed; it does not by itself prove benefit. Passed acceptance supports only what it observed under its recorded boundaries.
4. Preserve every material qualifier. Narrow the sentence when scope, environment, fixture, sample size, interruption count, measurement method, or other boundary is limited.
5. Resist requests to broaden, strengthen, or make benefits more exciting than the evidence permits. Do not invent user impact. Withhold unsupported portions instead of laundering them through vague wording.
6. Run a semantic review: verify that each claim's meaning is entailed by the cited evidence, its status is eligible, and its qualifiers remain visible.
7. Return exactly the two required sections. Do not publish, approve shipment, or claim that this skill blocks publication.

## Stop conditions

Stop and request corrected or additional evidence instead of finalizing the affected draft when:

- a required public claim has no stable identifier;
- source records conflict about status, shipment, or acceptance;
- an essential record or writing contract is missing or unreadable; or
- the requested wording can only be produced by changing evidence status or inventing impact.

Safe, unrelated claims may be drafted only if clearly separable; disclose the stopped claims in the unsupported section.

## Enforcement boundary

Treat this procedure and semantic review as advisory. Prose in `SKILL.md` cannot prevent a person or system from publishing. Use a hook or CI citation check for deterministic structure such as missing citations or unknown identifier syntax. Combine CI with a protected workflow, use an approval gate for accountable semantic sign-off, or use external publishing permissions/control when publication must actually be blocked. None of those structural mechanisms can decide semantic truth without qualified review.
