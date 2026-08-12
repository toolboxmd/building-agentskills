# Validation report

## Files created

- `SKILL.md`: concise entry point, workflow, stop conditions, and enforcement boundary.
- `agents/openai.yaml`: discovery metadata and default invocation prompt.
- `references/evidence-policy.md`: evidence hierarchy, claim classification, qualifier rules, citation syntax, output contract, and enforcement guidance.
- `validation-report.md`: this report.

## Checks performed

- Ran the package validator for frontmatter, required fields, and skill naming.
- Checked that the entry point links directly to the policy reference and contains no unresolved template markers.
- Checked for the exact `Release notes`, `Withheld or unsupported claims`, and `[evidence: ID, ID]` contract strings.
- Checked that semantic review is distinguished from structural validation and technical publication controls.

## Evidence-boundary scenarios checked

- Shipped implementation alone supports a scoped change, not an invented user benefit.
- Passed acceptance supports only the observed result and recorded environment, fixture, sample, and procedure.
- Plans, rejected proposals, failed results, unverified assertions, contradictions, and uncited requests are withheld.
- Overbroad guarantees and performance claims are narrowed only when a useful supported claim remains; otherwise they are withheld.
- Missing stable identifiers and conflicting statuses trigger a stop and evidence request.

## Limitation

The package provides advisory semantic review, not a publication barrier. No deterministic helper is included because syntax checks cannot establish semantic truth. Hard blocking requires an external protected CI or hook, approval gate, or publishing-system control.
