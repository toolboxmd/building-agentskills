Use the loaded `creator-under-test` skill to repair the existing candidate in
`output/skills/`. Read `input/base-brief.md`, `input/contract.json`, and the
bounded external feedback in `input/feedback.json`.

First run `python3 harness/isolation_preflight.py model`. Stop if it fails.

Reproduce each reported contract failure with your own minimal acceptance case
before changing the package. Apply the smallest supported repair, rerun the
relevant cases and the Creator validator, and leave exactly one final package
under `output/skills/`. Do not search for or infer the hidden grader. Do not use
network, Git, credentials, another agent, or another agentic CLI.

This is one bounded repair round. Preserve no extra file inside the distributed
package. Return the required final JSON message only after reporting which
feedback remains unresolved.
