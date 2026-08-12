# Northstar Relay incident routing

This packaged reference preserves the incident-runbook rule boundary. It is authoritative for routing, precedence, retry timing, and missing-fact handling.

## Precedence

Evaluate applicable rules in this exact order and select the first matching route:

1. `NSR-AUTH-17`
2. `NSR-DATA-24`
3. `NSR-RATE-31`
4. `NSR-REMOTE-46`
5. `NSR-UNKNOWN-90`

Do not combine a lower-priority route into the classification. It may be mentioned only as a secondary observed symptom.

## Routes

### `NSR-AUTH-17`

When `signature_check` is `failed`:

- Classification: `signature-integrity`
- Priority: `P1`
- Next action: stop automatic retries, quarantine the delivery, and ask the endpoint owner to verify the active signing-key identifier
- Retry guidance: not eligible

Do not rotate or expose secrets as part of triage.

### `NSR-DATA-24`

When signature verification passed but `schema_check` is `failed`:

- Classification: `payload-contract`
- Priority: `P2`
- Next action: preserve the rejected body hash for schema-owner review
- Retry guidance: do not retry unchanged payload bytes

### `NSR-RATE-31`

When integrity and schema checks passed and the endpoint returned HTTP `429`:

- Classification: `endpoint-throttling`
- Priority: `P2`
- Next action: follow `NSR-RETRY-12`
- Retry guidance: eligible under `NSR-RETRY-12`

### `NSR-REMOTE-46`

When integrity and schema checks passed and the endpoint returned HTTP `500`, `502`, `503`, or `504`:

- Classification: `endpoint-transient`
- Priority: `P2`
- Next action: follow `NSR-RETRY-12`
- Retry guidance: eligible under `NSR-RETRY-12`

### `NSR-UNKNOWN-90`

When `delivery_state` is not defined by [delivery-states.md](delivery-states.md) and no higher rule matches:

- Classification: `unknown-state`
- Priority: `P2`
- Next action: pause automation, preserve the literal state, and escalate to the Relay maintainer
- Retry guidance: no retry schedule is specified; automation is paused

Never infer a state meaning from its spelling.

## Retry rule

### `NSR-RETRY-12`

Eligible throttling and transient failures retry after 45 seconds, then 3 minutes, then 12 minutes. Stop after the third retry and escalate.

A server-provided `retry_after_seconds` replaces only the next scheduled delay when it is an integer from 30 through 900. An absent, non-integer, or out-of-range value does not replace the scheduled delay.

Signature-integrity and payload-contract routes are not retry eligible.

## Missing facts

### `NSR-MISSING-08`

List any absent fact needed to complete the selected route. Missing facts do not authorize guessing.

- For `signature-integrity`, the active signing-key identifier is operationally useful.
- For retry-eligible routes, endpoint tier and attempt number are useful.

