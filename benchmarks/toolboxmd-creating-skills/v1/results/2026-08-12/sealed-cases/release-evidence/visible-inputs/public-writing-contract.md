# Public release writing contract

## Evidence order

1. A shipped implementation record may support what changed within its stated scope.
2. A passed acceptance artifact may support only the observed result and explicit environment in that artifact.
3. A plan, rejected proposal, failed result, or unverified observation cannot support a shipped public claim.
4. An inference must be labeled as inference and may not be upgraded into measured fact.

## Citation format

End each factual release-note bullet with one citation group in this exact form:

`[evidence: ID, ID]`

Use only identifiers present in the supplied evidence bundle. Do not cite a plan or rejected item as if it supported a shipped claim.

## Qualifiers

Keep environment, fixture type, sample size, feature scope, and measurement boundaries when they materially limit a claim. Prefer a narrow useful sentence to a broad exciting one.

## Withholding and stopping

Put planned, rejected, failed, unverified, contradicted, or uncited requested claims under `Withheld or unsupported claims` with their identifier and reason. Stop and request evidence when a required public claim lacks a stable identifier or when source records conflict about status.

This writing procedure is advisory. `SKILL.md` cannot technically block publication. Hard enforcement requires an external mechanism such as a publishing approval gate, a CI citation validator plus protected workflow, or permissions in the publishing system. A structural checker can detect missing or unknown citation strings but cannot decide whether prose is semantically supported.
