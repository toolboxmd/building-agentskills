# Northstar Relay delivery states

This packaged reference preserves the delivery-state source boundary. It is exhaustive: values not listed as defined below are unknown under `NSR-UNKNOWN-90`.

| Literal value | Authoritative meaning |
|---|---|
| `queued` | Accepted and waiting for its first attempt. |
| `attempting` | An HTTP attempt is currently in progress. |
| `retry_wait` | Eligible failure waiting for a scheduled retry. |
| `delivered` | Endpoint acknowledged the delivery with a terminal success. |
| `quarantined` | Automatic delivery is stopped pending operator review. |

`paused_unknown` is intentionally undocumented. Treat it as an unknown state under `NSR-UNKNOWN-90`; do not infer why it is paused.

No other delivery-state values are defined by this reference.

