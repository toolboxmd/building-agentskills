# Northstar Relay delivery states

- `queued`: accepted and waiting for its first attempt.
- `attempting`: an HTTP attempt is currently in progress.
- `retry_wait`: eligible failure waiting for a scheduled retry.
- `delivered`: endpoint acknowledged the delivery with a terminal success.
- `quarantined`: automatic delivery is stopped pending operator review.
- `paused_unknown`: intentionally undocumented. Treat it as an unknown state under `NSR-UNKNOWN-90`; do not infer why it is paused.

This excerpt does not define any other delivery-state values.
