# Northstar Relay incident runbook

This synthetic runbook is authoritative for incident routing.

## Precedence

Evaluate applicable rules in this exact order and select the first matching route:

1. `NSR-AUTH-17`
2. `NSR-DATA-24`
3. `NSR-RATE-31`
4. `NSR-REMOTE-46`
5. `NSR-UNKNOWN-90`

Do not combine a lower-priority route into the classification. It may be mentioned as a secondary observed symptom only.

## Rules

### NSR-AUTH-17

When `signature_check` is `failed`, classify as `signature-integrity`, assign priority `P1`, stop automatic retries, quarantine the delivery, and ask the endpoint owner to verify the active signing-key identifier. Do not rotate or expose secrets as part of triage.

### NSR-DATA-24

When signature verification passed but `schema_check` is `failed`, classify as `payload-contract`, assign priority `P2`, and preserve the rejected body hash for schema-owner review. Do not retry unchanged payload bytes.

### NSR-RATE-31

When integrity and schema checks passed and the endpoint returned HTTP `429`, classify as `endpoint-throttling`, assign priority `P2`, and follow the retry schedule in `NSR-RETRY-12`.

### NSR-REMOTE-46

When integrity and schema checks passed and the endpoint returned HTTP `500`, `502`, `503`, or `504`, classify as `endpoint-transient`, assign priority `P2`, and follow `NSR-RETRY-12`.

### NSR-UNKNOWN-90

If `delivery_state` is not defined by the delivery-state reference and no higher rule matches, classify as `unknown-state`, assign priority `P2`, pause automation, preserve the literal state, and escalate to the Relay maintainer. Never infer a state meaning from its spelling.

## Retry rule

`NSR-RETRY-12`: eligible throttling and transient failures retry after 45 seconds, then 3 minutes, then 12 minutes. Stop after the third retry and escalate. A server-provided `retry_after_seconds` replaces only the next scheduled delay when it is an integer from 30 through 900. Signature or payload-contract routes are not retry eligible.

## Missing facts

`NSR-MISSING-08`: list any absent fact needed to complete the selected route. Missing facts do not authorize guessing. For `signature-integrity`, the active signing-key identifier is operationally useful. For retry-eligible routes, endpoint tier and attempt number are useful.
