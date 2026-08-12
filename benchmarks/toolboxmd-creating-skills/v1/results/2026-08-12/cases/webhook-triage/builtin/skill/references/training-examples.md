# Training examples

Source boundary: derived only from the supplied synthetic training events. These are examples, not additional rules. Apply the authoritative runbook and delivery-state reference independently; never fill missing incident facts from an example.

## `train-101`

```json
{"event_id":"train-101","delivery_state":"retry_wait","signature_check":"passed","schema_check":"passed","http_status":429,"attempt_number":1,"endpoint_tier":"standard"}
```

The facts establish `NSR-RATE-31` (`endpoint-throttling`, `P2`) and its `NSR-RETRY-12` guidance. No `retry_after_seconds` is supplied, so no override is established.

## `train-102`

```json
{"event_id":"train-102","delivery_state":"quarantined","signature_check":"failed","schema_check":"passed","http_status":429,"active_signing_key_id":"key-blue"}
```

`NSR-AUTH-17` wins by precedence (`signature-integrity`, `P1`). HTTP `429` is at most a secondary observed symptom; it does not add `NSR-RATE-31` to the classification or make the delivery retry eligible.

## `train-103`

```json
{"event_id":"train-103","delivery_state":"paused_unknown","signature_check":"passed","schema_check":"passed","http_status":418,"endpoint_tier":"priority"}
```

The delivery-state reference explicitly directs `paused_unknown` to `NSR-UNKNOWN-90` (`unknown-state`, `P2`). Do not infer what caused the pause.
