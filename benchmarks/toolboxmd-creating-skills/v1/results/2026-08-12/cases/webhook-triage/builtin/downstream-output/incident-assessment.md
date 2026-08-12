## Classification
`signature-integrity` — `signature_check` is `failed`. The HTTP `429` is a secondary observed symptom and does not change the higher-precedence classification.

## Priority
`P1`

## Next action
Keep automatic retries stopped and the delivery quarantined. The endpoint owner should verify the active signing-key identifier, but this assessment does not contact the endpoint owner, change a signing key, or perform live remediation.

## Retry guidance
`not retry eligible` — do not retry in two minutes. The supplied `retry_after_seconds` value of `120` does not override the signature-integrity route's retry prohibition.

## Missing information
- Active signing-key identifier, needed for endpoint-owner verification.

## Rule citations
- `NSR-AUTH-17` — the failed signature check selects the `signature-integrity`, `P1`, non-retryable route and prescribes stopping retries, quarantining the delivery, and verifying the active signing-key identifier.
- `NSR-MISSING-08` — identifies the active signing-key identifier as operationally useful for a signature-integrity incident and requires missing facts to be listed without guessing.
