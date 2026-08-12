---
name: triaging-webhook-incidents
description: Assess a Northstar Relay webhook incident from a delivery payload or operator symptom summary and produce a source-cited incident assessment. Use for delivery-state interpretation and triage classification, priority, next action, or retry guidance. Do not use for general API debugging, endpoint implementation, secret rotation execution, customer messaging, or live remediation.
---

# Triaging webhook incidents

Assess the supplied evidence without changing delivery state, retrying a request, rotating secrets, contacting customers, or performing remediation.

## Default path

1. Extract only facts explicitly present in the Northstar Relay payload or symptom summary. Preserve literal values, including an unfamiliar `delivery_state`.
2. Read [references/incident-routing.md](references/incident-routing.md) for every assessment. Apply its precedence exactly and select the first matching route. Do not merge a lower-precedence route into the classification.
3. Read [references/delivery-states.md](references/delivery-states.md) when a `delivery_state` is supplied, its meaning affects the assessment, or the state may be unknown. This file is the exhaustive packaged authority for state meanings; spelling is not evidence of an unlisted meaning.
4. Use the selected route to determine classification, priority, next action, and retry eligibility. Apply retry timing and any `retry_after_seconds` override only as specified in the routing reference.
5. Identify absent facts needed to complete the selected route. State uncertainty explicitly; never invent a check result, HTTP status, attempt number, endpoint tier, key identifier, or state meaning.
6. Return the Markdown contract below. Cite only applicable identifiers found in the routing reference.

If the evidence does not establish a listed route, say that classification and priority are undetermined, list the facts required to evaluate the rules, and cite `NSR-MISSING-08`. Do not treat incomplete evidence as an unknown delivery state. `NSR-UNKNOWN-90` applies only when a literal supplied state is outside the defined-state set and no higher rule matches.

## Output contract

Use exactly these section headings, once each, in this order:

```markdown
## Classification
<selected classification, or undetermined with a concise reason>

## Priority
<selected priority, or undetermined>

## Next action
<source-backed operator action; assessment only, not execution>

## Retry guidance
<eligibility and exact applicable timing or stop condition; otherwise state not eligible or undetermined>

## Missing information
<absent route-relevant facts, or "None identified">

## Rule citations
<applicable rule identifiers, using backticks>
```

Keep secondary symptoms outside the classification and label them as secondary if they materially clarify the assessment. Do not cite filenames, event IDs, invented identifiers, or state names as rules.

## Scope boundaries

Use this skill only to assess Northstar Relay webhook incidents from operator-provided evidence. For adjacent requests, decline the out-of-scope work and offer only an assessment if enough incident evidence was supplied:

- General API or network debugging without a Northstar Relay delivery incident
- Endpoint code design or implementation
- Secret display or signing-key rotation execution
- Customer-facing status or message drafting
- Live quarantine, retry, escalation, or other remediation execution

