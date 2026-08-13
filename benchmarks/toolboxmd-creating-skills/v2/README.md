# ToolboxMD creating-skills benchmark v2

## Question

Which frozen creator produces more useful daily-use skills under the same Codex configuration: the Codex 0.147.0 built-in `skill-creator`, or the retained `toolboxmd-creating-skills` candidate?

The answer is based on implicit activation, complete downstream execution, deterministic artifacts, false-positive triggering, and runtime cost. It is not based on prose aesthetics alone.

## Treatments

- `builtin`: retained inspectable package from the v1 baseline.
- `toolboxmd`: retained inspectable package produced for v1 before any exact v2 case existed.

Both packages are immutable inputs referenced by hash. Both use `gpt-5.6-sol`, medium reasoning, Codex CLI 0.147.0, the same prompts and files, clean sessions, the same sandbox, and no network or nested delegation.

## Counterfactual

Every downstream arm receives the same ordinary task files, conventions, and template. The no-skill arm receives no target skill listing. Each creator arm receives one generated target skill through normal `.agents/skills/` discovery.

Positive prompts never name the target skill, its path, or the instruction to use a skill. A trace must show the generated `SKILL.md` load. Agent self-report is not triggering evidence.

## Cases

Primary:

1. `meeting-followups`
2. `weekly-status-deck`

Conditional reserve:

3. `personal-expense-rollup`

The reserve runs only when the primary result is mixed, invalid, or tied.

## Sequence

1. Freeze and verify treatments, protocol, cases, and hashes.
2. Pass an infrastructure preflight for implicit discovery and blocked network access.
3. Qualify each primary case with a no-skill run.
4. Author one target skill per valid case and treatment.
5. Validate and hash generated packages without repair.
6. Run fresh natural downstream prompts with implicit skill discovery.
7. Apply deterministic grades, boundary audits, trace audits, and cost extraction.
8. Invoke the reserve only if the frozen stopping rule requires it.
9. Run one aggregate near-miss session per treatment.
10. Compare the creators and generated packages one to one.
11. Publish the decision and path-backed improvement recommendations.

## Session budget

The clean path has 12 decision sessions. The hard maximum is 17. Infrastructure preflight is outside the decision count. Optional sessions are allowed only when they can change the result and remain inside the ceiling.

## Protocol revision 2

The first authoring batch was discarded because Python bytecode appeared under the protected built-in creator tree. The v2-only runner disables bytecode writes and routes any cache prefix under `.tmp/`. All four authoring arms are repeated under the corrected runner, while cases, prompts, treatments, grader, model, and decision rules remain unchanged. The discarded attempts stay inspectable and count toward the hard maximum.

## Claim boundary

This is a one-run operational comparison for Codex CLI 0.147.0, `gpt-5.6-sol`, medium reasoning, the frozen creators, and the declared daily-use families. It does not establish cross-provider or universal superiority. A `mixed` or `inconclusive` result is valid.

## Failure retention

Invalid, contaminated, failed, and non-winning evidence remains inspectable. A failure does not activate or promote the ToolboxMD candidate. A passing benchmark still requires a separate reviewed product change.
