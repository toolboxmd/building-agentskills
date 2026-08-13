# Evidence-backed recommendations

## Release recommendation

Do not promote the frozen ToolboxMD candidate. The corrected benchmark is inconclusive because neither primary case has an eligible no-skill qualification or paired pipeline. Keep ToolboxMD as an inspectable product candidate and use the built-in creator as the current default until a simplified revision wins a new benchmark or demonstrates a clear capability the built-in creator lacks.

Do not rewrite the frozen candidate in place. Build the next candidate from these changes, freeze it, and compare it against both the current ToolboxMD snapshot and the built-in baseline.

## Preserve these ToolboxMD hypotheses

### 1. Compact activation contracts

Keep the current description pattern as a hypothesis to retest: capability, concrete intents, and close exclusions without a workflow summary. The retained ToolboxMD descriptions are 29.5% and 39.2% shorter than their built-in counterparts. All four positive traces loaded a target, but those command-bearing streams are ineligible. Neither eligible zero-command near-miss stream loaded one. These are diagnostic package and positive-trace observations plus a narrow eligible no-trigger observation, not a demonstrated ToolboxMD advantage.

Acceptance for the next candidate:

- record description characters separately from activated-core size;
- include realistic positive and near-miss prompts;
- verify a load from the trace, not the agent's claim;
- do not broaden a description merely to make it longer or more keyword-rich.

### 2. Mechanisms for deterministic invariants

Keep the instruction to add a script when a mechanical gate catches a real repeated failure. Both ToolboxMD packages generated working validators, and both downstream agents used them successfully.

Keep the boundary between semantic review and mechanical validation. The ToolboxMD deck validator required an explicit claim-boundary review flag and did not pretend to fact-check prose.

### 3. Portable package defaults

Keep optional platform sidecars optional. ToolboxMD omitted `agents/openai.yaml`, and both retained ToolboxMD targets were discovered through portable frontmatter. Those loads are diagnostic because their pipelines are ineligible, so the next benchmark must retest this portability claim.

## Change the ToolboxMD creator

### P0. Make runtime script commands independent of the current directory

Both generated ToolboxMD cores showed commands such as `python3 scripts/validate_outputs.py` or `python3 scripts/validate_deck.py` while the downstream task ran from a separate workspace root. The agents repaired the examples by invoking `.agents/skills/<name>/scripts/...`, so the benchmark passed, but the written command is not directly executable from the normal task directory.

Change the creator and its validator to require one of:

- an explicit `<skill-dir>/scripts/...` placeholder with a stated resolution rule;
- a command that first resolves the installed skill directory;
- a wrapper whose documented current directory is unambiguous.

Add a mechanical validation warning for bare `python3 scripts/`, `node scripts/`, or `bash scripts/` commands when the skill does not first enter its own directory.

### P1. Stop shipping eval artifacts by default

The current creator says that nontrivial skills should prepare two or three evals and a smoke check. In this benchmark that produced:

- one packaged eval file for meeting;
- two packaged eval files plus a 117-line test module for deck;
- packages 29.7% and 53.9% larger than the built-in packages;
- longer authoring duration in both cases;
- no measured downstream quality advantage.

Change the default ownership:

- `toolboxmd-creating-skills` creates the smallest target package and a concise external handoff for what should be tested;
- `toolboxmd-benchmarking-skills` owns comparative, repeated, and trace-based eval suites;
- package-local tests stay only when they validate a bundled deterministic script and materially improve maintainability;
- package-local `evals/` are opt-in or justified by an explicit distribution requirement.

### P1. Treat an always-read reference as activated core

All four positive runs loaded the target `SKILL.md` and then immediately read the only reference. Moving required contract text into a reference did not defer its token cost. It added a tool step and made the nominal core look smaller without reducing activated context.

Change the token-budget record to report:

- always-listed description;
- `SKILL.md`;
- references required on every invocation;
- references loaded only under a condition;
- scripts or assets read by the agent instead of executed directly.

If a short reference is required on every invocation, either inline the load-bearing rules or justify the separate file for maintenance. Do not call unconditional loading progressive disclosure.

### P1. Make Git delivery checks conditional

The frozen creator requires a handoff that states validated, tested, committed, and pushed separately. Two ToolboxMD authoring sessions responded by running unscoped `git status`. The strict re-audit also found scoped Git commands in downstream and built-in streams. Even when stdout is empty or paths are scoped below `output/`, Git may read repository plus system, global, or included configuration metadata outside the run root. More broadly, none of the command-bearing traces records trusted environment, filesystem, or syscall-level network isolation evidence. All eight scored streams are ineligible and every paired comparison is eliminated.

Change the handoff rule:

- always report validation and testing;
- report commit and push only when the destination is a Git repository and the user asked for repository delivery;
- do not inspect ancestor repositories when creating a package in a disposable or non-repository workspace;
- do not run Git unless the benchmark harness explicitly isolates repository and configuration metadata inside the run root.

### P2. Make artifact budgets enforceable

The creator already asks for a token budget and the smallest package, but both ToolboxMD activated cores were 11.6% to 14.1% larger than the built-in cores. Turn the budget from advice into a final comparison:

1. report description characters, core lines and bytes, always-read reference bytes, package files, and package bytes;
2. name the evidence that justifies every support file;
3. delete a file when its benefit is only hypothetical;
4. rerun validation after the deletion pass.

Do not optimize for package bytes alone. A larger script can be justified when it replaces repeated model work or catches an observed failure. The required output is an explicit cost-to-benefit record.

### P2. Keep trigger precision but test likely under-trigger boundaries

The ToolboxMD meeting description correctly excluded untagged notes because the private workflow required explicit tags. That is safer than the built-in description's broader transcript claim. A future description test should also include natural requests with tagged files whose prompt does not repeat the tags, renamed files, and requests phrased as tracker maintenance rather than follow-up writing.

This is a targeted trigger test, not a twenty-query optimization campaign for every new skill.

## Change the repository and benchmark harness

### P0. Require trust-bearing isolation evidence for command execution

Any event stream containing `command_execution`, including an incomplete or started event, must be ineligible unless the harness supplies a separate, independently verifiable evidence channel for:

- a sanitized, recorded environment;
- filesystem read confinement;
- filesystem write confinement;
- syscall-level network enforcement and audit.

The historical JSONL contains no such channel. A failed curl probe, a command allowlist, or a user-controlled assertion cannot establish the invariant. Re-auditing the same 17 streams with zero model sessions added made 15 ineligible: eight scored streams, four discarded authoring streams, two qualifications, and the preflight. Only two zero-command near-miss streams remain eligible for the narrow no-trigger observation.

Detailed command heuristics remain diagnostic reasons. They help explain observed risks, but their completeness is not the eligibility trust boundary.

### P0. Require path proof, not a trusted suffix

Never allow a parent-relative operand merely because its suffix resembles `creator/`, `authoring-sources/`, `output/`, `knowledge/`, or `workspace/`. Resolve it only when the event records an in-root command cwd and the resolved path stays inside the run root. Treat bare `..`, missing cwd, an outside cwd, and commands that change cwd internally as ineligible when the trace cannot prove the effective location.

The corrected auditor retains diagnostic reasons for unprovable parent traversal, outside absolute filesystem operands, and Git execution without trace-backed read isolation. Preserve those findings as inspectable failure detail, but do not mistake command parsing for proof that every possible filesystem or network access was captured.

### P0. Isolate Python and Git before the first model run

Keep `PYTHONDONTWRITEBYTECODE=1` and a run-local Python cache prefix in the runner. Prohibit Git in model runs by default. If a future case genuinely requires Git, the trust-bearing isolation evidence must cover repository metadata, HOME/XDG configuration, global configuration, system configuration, and includes. Staging outside a worktree alone is insufficient.

The bytecode failure consumed four authoring sessions. A correct infrastructure preflight should catch this class before creator output exists.

### P0. Reject under-specified exact assertions

The meeting check required byte-exact CSV action text but the contract did not say whether source terminal punctuation should be retained. Both skills preserved the source punctuation and failed the same check.

For exact-text assertions, require the case contract to state every normalization rule. Otherwise grade parsed CSV fields and declare only semantically relevant equality. A check that fails both treatments for an under-specified convention is diagnostic evidence about the benchmark, not evidence against either creator.

### P0. Freeze every scoring and eligibility tool

The v2 protocol commitment hashed the design, case contracts, run configuration, treatments, and isolated runner, but omitted the supporting grader and event-audit scripts. Their at-result hashes and outputs are retained, yet the omission weakens the independent immutability claim.

Future commitments must include every script that can affect qualification, eligibility, deterministic scores, cost extraction, retention, or the final decision. A post-run hash is useful provenance, but it is not a substitute for a pre-run commitment.

### P1. Reserve repeats for cost-only decisions

The raw deck scores tied on observable utility and ToolboxMD used fewer tokens, while the raw meeting artifacts point in the opposite cost direction. Neither case retains an eligible pair, so neither direction is a benchmark result. Cost is stochastic enough that even a valid single run should not support a confident product ranking.

For the next benchmark:

- qualify cases without a skill first;
- run one paired authoring and downstream sample;
- if a treatment wins on utility, stop that case;
- if utility ties and cost is the only discriminator, spend one paired repeat on that case before opening a third case;
- use a reserve case for a capability split, not to manufacture a cost majority.

### P1. Separate infrastructure retries from the decision budget

Use a small, explicit infrastructure-repair allowance that cannot contribute to scores. Keep the semantic decision budget separate and fixed. Every failed attempt still remains evidence, but a neutral runner defect should not consume the capacity needed for the predeclared tie-break.

### P2. Keep the lean v2 controls

Retain these v2 changes:

- same ordinary workspace in no-skill and skill arms;
- no-skill qualification before authoring;
- natural implicit prompts;
- trace-backed skill-load evidence;
- deterministic downstream checks;
- separate authoring and repeated-use cost;
- blind review only when subjective differences remain after deterministic evidence.

## Next candidate acceptance

The next ToolboxMD candidate should not be promoted merely because these edits make it smaller. It should demonstrate:

1. valid implicit activation and no false positive on the same daily-use families;
2. no regression in critical deterministic utility;
3. cwd-independent executable examples;
4. no unconditional Git inspection in a package-only task;
5. smaller activated context or a path-backed justification for every added byte;
6. lower or statistically stable repeated-use cost on a cost-only tie;
7. a new frozen case or paraphrase set that was not used to author the revision.
