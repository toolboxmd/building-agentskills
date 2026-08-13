# ToolboxMD creating-skills benchmark v2 implementation plan

**Goal:** Execute the frozen v2 design, preserve all evidence, decide which creator is better for the declared cases, and produce path-backed repository or product recommendations.

**Worktree:** `building-agentskills-benchmark-v2`

**Branch:** `codex/benchmark-v2`

## Task 1: Freeze the protocol and exact fixtures

Create and validate:

- `benchmarks/toolboxmd-creating-skills/v2/README.md`
- `benchmarks/toolboxmd-creating-skills/v2/rubric.md`
- `benchmarks/toolboxmd-creating-skills/v2/run-config.json`
- three public case contracts;
- exact authoring and downstream fixtures for two primary cases and one reserve;
- per-file and aggregate SHA-256 manifests;
- immutable references to the retained v1 built-in and ToolboxMD creator snapshots.

Run:

```bash
bash tests/toolboxmd-creating-skills-v2-contract.test.sh
```

Do not start treatment runs until this test passes.

## Task 2: Implement staging and deterministic grading

Add v2-only scripts so v1 evidence and claims remain unchanged:

- stage an authoring root with exactly one explicit creator and authoring sources;
- stage a no-skill root with the ordinary downstream workspace only;
- stage a treatment root with the same ordinary workspace plus one generated skill under `.agents/skills/`;
- stage one aggregate near-miss root per treatment;
- grade generic file, Markdown, CSV, JSON, frontmatter, and Marp slide assertions;
- audit Codex events for contamination, token usage, target-skill load, unexpected skill loads, and load order;
- summarize package size and case results without model judgment.

Add fixture tests before relying on each script.

## Task 3: Verify the runner boundary

Use the v2 isolated Codex runner only after a v2 preflight proves:

- `codex-cli 0.147.0` is active;
- `gpt-5.6-sol` with medium reasoning is recorded;
- the local `.agents/skills/` beacon is discovered from a natural prompt;
- its full `SKILL.md` is loaded in the event trace;
- no unrelated skill is loaded;
- an outbound network probe fails;
- plugins, apps, memories, web search, and nested delegation remain disabled.
- Python bytecode writes are disabled and any cache prefix is under `.tmp/`.

If any check fails, stop model runs, retain the preflight evidence, and repair only the harness boundary.

The first authoring batch found exactly such a boundary failure: Python created `__pycache__` under the staged built-in creator. Retain all four initial attempts, freeze the bytecode-only runner correction, rerun preflight, and repeat all four authoring arms symmetrically. Do not change cases, prompts, grading, or treatments.

## Task 4: Qualify the two primary cases without a skill

For each primary case:

1. stage the ordinary workspace with no `.agents/skills/` target;
2. hash protected inputs;
3. run the natural downstream prompt in a fresh session;
4. audit events and the write boundary;
5. grade deterministic outputs;
6. retain the full run regardless of result.

The case qualifies only if at least one critical check fails for a procedural reason and the run had all facts and tools needed to succeed.

If a primary case passes all critical checks, mark it invalid before any treatment sees it. Use the reserve according to the frozen stopping rule. Do not make an already observed treatment look better by rewriting a case.

## Task 5: Author target skills

For every valid case and each treatment:

1. stage byte-identical authoring sources and prompt;
2. expose exactly one creator at `creator/`;
3. run a fresh Codex session;
4. audit contamination and boundaries;
5. retain the generated package without editing;
6. validate the package with the official frozen Agent Skills validator and local package checks;
7. hash the package and record core lines, words, bytes, file count, and authoring tokens.

An invalid package is a treatment failure for that case. Do not repair it.

## Task 6: Run implicit positive use

For every valid generated package:

1. stage the same ordinary workspace used by no-skill qualification;
2. install only that package under `.agents/skills/<target-name>/`;
3. use the same natural downstream prompt;
4. run in a fresh session;
5. prove target `SKILL.md` load from events;
6. reject unexpected skill loads or forbidden commands;
7. verify protected inputs;
8. apply deterministic grading;
9. record runtime tokens and duration.

Not loading the target skill is a positive-trigger failure even if the model produces a plausible artifact from ordinary files.

## Task 7: Apply the stopping rule

After both primary cases:

- if one treatment wins both with no critical regression, do not run the reserve;
- if the result splits, a primary is invalid, or the evidence is tied, run the reserve qualification and paired treatment sequence;
- use a paired repeat only when it can change the decision and when total sessions remain at or below 17;
- never add an attractive new case after seeing an unfavorable treatment result.

Record why each optional session was or was not used.

## Task 8: Measure near-miss precision

After the final evaluated case set is known, stage one fresh near-miss root per treatment containing all target skills authored by that treatment. Run the frozen near-miss prompt set and audit whether any target `SKILL.md` was loaded.

Near-miss results break an otherwise equal utility result. They do not override a critical downstream failure.

## Task 9: Produce the evidence-backed verdict

Create a result directory containing:

- run metadata and raw events;
- final messages and stderr;
- input and output manifests;
- event and boundary audits;
- deterministic grades;
- generated packages;
- a machine-readable result manifest;
- a concise human report;
- a direct one-to-one creator and generated-skill comparison;
- repository and product recommendations tied to observed evidence.

The report must separate:

- what the creator caused;
- what may be one-run model variance;
- what the benchmark cannot establish;
- authoring cost from repeated runtime cost;
- a product defect from a harness defect.

## Task 10: Update durable project knowledge

Update project documentation and the wiki only for the durable decision and validated findings. Do not promote an upstream suggestion or an unreviewed model opinion into doctrine.

If the wiki runtime remains on a legacy configuration, retain the capture and report the migration requirement rather than silently choosing provider, model, effort, process count, or scheduling policy.

## Task 11: Verify and publish the branch

Run at minimum:

```bash
npm test
npm run build:docs
git diff --check
```

Inspect the final diff and confirm the original checkout's protected drafts remain untouched. Commit all useful evidence, including a failed or mixed benchmark result. Push `codex/benchmark-v2` and open a PR whose summary separates changes, checks, result, claim boundary, and known issues.

Do not merge without review or explicit user approval.
