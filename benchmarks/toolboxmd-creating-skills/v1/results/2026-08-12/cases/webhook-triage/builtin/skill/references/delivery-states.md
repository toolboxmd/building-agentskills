# Delivery-state meanings

Source boundary: derived only from the synthetic **Northstar Relay delivery states** reference. This excerpt is exhaustive: it does not define any values other than those below.

| Literal value | Meaning and treatment |
| --- | --- |
| `queued` | Accepted and waiting for its first attempt. |
| `attempting` | An HTTP attempt is currently in progress. |
| `retry_wait` | Eligible failure waiting for a scheduled retry. |
| `delivered` | Endpoint acknowledged the delivery with a terminal success. |
| `quarantined` | Automatic delivery is stopped pending operator review. |
| `paused_unknown` | Intentionally undocumented. Treat as an unknown state under `NSR-UNKNOWN-90`; do not infer why it is paused. |

For any other literal value, treat the state as undefined. If no higher-precedence rule matches, apply `NSR-UNKNOWN-90`. Preserve the literal value and never infer its meaning from spelling.
