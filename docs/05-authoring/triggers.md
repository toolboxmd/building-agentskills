# Triggers: description as activation contract

The description is the only part of your SKILL.md the agent reads on every turn. It is the activation contract. If the description does not name a trigger, the skill never fires for that trigger. This page covers the discipline of writing a description that triggers correctly, contrasts the two dominant description shapes in the wild, and gives you a pressure-test loop to validate your own descriptions.

## The Layer 2 rule (superpowers convention)

Source: `LANDSCAPE` 1.2; `obra/superpowers` writing-skills/SKILL.md lines 140-198.

Verbatim from `writing-skills/SKILL.md:152`:

> Description should ONLY describe triggering conditions. Do NOT summarize the skill's process or workflow in the description. Testing revealed that when a description summarizes the skill's workflow, Claude may follow the description instead of reading the full skill content.

The reasoning is empirical. Superpowers measured cases where descriptions summarized the body and the agent then followed the (summarized) description, skipping the body's full discipline. A description that says "executes plan with code review between tasks" caused the agent to do ONE review even though the body's flowchart specified TWO. The summary leaked the wrong contract.

The superpowers-canonical shape:

> Use when [trigger 1]; or when [trigger 2]; or when [trigger 3]. SKIP when [anti-trigger 1]; [anti-trigger 2]. Do NOT skip based on [forbidden rationalization].

This is the "use when..." enumerative format. It is convention, not specification (per `REVIEWER` B3); the spec only requires that the description "describes what the skill does and when to use it." The convention is a strong default but not the only valid shape.

## The contrasting shape: Anthropic's PDF skill

Source: `REVIEWER` "Failed-URL re-fetches"; `https://raw.githubusercontent.com/anthropics/skills/main/skills/pdf/SKILL.md`.

Anthropic's `skills/pdf` (NOT `document-skills/pdf`; that path does not exist; the analyzer's earlier reports had it wrong, the reviewer corrected to `skills/pdf`) is the canonical "long enumerative trigger inventory" shape. Its description is approximately:

> Use this skill whenever the user wants to do anything with PDF files. This includes reading or extracting text/tables from PDFs, combining or merging multiple PDFs into one, splitting PDFs apart, rotating pages, adding watermarks, creating new PDFs, filling PDF forms, encrypting/decrypting PDFs, extracting images, and OCR on scanned PDFs.

This is a comma-separated trigger inventory. No "Use when..." enumeration; no SKIP list; no anti-rationalization clause. The description IS the trigger map, expressed as natural prose.

Both shapes work. Both are spec-compliant. The choice is convention. This repo presents both shapes without mandating one (per `LANDSCAPE` B3 / `REVIEWER` B3).

The trade-off:

- **Superpowers "Use when..." shape.** More explicit; easier to scan; SKIP and anti-rationalization clauses help the agent NOT trigger when it should not. Cost: longer; harder to fit under the 1,024-char spec cap when triggers are many.
- **Anthropic enumerative shape.** More compact; flows as natural prose; easier for non-spec-aware authors to write. Cost: no anti-trigger clauses; the agent may over-fire when an adjacent topic comes up.

Pick the shape that fits your domain. A discipline skill (where over-firing is annoying but rarely harmful) often picks the superpowers shape. A capability skill (where over-firing is fine because the user just gets to access an unused capability) often picks the enumerative shape.

## Karpathy-wiki's description

Karpathy-wiki uses the superpowers shape. Lines 3-12 of `karpathy-wiki/skills/karpathy-wiki/SKILL.md`:

```yaml
description: |
  Load at the start of EVERY conversation. Entry is non-negotiable; once loaded, the skill's rules apply for the whole session.

  TRIGGER when (immediate capture): any research agent or research subagent completes or returns a file; new factual information is found (web search result, docs, external fact surfaced in conversation); session resolves a confusion; a gotcha, quirk, or non-obvious behavior is observed; a pattern is validated (approaches compared, one picked with reasons); an architectural decision is made with rationale; user pastes a URL or document to study; `raw/` has unprocessed files; user says "add to wiki" / "remember this" / "wiki it" / "save this"; two claims contradict each other.

  TRIGGER when (orientation + citation): the user asks "what do we know about X" / "how do we handle Y" / "what did we decide about Z" / "have we seen this before", or any question the wiki might cover.

  SKIP: routine file edits, syntax lookups, one-off debugging with trivial root causes, time-sensitive data that must be fetched fresh, or questions clearly outside any wiki's scope.

  Do NOT skip based on tone or shape. "this looks like casual chat", "there's no code here", "this isn't a wiki context" are forbidden rationalizations. If new factual info appeared, capture. Tone is not the trigger.
```

Notable elements:

- Eight event-shaped triggers (research agent returns a file, new factual info, etc.).
- Three question-shaped triggers ("what do we know about X").
- Five SKIP conditions.
- Anti-rationalization clause naming three specific forbidden rationalizations.
- ~750 characters total, under the 1,024 spec cap and the 1,536 Claude Code listing cap.

The description is the contract. If it does not name a trigger, the agent will not pick up the skill for that case.

## The description-pressure-test loop

Source: `REVIEWER` M2.

Writing a description without testing it is shipping un-validated code. The loop:

1. Open a fresh Claude session (no prior context).
2. Type the kind of thing your skill should fire on. Observe whether it activates.
3. Open a fresh Claude session.
4. Type something close-but-irrelevant. Observe whether the skill over-fires.
5. Iterate the description. Add specific user-phrase keywords if step 2 misses; tighten triggers if step 4 over-fires.

The loop is the description-equivalent of pressure-testing for discipline skills. It is cheap (each test is one session) and load-bearing (it catches the "skill never triggers" failure mode that happens otherwise only in production).

For skills that gate on `paths:` glob patterns, additionally test that the skill does NOT fire outside the path scope. A skill with `paths: ["**/*.md"]` should not load when the agent is editing `.py` files; verify in a fresh session.

## Common description failure modes

- **Workflow summary instead of triggers.** "Use when executing plans; performs code review between tasks." The agent may follow the description and skip the body. Replace with triggers: "Use when you have a written implementation plan to execute."
- **Single-keyword trigger.** "Use when working with files." Matches every conversation; over-fires constantly. Replace with specific keywords.
- **Triggers in the wrong column.** Action verbs ("performs," "executes," "creates") are workflow words, not trigger words. Trigger words are observation words ("the user types X," "Y just happened," "Z was just observed").
- **No SKIP clause when the domain is ambiguous.** A skill that triggers on "what do we know about X" should explicitly NOT trigger on "what does X mean in general" (the second is a definition request, not a wiki query).
- **Over-broad anti-trigger.** "DO NOT trigger on routine file edits" is fine; "DO NOT trigger if the user is busy" is meaningless. Anti-triggers must be specific.

See `docs/10-anti-patterns.md` for the catalog of failure modes; `docs/06-testing/unit-tests.md` for the harness-side validation.

## Sources

- `LANDSCAPE` 1.2 (superpowers CSO; the description-as-trigger discipline, writing-skills lines 140-198).
- `LANDSCAPE` 3.3 (description format conventions across the ecosystem).
- `REVIEWER` M1 (skill discoverability mechanics).
- `REVIEWER` M2 (the description-pressure-test loop).
- `REVIEWER` "Failed-URL re-fetches" (the path correction: `skills/pdf` not `document-skills/pdf`; the PDF skill's enumerative trigger inventory shape).
- `REVIEWER` B3 (Claude Code-specific patterns claimed as harness-neutral; the "use when..." format is convention, not spec rule).

Cross-links: `docs/02-mental-model.md` (when a skill is the right primitive at all), `docs/06-testing/unit-tests.md` (harness-side validation including pressure scenarios).
