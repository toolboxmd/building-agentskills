# Trigger benchmarks

A trigger benchmark measures whether an agent reads the file a description or routing row sends it to, before the action that file governs, and leaves the file alone when the work does not need it. It runs a real host CLI on prompts in a throwaway repository and scores the tool calls, not the answer.

The general rules in [Benchmark integrity](/docs/06-testing/benchmark-integrity) apply: freeze the experiment, guard attribution, isolate runs and keep invalid attempts. This page adds what trigger benchmarks need on top. Every rule comes from the [AgentsMD routing benchmarks](/case-studies/2026-09-29-agentsmd-routing-benchmarks), where the instrument was wrong more often than the Skill; read the case study for the full account. Terms such as naive prompt, moment, successful read and verdict are defined in the [glossary](https://github.com/toolboxmd/building-agentskills/blob/main/GLOSSARY.md). Writing the trigger itself is covered in [Triggers](/docs/05-authoring/triggers).

## Write the decision first

Write down what the benchmark decides before building anything. AgentsMD's three benchmarks each answered one question: does rewording four "before editing X" rows make the read happen on four hosts ([toolboxmd/agentsmd#164](https://github.com/toolboxmd/agentsmd/issues/164)); can a session-start pointer take Claude Code and OpenCode to 20 of 20 ([#174](https://github.com/toolboxmd/agentsmd/issues/174)); does every other row fire, and does the fix regress another host ([#182](https://github.com/toolboxmd/agentsmd/issues/182)). The decision fixes the arms, the hosts and models, the rows under test and what counts as a regression.

Measure the models your users run, on every host the text reaches. Models disagree on the same row: Opus 5.5 skipped a file joined by a bare conjunct that Codex and Grok read, and a pointer that fixed Opus made OpenCode over-read on a question ([case study](/case-studies/2026-09-29-agentsmd-routing-benchmarks)). A cheaper stand-in model answers a different question.

## Build a fixture that makes the action possible

Give each run a fresh throwaway git repository holding everything the prompts need. The AgentsMD fixture is a small app with a README, a test file, a sample Skill, a glossary and the direction files the global contract asks for.

- **Satisfy the rules the agent must follow.** Codex stopped before any edit to ask for missing direction files, as its contract requires, so nothing could be measured until the fixture had them ([#164 results](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/164-trigger-audit/results.md)).
- **Make the action possible.** A delivery case had a `fix/divide` branch with no commits, so there was nothing to merge and Opus correctly stopped. Branches the prompt names must carry commits ([PR #184](https://github.com/toolboxmd/agentsmd/pull/184)).
- **Stub external effects.** A `gh` stub on `PATH` answered `gh pr create` and `gh issue create` with a fake URL, and a `grok` stub answered without a model call, so no run reached GitHub or spent credits ([case study](/case-studies/2026-09-29-agentsmd-routing-benchmarks)).

## Write naive prompts, negatives and moments

- **Naive prompts** need the row but never name the Skill or the procedure. Run at least 5 per prompt and arm for a result you will act on. AgentsMD's #182 sweep used 3 runs per row to find misses, then 5 to re-measure each change.
- **Negative prompts** are similar work that needs no procedure, such as a typo fix or a question about the code. Score each negative against every procedure the change could open: the #182 sweep scored two shared negatives against all 21 row procedures.
- **Moments** are the actions a read must precede: the first file edit, the first `git commit` or `gh pr create`, a named command such as `git merge <branch>`, or the end of the run when the answer is the action. A read counts only before its moment.

Match a moment only on the real action. `git tag` (listing) and `git merge-base` counted as releasing, and `command -v grok` counted as consulting Grok, until the patterns were narrowed to `git tag v1.0.1`, `git merge <branch>` and `grok --prompt-file` ([PR #184](https://github.com/toolboxmd/agentsmd/pull/184)).

## Confine every run

A benchmark run is an agent with write access. The first AgentsMD pilot ran with the real HOME, skipped permissions and had no post-run check; the model resolved a relative path against the plugin, searched upward and created a file in the canonical checkout. Later runs edited that file and two committed it; 9 of 10 runs in the cell were affected and the batch was discarded ([#164 results](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/164-trigger-audit/results.md), [PR #168](https://github.com/toolboxmd/agentsmd/pull/168)).

Confine each run as follows ([PR #168](https://github.com/toolboxmd/agentsmd/pull/168), [PR #183](https://github.com/toolboxmd/agentsmd/pull/183)):

1. **Temporary HOME and host configuration** holding a copy of the global instructions for the arm, a copy of the plugin under test, and links to the host's existing login. Install nothing into the live configuration.
2. **Cleanup on failure.** Remove the temporary directories and login links in a `finally`, and self-check that a setup failure leaves none behind.
3. **A snapshot guard on real checkouts.** Before the batch, record `git status --porcelain --ignored --untracked-files=all` and `HEAD` of every checkout a run could reach, and the content of live host configuration files. Compare after every run and abort the batch on any change. Self-check that the guard detects a new ignored file. Account for the harness's own writes: an AgentsMD batch aborted when its record append and a stray `__pycache__` changed the checkout it guarded ([#164 results](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/164-trigger-audit/results.md)).
4. **A shell sandbox that confines reads and writes.** The snapshot guard sees only what it snapshots. Allowing the shell let the model reach any path, and Claude Code's Bash sandbox by default confines writes only, leaving the real home and the login keychain readable. The fix was a sandbox with `allowUnsandboxedCommands: false`, `failIfUnavailable: true`, `filesystem.denyRead` of the real home and the keychain link, and `filesystem.allowRead` of the temporary HOME ([PR #183](https://github.com/toolboxmd/agentsmd/pull/183)).
5. **Proof with real denials.** A settings test does not show the sandbox works. In AgentsMD's smoke runs, a `cat` and a `touch` in a fresh directory under the real home and an `ls` of the keychain link all got `Operation not permitted`, while reads of the repository and the plugin copy, and a write in the repository, succeeded.
6. **Credential locations probed by listing, never reading.** A smoke prompt that named the keychain file was refused by the model as credential access; the check lists the link instead ([PR #183](https://github.com/toolboxmd/agentsmd/pull/183)).

## Make the instrument valid

The scorer decides every number. Each rule below changed an AgentsMD result.

- **Count a read only when its tool result succeeded.** A refused or failed read is an attempt. Claude Code lists refused tool uses in the result event's `permission_denials`, and OpenCode marks them as parts in state `error`. Before this fix, Opus scored 17 of 20 on an arm where every procedure read had been refused ([PR #179](https://github.com/toolboxmd/agentsmd/pull/179)).
- **Grant the reads and commands the live setup allows.** Claude Code in `acceptEdits` with only `--add-dir <repo>` refused every read of the plugin copy; the live setting is `bypassPermissions`. OpenCode denied reads through the Skill's config-directory link, which it reports as the Skill's base directory. `acceptEdits` also denied every non-read shell call, so no run reached `gh pr create` (0 of 10) until the shell was allowed and then sandboxed ([PR #179](https://github.com/toolboxmd/agentsmd/pull/179), [PR #181](https://github.com/toolboxmd/agentsmd/pull/181)).
- **Give a run without the action its own verdict.** A run that reads the procedure and stops has no moment to score against. The old scorer called it `fired`: 10 of the 17 runs above never edited. Use separate verdicts for read-then-no-edit (`read-noedit`) and read-then-no-action (`read-noaction`), and their skip counterparts ([PR #179](https://github.com/toolboxmd/agentsmd/pull/179), [PR #184](https://github.com/toolboxmd/agentsmd/pull/184)). Report them beside the fired count, not inside it.
- **Count shell reads the way the shell runs them.** The scorer missed `cd <dir> && cat <file>` because it looked for the joined path ([PR #184](https://github.com/toolboxmd/agentsmd/pull/184)), and missed brace lists such as `references/{implementation,test-design}.md` until it expanded them ([#164 results](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/164-trigger-audit/results.md)).
- **A chained command that exits non-zero may still have read.** Claude Code reports `cat prose.md; ls missing` as an error although the file was read. Treat a shell call as failed only when it was denied; keep error results as failures for the Read tool ([PR #181](https://github.com/toolboxmd/agentsmd/pull/181)).
- **Use unique record keys.** Many procedures are named `index.md`; the negatives' keys collapsed into one until keys used the full path where names collide ([PR #184](https://github.com/toolboxmd/agentsmd/pull/184)).

Re-scoring every kept call list under the final #182 rules changed 12 verdicts ([case study](/case-studies/2026-09-29-agentsmd-routing-benchmarks)).

## Interleave arms

Run arms in alternation, not one after another. On the OpenCode free route a rate limit hit mid-batch; with arms in sequence it would hit only the second arm and read as a wording effect ([#164 results](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/164-trigger-audit/results.md)). Build each arm from `git archive` of a named ref, so one batch compares released text with a candidate.

## Keep records and regenerate every table

- **Commit one anonymized record per run.** AgentsMD's record holds the host, model, effort, arm, case, the ordered tool calls up to the moment with home and repository paths replaced by placeholders, the index of each required file's first successful read, the moment's index, failed calls, token usage and a verdict per required file. It keeps no raw stream.
- **Regenerate every table from records.** One command, `trigger_test.py --summary <records>.jsonl`, rebuilds each AgentsMD table ([case study, Reproduce](/case-studies/2026-09-29-agentsmd-routing-benchmarks)). Keep one record schema: the post-install canary records lacked two fields, and the summary raised `KeyError` on them.
- **Keep invalid batches, marked.** AgentsMD kept `records-prefix.jsonl` and `midtask-prefix.jsonl` after the read fixes and marked them superseded, so the invalid numbers can still be inspected ([#174 results](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/174-routing-injection/results.md)).

## Check the instrument, not only its tests

A green unit suite does not prove the instrument observes anything. [PR #168](https://github.com/toolboxmd/agentsmd/pull/168) merged the harness with 349 passing tests, passing guard and cleanup self-checks on all four hosts, and an independent approval, while Claude Code could not read the procedures and the scorer counted the refusals as reads.

- **Read the call list of every miss.** Four of the #182 instrument errors surfaced only there ([#182 results](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/182-routing-sweep/results.md)).
- **Run a diagnostic canary with tool results visible.** One exposed the dropped chained reads ([PR #181](https://github.com/toolboxmd/agentsmd/pull/181)).
- **Suspect a result that jumps.** 17 of 20 on an arm that could not read anything was the first sign of the refused-read defect.

Report what a benchmark proves and what it does not. AgentsMD's cells are 3 to 10 runs on one fixture and one model per host: they rank wordings on those prompts; they are not variance estimates.

## Sources

- [AgentsMD routing benchmarks case study](/case-studies/2026-09-29-agentsmd-routing-benchmarks) and its evidence manifest.
- toolboxmd/agentsmd results at `06b7af6`: [#164](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/164-trigger-audit/results.md), [#174](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/174-routing-injection/results.md), [#182](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/182-routing-sweep/results.md); harness [trigger_test.py](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/164-trigger-audit/trigger_test.py) and [test_trigger_harness.py](https://github.com/toolboxmd/agentsmd/blob/06b7af6/tests/test_trigger_harness.py).
- toolboxmd/agentsmd PRs [#168](https://github.com/toolboxmd/agentsmd/pull/168), [#179](https://github.com/toolboxmd/agentsmd/pull/179), [#181](https://github.com/toolboxmd/agentsmd/pull/181), [#183](https://github.com/toolboxmd/agentsmd/pull/183), [#184](https://github.com/toolboxmd/agentsmd/pull/184).

Cross-links: [Triggers](/docs/05-authoring/triggers), [Benchmark integrity](/docs/06-testing/benchmark-integrity), [Unit tests](/docs/06-testing/unit-tests).
