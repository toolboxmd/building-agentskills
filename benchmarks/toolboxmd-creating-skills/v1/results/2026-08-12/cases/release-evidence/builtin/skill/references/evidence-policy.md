# Evidence policy and output contract

Apply this file to each supplied evidence bundle. Use only the bundle and any local public-writing contract supplied with the task.

## Evidence hierarchy

Use evidence in this order without upgrading a lower class:

1. **Shipped implementation record:** support only what changed, within its stated feature and platform scope.
2. **Passed acceptance artifact:** support only the observed result, environment, fixture, sample, procedure, and measurement boundaries recorded by the artifact.
3. **Labeled inference:** include only when the cited eligible evidence reasonably supports the inference, label it explicitly as an inference, and never restate it as measured fact.
4. **Non-supporting record:** a plan or unshipped item, rejected proposal, failed result, unverified observation/assertion, contradicted record, or status-unknown item cannot support a shipped public claim.

Stronger evidence does not erase its boundaries. Combine a shipped implementation record with passed acceptance evidence when a sentence states both what changed and an observed result. Never use a citation merely because its wording resembles the claim.

## Claim-classification procedure

Split proposed copy into atomic claims, then classify each one independently:

| Class | Required support | Treatment |
| --- | --- | --- |
| Implementation fact | Shipped implementation record that directly states the change and scope | Draft narrowly; cite the record. |
| Observed result | Passed acceptance artifact that directly records the result and conditions | State as a bounded observation; cite the artifact and the shipped record too if the same claim also asserts availability. |
| Inference | Eligible cited evidence plus a reasoning step that does not contradict its boundaries | Label “inference” or equivalent; preserve boundaries; do not turn it into a measurement. |
| Unsupported or withheld | Only planned, unshipped, rejected, failed, unverified, contradicted, unknown-status, uncited, or semantically irrelevant support | Exclude from release notes; list the claim and reason. |

For every claim:

1. Identify the exact proposition: subject, change or outcome, scope, population/environment, and degree of certainty.
2. Locate stable identifiers whose contents directly support that proposition.
3. Check type and status against the hierarchy. Citation presence alone is not support.
4. Compare wording with evidence for semantic expansion: guarantees, universality, production reliability, performance, causality, availability, or user benefit require direct support.
5. Carry forward material qualifiers. If narrowing would make the claim misleading or useless, withhold it.
6. Classify mixed sentences by their weakest unsupported proposition; preferably split them into atomic bullets.

Do not reinterpret a failed test as support, a plan as shipped work, a rejected guarantee as permission for a softer guarantee, or an impression as a measurement. Do not change source status. When the user requests broader benefits than the evidence supports, default to the narrow supported wording and withhold the remainder.

## Qualifier handling

Retain any boundary that could change a reasonable reader's interpretation, including:

- feature or import-source scope;
- operating system, test runner, or environment;
- synthetic versus production data;
- fixture type and sample size;
- number and kind of interruptions, trials, or observations;
- measured versus perceived behavior;
- exclusions such as platforms, reliability, rollback, or performance not tested.

Place qualifiers in the claim itself, not only in the citation or unsupported section. Avoid “all,” “always,” “guaranteed,” “zero loss,” “faster,” “reliable,” or similar expansions unless eligible evidence directly establishes that wording and scope.

## Evidence citations

End each factual release-note bullet with exactly one citation group in this form:

`[evidence: ID, ID]`

Replace each `ID` with a stable identifier present in the supplied bundle. Use one or more identifiers, separated by a comma and one space. Put the group at the very end of the bullet. Do not cite plans, rejected items, failed results, or unverified observations as support for shipped claims. Each identifier must support the meaning of the claim, not just be known to the bundle.

## Downstream output contract

Return exactly these two top-level sections in this order:

```markdown
## Release notes

- <one narrow factual claim> [evidence: ID]

## Withheld or unsupported claims

- Claim: <requested claim>
  Evidence: <relevant ID or “no stable identifier supplied”>
  Reason: <specific status, conflict, missing support, or scope mismatch>
```

Under `Release notes`, use atomic bullets and cite every factual claim. If none are supportable, write `None.` Do not turn unsupported material into narrative, a footnote, or an uncited caveat.

Under `Withheld or unsupported claims`, include every requested planned, rejected, failed, unverified, contradicted, uncited, or overbroad claim. Give the claim, any relevant identifier, and a precise reason. If none were withheld, write `None.` Do not hide uncertainty or omit an unsupported request merely to make the draft look cleaner.

## Semantic review versus hard enforcement

Perform semantic review by comparing the meaning and qualifiers of prose with the actual cited records. A deterministic structural checker may flag absent/malformed citation groups, identifiers not found in the bundle, or missing required headings. It cannot establish that evidence entails a claim, that a qualifier is sufficient, or that prose is true.

This workflow is advisory and cannot itself stop publication. Require a repository hook or CI check when citation structure must be machine-checked; protect the workflow so failures cannot be bypassed. Require an approval gate when a qualified person must accept semantic support. Require permissions or another control in the external publishing system when unauthorized publication must be technically prevented.
