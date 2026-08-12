# Downstream smoke check

Run this after creating a nontrivial skill. Adapt paths and artifacts to the target; do not compare versions.

## Setup

1. Start a fresh agent context with only the created skill and representative input artifacts available.
2. Use one realistic should-trigger prompt from the evidence brief. Do not name the skill unless explicit invocation is the intended design.
3. Capture the skill-load event or execution trace when the harness exposes it.

## Pass conditions

- The agent discovers or explicitly invokes the intended skill according to the recorded invocation design.
- It follows the concise default path and loads only references whose conditions apply.
- It consumes the stated inputs and produces the promised output at the expected path or in the expected response shape.
- It handles one evidence-backed gotcha correctly.
- Any deterministic validator or script returns its documented success code.
- The trace shows no invented dependencies, unrelated broad reads, interactive prompt, or unexpected mutation.

If the skill does not trigger, revise the description using the failed prompt and a close near miss. If it triggers but the output fails, revise the body, resource, or mechanism responsible. Re-run mechanical validation after every change.

Record the result as **tested** only when the smoke check actually ran. A prepared prompt is not an executed test.
