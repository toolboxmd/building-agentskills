Create a portable agent skill named `triaging-webhook-incidents` from the synthetic local source material listed below.

Read all of these immutable inputs before authoring:

- `visible-inputs/northstar-webhook-runbook.md`
- `visible-inputs/delivery-state-reference.md`
- `visible-inputs/training-events.jsonl`

Write the complete skill package only under `output/triaging-webhook-incidents/`. Do not modify the source inputs or write anywhere else. The package must have a concise `SKILL.md` entry point and conditionally loaded reference material. Preserve rule identifiers and source boundaries, but do not copy the complete runbook into `SKILL.md`. The skill must work offline and must not rely on user memory, prior outputs, network access, another model, or another agent.

The skill is for webhook incident assessment when an operator supplies a Northstar Relay delivery payload or a symptom summary. It is not for general API debugging, endpoint implementation, secret rotation execution, customer messaging, or live remediation. Make the trigger and these near-miss boundaries precise. Route users through authoritative packaged references for delivery-state meanings, precedence, retry timing, and unknown states. Require uncertainty to be stated rather than filled in. A deterministic script is optional only if it performs justified repeated mechanical work; semantic classification must remain source-backed.

Document a downstream output contract for a Markdown incident assessment with exactly these sections or clearly equivalent labeled fields: Classification, Priority, Next action, Retry guidance, Missing information, and Rule citations. Citations must use identifiers that exist in the supplied material.

Include `output/triaging-webhook-incidents/validation-report.md` with a short account of files created, checks performed, and any limitation. Validate structure, internal paths, and source fidelity in proportion to the package. Do not perform live network checks.
