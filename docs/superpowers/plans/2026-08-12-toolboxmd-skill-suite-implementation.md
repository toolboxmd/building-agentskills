---
title: ToolboxMD creator and first benchmark implementation plan
status: EXECUTED, STOPPED AT BENCHMARK GATE; RESULT LATER CORRECTED TO INCONCLUSIVE
date: 2026-08-12
owner: lukemaj
design: docs/superpowers/specs/2026-08-12-toolboxmd-skill-suite-design.md
scope: tranche 1 only
execution_authorization: user approved conditional execution after the design gate on 2026-08-12
execution_result: benchmarks/toolboxmd-creating-skills/v1/results/2026-08-12/manifest.json
---

# ToolboxMD creator and first benchmark implementation plan

## Execution result

Executed on 2026-08-12. The design gate passed, the creator candidate and benchmark harness were implemented, and execution stopped at the promotion gate. A later post-result isolation-evidence correction made all 15 retained command-bearing model streams ineligible, so the comparison is inconclusive rather than evidence of a tie or built-in win. The candidate remains only as a retained result artifact because it did not clear the promotion gate. No updater, reusable benchmarking skill, watcher, scheduler, public recommendation, or loader change was implemented.

## Goal

Implement `toolboxmd-creating-skills`, run one small contamination-aware benchmark against the frozen current built-in `skill-creator`, and stop at the benchmark decision gate.

Do not implement the updater, reusable benchmark skill, source watcher, scheduler, automatic pull request flow, or auto-merge.

The user authorized this tranche to execute if the design gate passes. A material design contradiction still stops execution and returns to the user.

## Preflight

1. Confirm `main` still matches `origin/main` at the start of implementation.
2. Confirm the only pre-existing untracked paths are the protected `TODO.md` and May drift-prevention draft, or report any new unrelated path.
3. Do not stage, modify, move, or describe either protected draft as shipped.
4. Record the whole-package baseline `skill-creator` hash, Codex CLI version, model, reasoning effort, and upstream source SHAs.
5. Record the existing Claude manifest validation failure as out of scope. Do not repair it inside tranche 1.
6. Run the existing full test suite before changing shared contracts.

Expected preflight result: the repository is healthy and tranche 1 can proceed without executing the old watcher draft.

## Task 1: Freeze the public benchmark contract before the candidate

Create:

- `benchmarks/toolboxmd-creating-skills/v1/README.md`
- `benchmarks/toolboxmd-creating-skills/v1/rubric.md`
- `benchmarks/toolboxmd-creating-skills/v1/run-config.json`
- `benchmarks/toolboxmd-creating-skills/v1/commitments.json`
- `benchmarks/toolboxmd-creating-skills/v1/baselines/codex-skill-creator-0.147.0/`
- `benchmarks/toolboxmd-creating-skills/v1/case-contracts/webhook-triage.md`
- `benchmarks/toolboxmd-creating-skills/v1/case-contracts/csv-sanitizer.md`
- `benchmarks/toolboxmd-creating-skills/v1/case-contracts/release-evidence.md`

Each case contract freezes:

- the archetype, domain boundaries, and required skill name;
- visible source-material shape and hidden downstream challenge shape;
- required authored and downstream outputs;
- critical deterministic failures;
- semantic scoring dimensions;
- facts the exact instance generator may vary;
- facts the instance generator may not change.

Do not create exact authoring prompts, downstream prompts, or fixtures yet. Keep the family contracts and rubric outside the fresh-context candidate author's allowed read set.

Copy the full Apache-2.0 licensed built-in baseline package into the baseline directory without modification. Retain its license and add an external per-file manifest containing source-product provenance, file sizes, individual hashes, and the aggregate package hash.

Add a test that fails if the contract set is not exactly three cases, required fields are missing, or run configuration omits the frozen baseline package hash and harness metadata. Run the test and confirm it fails before the complete contract set exists, then passes after it is complete.

## Task 2: Add a deterministic skill-package validator

Prefer the pinned official validator:

```bash
uvx --from 'git+https://github.com/agentskills/agentskills@69ef37e9424c0a7ea9dd2293b559e43ec8176379#subdirectory=skills-ref' skills-ref validate <skill-dir>
```

Add only the smallest repository wrapper needed to make its invocation and failure output stable for tests. Do not reimplement the Agent Skills specification unless the pinned validator cannot run in this environment.

Create a fixture test covering:

- one valid minimal skill;
- name and directory mismatch;
- missing description;
- overlong description;
- a broken referenced path when the repository wrapper checks references beyond the official validator.

Run the focused validator test, then the full suite because this adds a shared contract.

## Task 3: Implement `toolboxmd-creating-skills`

Create:

- `skills/toolboxmd-creating-skills/SKILL.md`
- `skills/toolboxmd-creating-skills/agents/openai.yaml`
- only those `references/` or `scripts/` files justified by the creator contract, authoritative doctrine, and observed authoring needs

Use a fresh-context background author for the candidate. It may inspect the creator contract and named doctrine sources, but not `benchmarks/toolboxmd-creating-skills/v1/`, the benchmark rubric, the case-family section of the design, or benchmark outputs. Audit its reads. The orchestrator may request only source-grounded or mechanical corrections before freeze, never case-specific tailoring.

Requirements:

- Directory and frontmatter name are `toolboxmd-creating-skills`.
- Description states what the skill does, when it triggers, and the boundaries against updating and benchmarking.
- Portable frontmatter does not use Claude-only control fields.
- The body explicitly applies the three-question framework.
- The first gate is the primitive decision.
- Real artifacts and source provenance outrank generic generated expertise.
- Instructions remain the default; scripts are added for repeated deterministic work.
- The creator prepares proportionate eval prompts but does not embed the full comparative benchmark workflow.
- The body remains below 500 lines and targets a substantially smaller core.
- `agents/openai.yaml` contains matching display name, short description, and default prompt, without invented icon or dependency metadata.

Validate the candidate with the pinned validator. Check every referenced path. Run any bundled script tests. Run the full repository suite.

## Task 4: Freeze the candidate and generate held-out instances

1. Hash every file in `skills/toolboxmd-creating-skills/` and record the closure in `commitments.json`.
2. From a fresh-context background agent, generate the exact English authoring prompts, downstream prompts, and synthetic fixtures from the three tracked case contracts.
3. Instruct the instance generator not to inspect the baseline, candidate, rubrics beyond the named case contract, or any benchmark output. Audit its reads.
4. Write exact cases under an ignored `.benchmark-work/toolboxmd-creating-skills-v1/sealed-cases/` directory.
5. Hash the exact cases before any treatment run and append those hashes to the run-local freeze manifest.
6. Do not revise the candidate after revealing exact cases. A candidate revision starts a new benchmark iteration with newly generated held-out instances.

## Task 5: Prove isolation and prepare run roots

Create an ignored run workspace outside tracked source inputs. For each case and arm:

1. Create a task-specific `CODEX_HOME` and link only the existing Codex authentication file into it without printing its contents.
2. Let Codex materialize its system skill paths, then pass an explicit `skills.config` deny-list for every discovered system and user skill.
3. Run a preflight prompt that lists visible skills. The expected result is exactly `NONE`. This was demonstrated on Codex 0.147.0 during design review and must be repeated by the final harness.
4. Run an outbound-access preflight in the same sandbox. It must fail. Record the command and exit evidence; Codex 0.147.0 JSONL does not expose the effective network-policy field.
5. Create a unique run root.
6. Copy the case inputs and exactly one creator package into the root.
7. Write a SHA-256 inventory before execution.
8. Exclude sibling runs, graders, identity maps, repository docs, user memory, and prior output from the run root.
9. Use Codex with explicit frozen settings and the generated deny-list:

```bash
codex exec \
  --ephemeral \
  --ignore-user-config \
  --ignore-rules \
  --skip-git-repo-check \
  --sandbox workspace-write \
  --model gpt-5.6-sol \
  --config model_reasoning_effort=\"medium\" \
  --config 'skills.config=<generated-deny-list>' \
  --json \
  --cd <run-root> \
  -
```

10. Include the neutral attribution and read-boundary guard in both arms.
11. Capture JSONL events, final message, exit status, duration, usage metadata, and any sandbox metadata exposed by Codex.

If the skill preflight shows any visible skill or outbound access succeeds, stop before scoring. If a run reads a forbidden location, delegates to another model or agentic CLI, or sees the other treatment, mark it invalid and preserve it under `failed-attempts/`. Do not score it.

## Task 6: Run six authoring passes

For each of the three cases, start the baseline and candidate arms from clean roots with identical case material.

Required output from each arm:

- one generated skill directory;
- a short final report naming created files and validations actually run;
- no unrelated files outside its assigned output directory.

After each pass:

1. Record exit state and observed model metadata.
2. Audit events for nested delegation and obvious forbidden reads.
3. Run deterministic package validation.
4. Freeze and hash the generated package.
5. Do not edit the generated package.

If one arm fails because the prompt or harness is ambiguous for both treatments, amend the protocol neutrally, hash the amendment, and restart both arms for that case. If the failure is treatment-specific, retain it as benchmark evidence.

## Task 7: Run six downstream-use passes

For each generated package:

1. Create a new clean root containing only the generated skill, downstream prompt, and held-out inputs.
2. Run the frozen Codex configuration with the same attribution and read guard.
3. Save final output and required artifacts.
4. Run deterministic case assertions.
5. Preserve failures without repair.

The downstream agent receives the generated skill explicitly. Trigger auto-discovery is not part of this first quality benchmark and remains a later real-harness smoke test.

## Task 8: Blind grade and decide

Create A/B review bundles by copying the frozen artifacts byte for byte beneath neutral parent directories. Keep the identity map outside the blind reviewer root. Do not rewrite, redact, or normalize the contents of the generated skill or downstream output.

Run a deterministic identity scan before judging. If creator names, treatment labels, source paths, or identity-map content occur inside an artifact, preserve the original and invalidate the pair. Parent-directory renaming is the only permitted transformation.

The reviewer receives:

- A and B generated packages;
- A and B downstream outputs;
- shared case fixtures needed for fidelity checks;
- deterministic results with treatment labels removed;
- `rubric.md`.

The reviewer must select `A`, `B`, or `tie` for each case and cite concrete paths and observed behavior. Validate grading arithmetic and cited paths before revealing the identity map.

Apply the design acceptance rule:

- pass if ToolboxMD wins at least two cases and has no critical regression;
- repeat only one ambiguous pair if needed;
- stop and report if ToolboxMD loses two cases, has a critical regression, or the benchmark is contaminated.

## Task 9: Record evidence without overstating it

Create:

- `benchmarks/toolboxmd-creating-skills/v1/results/` with compact inspectable artifacts;
- `case-studies/evidence/2026-08-12-toolboxmd-creating-skills-benchmark.json`;
- a concise case study only if the result supports a reusable claim.

After grading, copy the exact sealed cases into tracked results so the experiment is reproducible. Verify their tracked hashes match the pre-run freeze manifest.

The manifest records:

- decision and claim boundary;
- source and treatment hashes;
- CLI, model, reasoning, and sandbox settings;
- eligible and invalid run counts;
- deterministic and semantic results separately;
- cost and duration when available;
- protocol amendments;
- retained artifact hashes;
- explicit one-run interpretation limit.

Regenerate `public/llms.txt` only if a tracked Mintlify document or case study enters the public corpus. Do not regenerate it merely because benchmark fixtures changed.

## Task 10: Update durable navigation and project wiki

If the benchmark passes:

- add the new creator to the README skill map;
- update the thin loader only if it must point readers to the new creator, without replacing it;
- update `wiki/index.md` and the relevant concept or entity page;
- append `wiki/log.md`.

If the benchmark fails:

- do not present the candidate as the preferred creator;
- update only benchmark evidence and the wiki decision record needed to explain the failure;
- leave the current loader and public recommendation unchanged.

## Validation matrix

Run, in order:

1. Focused benchmark-contract test.
2. Focused validator test.
3. Pinned `skills-ref validate` on the frozen candidate source, and on its retained result snapshot after a failed gate.
4. Tests for any bundled scripts.
5. `npm test`.
6. `npm run build:docs` if public docs or a case study changed.
7. `git diff --check`.
8. Inspect `git status --short` and confirm the two protected drafts remain unmodified and untracked.

Benchmark runs are evidence, not substitutes for repository tests.

## Commit boundaries

No commit or push occurs before the benchmark decision is known. After a passing result, the recommended local commit split is:

1. `spec: define ToolboxMD skill suite and creator benchmark`
2. `test: freeze ToolboxMD creator benchmark contract`
3. `feat: add toolboxmd-creating-skills`
4. `docs: record ToolboxMD creator benchmark result`

After a failed or inconclusive result, retain the design, contract, candidate, exact cases, failed outputs, and evidence manifest in an evidence-only local commit such as `test: record ToolboxMD creator benchmark failure`. Do not update the loader or publish a superiority claim.

Stage only paths created or modified by this plan. Never stage the two protected drafts. Do not push unless the user explicitly requests publication after reviewing the result.

## Stop conditions

Return to the user before continuing when any of these occurs:

- a primary source contradicts a load-bearing design assumption;
- the official validator cannot be pinned or run and a replacement would materially expand scope;
- the candidate cannot be isolated from baseline or grader material well enough to make a bounded claim;
- the final isolation preflight reports any visible skill;
- a benchmark run shows delegation or cross-run leakage that cannot be fixed with a neutral narrow guard;
- the candidate loses according to the acceptance rule;
- an unrelated working-tree change overlaps a target file;
- proceeding would require modifying either protected draft.

Difficulty, a single invalid run, or an ambiguous case is not by itself a blocker. Preserve the evidence and use the narrow recovery specified above.

## Completion report

Report separately:

- design-gate outcome;
- benchmark decision and claim boundary;
- files changed;
- validations and tests run;
- eligible, invalid, and repeated benchmark runs;
- committed state;
- pushed state;
- recommended next gate for `toolboxmd-benchmarking-skills` or remediation.
