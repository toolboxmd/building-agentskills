# Runbook rules

Source boundary: derived only from the synthetic **Northstar Relay incident runbook**. This reference is authoritative for incident routing.

## Precedence

Evaluate applicable rules in this exact order and select the first matching route:

1. `NSR-AUTH-17`
2. `NSR-DATA-24`
3. `NSR-RATE-31`
4. `NSR-REMOTE-46`
5. `NSR-UNKNOWN-90`

Do not combine a lower-priority route into the classification. It may be mentioned only as a secondary observed symptom.

## Routing rules

### `NSR-AUTH-17`

When `signature_check` is `failed`:

- Classification: `signature-integrity`
- Priority: `P1`
- Next action: stop automatic retries, quarantine the delivery, and ask the endpoint owner to verify the active signing-key identifier.
- Retry guidance: not retry eligible.
- Constraint: do not rotate or expose secrets as part of triage.

### `NSR-DATA-24`

When signature verification passed but `schema_check` is `failed`:

- Classification: `payload-contract`
- Priority: `P2`
- Next action: preserve the rejected body hash for schema-owner review.
- Retry guidance: do not retry unchanged payload bytes; this route is not retry eligible.

### `NSR-RATE-31`

When integrity and schema checks passed and the endpoint returned HTTP `429`:

- Classification: `endpoint-throttling`
- Priority: `P2`
- Next action and retry guidance: follow `NSR-RETRY-12`.

### `NSR-REMOTE-46`

When integrity and schema checks passed and the endpoint returned HTTP `500`, `502`, `503`, or `504`:

- Classification: `endpoint-transient`
- Priority: `P2`
- Next action and retry guidance: follow `NSR-RETRY-12`.

### `NSR-UNKNOWN-90`

When `delivery_state` is not defined by the delivery-state reference and no higher rule matches:

- Classification: `unknown-state`
- Priority: `P2`
- Next action: pause automation, preserve the literal state, and escalate to the Relay maintainer.
- Constraint: never infer a state meaning from its spelling.

The delivery-state reference explicitly treats `paused_unknown` as unknown under this rule even though the literal appears in that reference.

## Retry rule

### `NSR-RETRY-12`

Eligible throttling and transient failures retry after:

1. 45 seconds
2. 3 minutes
3. 12 minutes

Stop after the third retry and escalate. A server-provided `retry_after_seconds` replaces only the next scheduled delay when it is an integer from 30 through 900, inclusive. It does not replace later delays. Signature and payload-contract routes are not retry eligible.

## Missing facts

### `NSR-MISSING-08`

List every absent fact needed to complete the selected route. Missing facts never authorize guessing.

- For `signature-integrity`, the active signing-key identifier is operationally useful.
- For retry-eligible routes, endpoint tier and attempt number are operationally useful.

When facts needed to establish precedence are absent, identify them as necessary to complete classification rather than assuming a lower route.
