---
name: triaging-webhook-incidents
description: Assess a Northstar Relay webhook incident from an operator-provided delivery payload or symptom summary and produce a source-cited Markdown classification, priority, next action, retry guidance, and missing-information report. Use for delivery triage only; do not use for general API debugging, endpoint implementation, secret-rotation execution, customer messaging, or live remediation.
---

# Triage Northstar Relay webhook incidents

Perform an offline assessment only. Do not call services, alter delivery state, retry a delivery, rotate secrets, implement an endpoint, or draft customer communications. If the request includes those tasks, assess the incident when possible and clearly decline or separate the out-of-scope work.

## Load authoritative references

1. Read [references/runbook-rules.md](references/runbook-rules.md) for every assessment. It is authoritative for rule precedence, classifications, priorities, actions, retry timing, and missing facts.
2. Read [references/delivery-states.md](references/delivery-states.md) whenever `delivery_state` is supplied, its meaning is asked about, or the unknown-state route may apply. Treat its list as exhaustive for this excerpt.
3. Read [references/training-examples.md](references/training-examples.md) only when a worked comparison would help interpret an input or check the report. Examples never override either authoritative reference.

Keep the two authoritative source boundaries distinct. Do not infer a delivery-state meaning from a route, an example, or the state's spelling.

## Assess the incident

1. Extract only facts explicitly supplied by the operator. Preserve literal values, including an unfamiliar `delivery_state`. Distinguish absent facts from explicit `null` or unknown values.
2. Evaluate the routing rules in their documented order. Select the first rule whose conditions are established. Do not add a lower-precedence route to the classification; mention it only as a secondary observed symptom when useful.
3. Do not skip an unevaluable higher-precedence rule to assert a lower route. If missing facts could change the first matching route, make the classification and priority undetermined and request those facts under `NSR-MISSING-08`.
4. If no route is established—even after applying the documented unknown-state rule—report `undetermined` rather than inventing a classification or priority. State which required facts or rule coverage are absent.
5. Derive the next action and retry guidance only from the selected rule. Treat a retry override as valid only under the documented type and range constraints. Never characterize an ineligible route as retryable.
6. State uncertainty explicitly. Do not fill gaps from user memory, prior incidents, general webhook conventions, or the training examples.
7. Cite only applicable identifiers exactly as written in the packaged runbook. Include the selected routing rule, `NSR-RETRY-12` when retry guidance relies on it, and `NSR-MISSING-08` when listing missing route-relevant facts. Never create a citation identifier for a delivery-state value.

## Output contract

Return one Markdown incident assessment with exactly these level-two sections in this order and no additional sections:

```markdown
## Classification
<selected classification, or `undetermined`, with a concise basis>

## Priority
<selected priority, or `undetermined`>

## Next action
<source-backed operator action; distinguish assessment advice from prohibited live execution>

## Retry guidance
<exact applicable schedule/override/stop condition, `not retry eligible`, or `undetermined`>

## Missing information
<bulleted absent facts needed to complete or operate the selected route, or `None identified.`>

## Rule citations
<bulleted exact rule identifiers and a short statement of how each applies>
```

Do not add citations that are merely plausible. If no routing rule can be established, cite `NSR-MISSING-08` when it applies and explain in the other fields that classification remains undetermined.
