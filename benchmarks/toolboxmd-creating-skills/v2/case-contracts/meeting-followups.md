# Meeting notes to follow-ups

## Daily job

Turn ordinary meeting notes into a shareable follow-up, update the team's action tracker, and leave a compact QA receipt.

## Target skill

`meeting-followups`

## Why a skill should help

The model can summarize a meeting without help. The useful skill must instead activate on a natural request, apply private classification and tracker conventions, complete the easily skipped tracker and QA steps, and avoid promoting ideas into commitments.

## No-skill qualification

The no-skill arm receives the same notes, tracker, and private convention file as treatment arms. It qualifies the case only by failing at least one critical assertion while having enough information to succeed.

## Positive trigger

A natural request asks for today's follow-up and tracker update. It does not mention skills or workflow steps. The event trace must show a full load of the target `SKILL.md` before output creation.

## Near miss

A related request asks for concise advice on making meetings easier to follow. It should not load a procedure for processing actual meeting notes.

## Authoring material

The creator receives the private convention contract and a separate worked example. The example does not contain the held-out people, dates, identifiers, decisions, or actions.

## Held-out downstream task

The held-out workspace contains a dated meeting, an existing tracker, explicit decisions, explicit actions, an idea, an open question, and one missing due date.

## Critical assertions

The follow-up has the required sections and evidence identifiers. The tracker contains exactly the expected new rows in the required schema. The idea is not added as an action. Missing due dates remain `TBD`. The QA receipt reports exact counts and completed checks. Protected inputs remain unchanged.

## Cost and trace evidence

Record package size, authoring tokens, target load, unexpected loads, downstream uncached tokens, output tokens, duration, deterministic checks, and boundary audit.
