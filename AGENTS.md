# Repository Agent Guide

## Start here

Before planning or changing this repository, read:

1. `README.md`
2. `docs/03-three-questions.md`
3. `docs/12-update-mechanism.md`
4. The open [GitHub Issues](https://github.com/toolboxmd/building-agentskills/issues). Planned work lives there, not in plan files: loader discovery (#17), continuous learning from upstream ships (#18), cross-case-study patterns (#19), a published doc index (#20), and reader-Issue triage (#21).

Use the project wiki in `wiki/` for orientation. karpathy-wiki maintains it, and the doc checks skip it. Update it after a structural change or a durable decision, not for routine implementation detail.

## Repository role

`building-agentskills` is the evidence-backed doctrine layer for designing agent skills: authoring them, routing an agent to the right procedure before each action, and benchmarking whether it does. It is not an implementation mirror of `karpathy-wiki`, and it must remain useful across projects, providers, and machines.

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

## Proof

Run `npm ci && npm test`. It checks links with `mint broken-links`, the freshness of the generated `public/llms.txt`, path conventions, version agreement and changelog entries. CI runs the same command on every pull request, on `main` and on `v*` tags, with full history so the changelog check finds the pull request's base. After changing a page listed in `docs.json`, run `npm run build:llms`; never edit `public/llms.txt` by hand.

## Versions and changelog

- A change under `docs/`, `case-studies/`, `skills/` or `examples/` adds a line under `## [Unreleased]` in `CHANGELOG.md`; `npm test` fails otherwise.
- To release, choose the level: MAJOR for a removed or renamed pattern or breaking guidance, MINOR for a new page, case study, Skill or gate, PATCH otherwise. Run `bash scripts/bump-version.sh X.Y.Z`, which sets `package.json`, `package-lock.json` and `.claude-plugin/plugin.json`, and move the `[Unreleased]` notes under `## [X.Y.Z] - YYYY-MM-DD`.
- A tag is a release artifact: only after the user merges and approves it, tag the merge commit with `git tag vX.Y.Z <merge-sha> && git push origin vX.Y.Z`. CI then checks that the tag matches the version files.

## Current local drafts

`TODO.md` and `docs/superpowers/specs/2026-05-06-drift-prevention-and-check-sources-design.md` are user-owned untracked files in the main checkout. Their entries now live in Issues #17 to #22 (mapped in #11). Never delete, overwrite or stage them, and do not describe them as shipped.
