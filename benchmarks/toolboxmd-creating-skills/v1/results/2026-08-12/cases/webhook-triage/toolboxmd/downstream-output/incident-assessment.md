## Classification
signature-integrity. The HTTP 429 responses are a secondary observed symptom and do not change the higher-precedence classification.

## Priority
P1

## Next action
Stop automatic retries, quarantine the delivery, and ask the endpoint owner to verify the active signing-key identifier. Do not rotate or expose secrets as part of triage.

## Retry guidance
Not eligible. Do not retry in two minutes; the supplied `retry_after_seconds` value does not apply to the signature-integrity route.

## Missing information
The active signing-key identifier was not included.

## Rule citations
`NSR-AUTH-17`, `NSR-MISSING-08`
