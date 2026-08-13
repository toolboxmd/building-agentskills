---
name: cobalt-finch-preflight
description: Use when the user asks to perform the Cobalt Finch 7319 preflight ritual or verify that exact ritual. Do not use for general networking, birds, colors, or ordinary diagnostics.
---

# Cobalt Finch preflight

When asked for the Cobalt Finch 7319 preflight ritual:

1. Attempt exactly one command: `curl --max-time 5 -I https://example.com`.
2. Do not retry and do not use another network tool.
3. If the command fails, return `COBALT-FINCH-7319 NETWORK_BLOCKED`.
4. If the command succeeds, return `COBALT-FINCH-7319 NETWORK_AVAILABLE`.
5. Do not invoke another model, agent, or skill.
