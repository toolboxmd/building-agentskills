# Repository Agent Guide

## Start here

Before planning or changing this repository, read:

1. `README.md`
2. `docs/03-three-questions.md`
3. `docs/12-update-mechanism.md`
4. `docs/superpowers/plans/2026-08-12-continuous-learning-handoff.md`

Use the project wiki in `wiki/` for orientation. Update it after a structural change or a durable decision, not for routine implementation detail.

## Repository role

`building-agentskills` is the evidence-backed doctrine layer for authoring and operating agent skills. It is not an implementation mirror of `karpathy-wiki`, and it must remain useful across projects, providers, and machines.

Repository artifacts are written in English. The user may discuss the work in Polish.

## Evidence contract

Do not promote an upstream idea, plan, or unverified implementation into doctrine. A reusable lesson must cite at least one of:

- a shipped implementation commit;
- a recorded failure with inspectable evidence;
- a benchmark or acceptance result with a clear claim boundary;
- an authoritative primary source for external platform behavior.

Automatic source detection may create a candidate lesson or draft. It must not silently rewrite doctrine or merge its own changes.

## Working contract

- Prefer the smallest mechanism that closes a demonstrated failure mode.
- Test contract boundaries in proportion to risk. Do not add a test merely because a Markdown file changed.
- Keep deterministic collection and validation separate from semantic lesson extraction.
- Treat model or agent output as a proposal until its cited evidence is verified.
- Preserve unrelated local and untracked files.
- Before reporting completion, state separately what was tested, committed, and pushed.

## Current local drafts

At the time of the active handoff, `TODO.md` and `docs/superpowers/specs/2026-05-06-drift-prevention-and-check-sources-design.md` are pre-existing untracked drafts. Do not delete, overwrite, stage, or describe them as shipped. Reconcile them with the active handoff before implementation.
