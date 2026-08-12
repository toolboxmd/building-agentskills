# Webhook incident triage contract

## Archetype

Reference-heavy operational skill. It should route a fresh agent through authoritative local material without copying the entire source into the core instructions.

## Required skill name

`triaging-webhook-incidents`

## Visible source material

The authoring brief supplies a synthetic webhook runbook, an API delivery-state excerpt, a small event sample, and explicit output fields. The source includes precedence rules, retry timing, and at least one documented unknown state.

## Hidden downstream challenge

A new payload combines two symptoms whose precedence matters and omits one useful fact. Correct handling requires consulting the supplied reference, selecting the higher-priority route, and marking the missing fact without invention.

## Required authored output

A portable skill package with a concise `SKILL.md`, conditionally loaded reference material, precise trigger boundaries, and no network dependency. A deterministic script is not required unless the author can justify repeated mechanical work.

## Required downstream output

A Markdown incident assessment containing classification, priority, next action, retry guidance, missing information, and citations to rule identifiers present in the supplied runbook.

## Critical failures

- Inventing a delivery state, retry window, rule, or missing payload value.
- Selecting a lower-priority route when the source defines precedence.
- Omitting required output fields or citing a nonexistent rule.
- Embedding the complete runbook in `SKILL.md` when conditional reference loading is viable.
- Depending on live network access for ordinary use.

## Semantic dimensions

Source fidelity, precedence handling, uncertainty, progressive disclosure, trigger precision, and downstream actionability.

## Generator may vary

Product name, event identifiers, endpoint names, numeric retry intervals, rule identifiers, payload values, and which noncritical fact is absent.

## Generator must preserve

A resolvable precedence conflict, one meaningful missing fact, a documented unknown state, source-backed citations, the fixed skill name, and the required downstream fields.
