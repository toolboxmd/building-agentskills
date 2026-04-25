# Evolution: ship cycles, semver, and deprecation

Skills evolve. The audit-driven hardening cycle that produced karpathy-wiki v2.2 is the same cycle this repo expects authors to use for their own skills. This page covers the cycle, how to version a skill, how to deprecate a public surface without breaking cached users, and the license-of-skills nuance.

## The audit cycle

Source: `LESSONS` 3 (the brainstorming-spec-plan-execute pipeline as a gestalt); `LESSONS` 7 (recommendations).

The cycle has five phases:

1. **Audit.** Read every line of the SKILL.md, every script, every test fixture. Produce a numbered findings list with severity (BLOCKER / HIGH / MEDIUM / LOW) and an explicit "things working well" + "things deliberately not covered" section. Defer 30-50 percent of findings to a future audit; do not try to fix everything in one ship.
2. **Spec.** Brainstorm the architectural shape. Look for findings that collapse into one fix (the v2.2 architectural cut to delete `sources/` collapsed three audit findings into one cut). The spec doc names the architectural decisions and the per-finding plan.
3. **Plan.** Convert the spec into bite-sized implementation tasks. Each task has a verbatim test body, BEFORE / AFTER blocks, a commit message. The plan is "no placeholders" per superpowers writing-plans. The v2.2 plan was 2,029 lines for 13 tasks.
4. **Execute.** Dispatch one implementer subagent per task. Two-stage review (spec compliance, then code quality) on each commit. Fix-up commits as needed (reviewer fix-up rate stays in 25-40 percent for a healthy ship).
5. **Next audit.** The cycle repeats. The "things deliberately not covered" list from the previous audit becomes the seed for the next audit's scope.

Cycle cadence: typically per major-version ship. Karpathy-wiki ran the cycle for v2 (Tasks 1-29), v2-hardening (Tasks 30-44), v2.1 (missed-capture patch), and v2.2 (Tasks 50-62). Four cycles in six months. Each cycle produced lessons that fed the next.

## Versioning policy

Source: `REVIEWER` G3.

Semantic versioning for skills, with one nuance the spec does not name:

- **Major (X.0.0).** A breaking change to the public surface. Includes:
  - Frontmatter contract change (a removed field, a changed required-field set).
  - Script API change (a renamed function, a removed flag).
  - **Description string change.** The description is the activation contract. Changing it can break implicit triggering for users whose prompts matched the old description and not the new one. Conceptually, this is a major shift even if no other surface changed. Document the trigger differences explicitly.
- **Minor (0.X.0).** A non-breaking addition. New frontmatter field with a default. New script subcommand. New body section that does not change existing behavior.
- **Patch (0.0.X).** Bug fix. No surface change. Prose tightening, fixture corrections, internal refactor.

Karpathy-wiki uses `0.X.Y` versioning because the skill is still pre-1.0 (pre-stable-API). v2.2 was a `0.2.0 → 0.2.2` bump (two patches over the v2 stable surface). When the skill reaches stable API, it will move to `1.0.0` and start using the major/minor/patch semantics strictly.

## Deprecation

When you remove a public surface (a frontmatter field, a script flag, a SKILL.md section), users with cached versions of the previous surface may break. Three strategies:

- **Soft deprecation.** Add a deprecation warning in the new version while keeping the old surface working. The next major version removes the deprecated surface entirely. Pattern: log a warning when the deprecated surface is used; document the warning and the removal timeline in the changelog.
- **Hard deprecation.** Remove the surface in a major version with a migration script. Karpathy-wiki v2.2 used this pattern for the `sources/` directory deletion; the migration script `wiki-migrate-v2.2.sh` (177 lines, six functions, with a `--dry-run` flag) handled the live state changes (`LESSONS` 8.4).
- **Versioned-skill coexistence.** Ship both the old and the new skill side by side. Users can pick. Heavier maintenance burden; usually only justified for bridge ships.

The migration-script-as-Phase-D-task pattern is canonical: when the cycle modifies live state outside the repo (the user's file system, a database), Task 1 of Phase D is "create a backup with a timestamped name." Karpathy-wiki Task 61 step 1 created a 1.9 MB tarball before any live wiki mutation; the tarball was never needed (the migration ran clean) but cost ~10 seconds. Cheap insurance.

## Reviewer fix-up rate as a quality signal

Source: `LESSONS` 2.6; `REVIEWER` verification table.

The v2.2 ship produced 19 commits on the v2-rewrite branch. Five were reviewer-driven fix-ups: `42b24bf`, `697318a`, `3dfc26b`, `0e0f815`, `ff12716`. That is 5 out of 19, or approximately 26.3 percent.

Empirical anchor:

- **Less than 5 percent reviewer fix-ups** means the reviewer is rubber-stamping. Either the plans are extremely good (rare) or the reviewer is not actually reading the code. Investigate.
- **More than 50 percent reviewer fix-ups** means the plans are too vague. Each implementer is filling in design choices the plan should have specified. Tighten the plans.
- **25 to 40 percent** is healthy. The reviewer is catching real bugs without redoing the implementer's design work.

Note: `REVIEWER` corrected the analyzer's earlier 28 percent figure to 26.3 percent (5 of 19, not 5 of 18). Both numbers are within the healthy band; the corrected number is the one to cite.

This is one ship of evidence. The pattern needs more samples before it becomes a load-bearing claim. The qualitative observations (fix-ups caught real bugs, none caused rework) hold within this sample.

## License-of-skills nuance

Source: `REVIEWER` M6; license verification across the ecosystem.

The skill ecosystem is mixed-license. Authors should know what they are inheriting and what they are publishing.

- **agentskills/agentskills (the spec org repo).** Apache 2.0. The reference implementation has explicit patent grant.
- **anthropics/skills.** Mixed-license. Many skills are Apache 2.0; the document skills (pdf, docx, pptx, xlsx) are explicitly proprietary ("Source-available, not open source," per the repo's THIRD_PARTY_NOTICES). The earlier characterization of the repo as "MIT-licensed" was wrong (corrected by `REVIEWER` recommendation 8).
- **obra/superpowers.** Apache 2.0.
- **karpathy-wiki.** MIT. The author chose MIT for that repo; this is a per-repo choice.
- **toolboxmd/building-agentskills (this repo).** Apache 2.0. The choice is deliberate: Apache 2.0's explicit patent grant matches `agentskills/agentskills`'s posture and eases cross-pollination. This repo is the ecosystem reference; it follows agentskills/agentskills' lead rather than mirroring karpathy-wiki's MIT choice.

The patent-grant rationale: as the agent-skills ecosystem grows, contributors may hold patents on techniques their skills use. Apache 2.0's patent clause grants an explicit license to those patents under the same terms as the copyright; MIT does not. For an ecosystem-reference repo, the explicit grant reduces friction for downstream users.

When publishing your own skill: pick the license that matches your downstream-use expectations. MIT for permissive minimal-conditions reuse; Apache 2.0 for explicit patent grant; proprietary for source-available-but-not-open. Document the choice in `LICENSE` and reference in your `plugin.json` `license` field.

## What this repo expects from contributors

Per `docs/12-update-mechanism.md`: case studies, per-ship retrospectives, reader-submitted issues. The audit cycle is not strictly required for every contribution (a small typo fix does not need a brainstorming pass), but for non-trivial ships it is the proven pattern.

## Sources

- `LESSONS` 2.6 (the reviewer fix-up rate as quality signal; corrected to 26.3 percent in `REVIEWER`).
- `LESSONS` 3 (the brainstorming-spec-plan-execute pipeline as gestalt).
- `REVIEWER` G3 (description-string change as conceptual major version).
- `REVIEWER` M6 (the license-of-skills nuance; Apache 2.0 patent grant rationale).
- `KP-LICENSE` (for contrast only; karpathy-wiki is MIT, this repo is Apache 2.0).

Cross-links: `docs/12-update-mechanism.md`, `case-studies/2026-04-25-karpathy-wiki-v2.2.md`.
