# Case study: AgentsMD routing benchmarks

- **Date:** 2026-09-29
- **Subject:** whether agents read the procedure a Skill's routing table links, before the action it governs, on Claude Code, Codex, Grok Build and OpenCode
- **Issues and PRs:** [toolboxmd/agentsmd#164](https://github.com/toolboxmd/agentsmd/issues/164), [#174](https://github.com/toolboxmd/agentsmd/issues/174), [#182](https://github.com/toolboxmd/agentsmd/issues/182); PRs [#168](https://github.com/toolboxmd/agentsmd/pull/168), [#179](https://github.com/toolboxmd/agentsmd/pull/179), [#181](https://github.com/toolboxmd/agentsmd/pull/181), [#183](https://github.com/toolboxmd/agentsmd/pull/183), [#184](https://github.com/toolboxmd/agentsmd/pull/184)
- **Records:** AgentsMD at commit [`06b7af6`](https://github.com/toolboxmd/agentsmd/tree/06b7af6/docs/work) (v14.5.0), 1,713 run records in three folders
- **Evidence manifest:** [machine-readable manifest](/case-studies/evidence/2026-09-29-agentsmd-routing-benchmarks.json)

AgentsMD ships one Skill, `operations`, whose routing table sends the agent to a procedure file before each kind of action. Three benchmarks in one day measured whether agents actually read that file before acting. Opus 5.5 on Claude Code never loaded the Skill from its description alone (0/40 naive runs); a short session-start pointer fixed that, and rewording triggers as before-clauses fixed every row that still missed. The harness was wrong more often than the Skill: it scored refused reads as reads, scored runs that never acted as passes, and passed 349 unit tests and an independent review while doing so.

Terms such as routing row, before-clause, naive prompt, moment and successful read are defined in the [glossary](https://github.com/toolboxmd/building-agentskills/blob/main/GLOSSARY.md).

## What was measured

The `operations` Skill's [routing table](https://github.com/toolboxmd/agentsmd/blob/06b7af6/skills/operations/SKILL.md) has one row per kind of work. Each row names a trigger and links one or more procedure files. The question for every row: on a prompt that needs that row, does the agent read the linked file before it takes the row's action, and does it leave the file alone on a prompt that does not need it?

| Benchmark | Question | Records |
| --- | --- | --- |
| [#164](https://github.com/toolboxmd/agentsmd/issues/164) trigger audit | Do four "before editing X" rows fire on four hosts, and does rewording them help? | [`164-trigger-audit/records.jsonl`](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/164-trigger-audit/records.jsonl), 600 runs |
| [#174](https://github.com/toolboxmd/agentsmd/issues/174) routing injection | Can Claude Code and OpenCode reach 20/20 when something loads the Skill for them? | [`174-routing-injection/records.jsonl`](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/174-routing-injection/records.jsonl) 180 runs, [`midtask.jsonl`](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/174-routing-injection/midtask.jsonl) 40, [`canary.jsonl`](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/174-routing-injection/canary.jsonl) 4; superseded [`records-prefix.jsonl`](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/174-routing-injection/records-prefix.jsonl) 520 and [`midtask-prefix.jsonl`](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/174-routing-injection/midtask-prefix.jsonl) 60 |
| [#182](https://github.com/toolboxmd/agentsmd/issues/182) routing sweep | Does every other row fire on Claude Code, and does the fix regress other hosts? | [`182-routing-sweep/records.jsonl`](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/182-routing-sweep/records.jsonl), 309 runs |

Each folder has a results file written by the agent that ran it: [#164](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/164-trigger-audit/results.md), [#174](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/174-routing-injection/results.md), [#182](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/182-routing-sweep/results.md).

## Setup

### The harness

One script, [trigger_test.py](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/164-trigger-audit/trigger_test.py), runs every benchmark; its tests are [test_trigger_harness.py](https://github.com/toolboxmd/agentsmd/blob/06b7af6/tests/test_trigger_harness.py). It runs one host CLI headless per run, keeps no raw stream, and appends one anonymized record per run: the ordered tool calls up to the moment, the index of the first read of each required file, the index of the moment, failed calls, token usage and a verdict per required file.

**Fixture.** `make_repo` builds a fresh throwaway git repository per run: a small greeter app (`greet`, `add`, `divide`), a README with an Installation section, a test file, a greet Skill with a vague description, a glossary, and a minimal direction triad (VISION, MISSION and OBJECTIVE files). The direction files were added because Codex otherwise stopped before any edit to ask for them, as the AgentsMD global contract requires, so nothing could be measured ([#164 results](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/164-trigger-audit/results.md)). Sweep cases add files and branches per row, for example a `fix/divide` branch with a commit for the delivery row.

**Hosts, models and versions.**

| Host | Version | Models |
| --- | --- | --- |
| Claude Code | 2.1.284 | Opus 5.5, effort medium |
| Codex | 0.159.0 | `gpt-6-astra` low; `gpt-6-luna` high (#164 only) |
| Grok Build | 1.0.44 | `grok-4.7` medium |
| OpenCode | 1.18.33 | Muse 1.3 on the Go route (`opencode-go/muse-spark-1.3-contributor`), default variant |

The OpenCode free route was rate-limited and then refused outside the OpenCode app, so every OpenCode cell uses the Go route ([#164 results](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/164-trigger-audit/results.md)).

**Per-host confinement.** Each run gets a temporary HOME and host configuration directory holding only the arm's global contract (a copy), a copy of the plugin under test, and links to the host's existing login, removed in a `finally`. Nothing was installed into the live configuration.

| Host | Plugin loaded from | Permissions |
| --- | --- | --- |
| Claude Code | `--plugin-dir <copy>` | `acceptEdits`, `--add-dir <repo>` (later also `--add-dir <copy>`, `--allowedTools Bash` and the Bash sandbox; see Fixes) |
| Codex | local marketplace in a temporary `CODEX_HOME`, `codex plugin add` | `-s workspace-write`; `--dangerously-bypass-hook-trust` stands in for the live trusted hook hash |
| Grok Build | `grok plugin install <copy> --trust` in a temporary `GROK_HOME`, plus the live-style Project Direction hook file | `--always-approve` (the live setting) inside `--sandbox workspace` |
| OpenCode | Skill and plugin links into the copy in a temporary `OPENCODE_CONFIG_DIR` | edits and shell allowed, external directories denied except the copy |

**Guard and self-checks.** After every run, the canonical AgentsMD checkout and the harness checkout must match their pre-batch `git status --porcelain --ignored --untracked-files=all` and HEAD, and the live host configuration files their pre-batch content, or the batch aborts. Before its first batch each host passes a guard self-check (a new ignored file is detected) and a cleanup self-check (a setup failure leaves no temporary directory or login link).

**Arms.** Each arm is `git archive` of a named ref, so one batch can compare released rows with candidate wording. Arms are interleaved after the free-route failure showed that running one arm after another lets a rate limit hit only the second.

**Cases.** Naive prompts need a row but never name the Skill or the procedure, for example "The Installation section of README.md is wordy and hard to follow. Rewrite it so it is clear and short." Negative prompts are similar work that needs no procedure, for example fixing a typo. #164 and #174 ran 5 runs per case per arm (four first-edit cases, so 20 naive and 20 negative runs per arm). The #182 sweep ran one naive prompt per row, 3 runs each, re-measured reworded rows 5 times, and scored two shared negatives (a code question and a one-line docstring edit) against all 21 row procedures.

**Moments.** A read counts only before the moment: the first file edit; the first `git commit` or `gh pr create`; a named shell command or tool call (such as `git merge <branch>` for delivery, an Agent or Task call for orchestration, a `grok -p` or `grok --prompt` call for use-grok); or the end of the run, for rows whose action is the answer itself.

**Stubs.** A `gh` stub on PATH answers `gh pr create` and `gh issue create` with a fake URL, so nothing reaches GitHub. A `grok` stub on non-Grok hosts answers without a model call, so the use-grok row spends no credits.

## What failed

Most failures were in the instrument, not the Skill. Each one below changed a number.

### A pilot run escaped into the canonical checkout (#164)

The first entry-loaded pilot ran `claude -p --dangerously-skip-permissions` with the real HOME and no post-run check. With `operations` loaded, the Skill's base directory (the plugin path) was in context; the writing-for-agents prompt named `skills/greet` relatively, so the model resolved it against the plugin, found nothing, searched the parent directory of the checkout and created a greet Skill file in the canonical AgentsMD checkout. Later runs of both arms edited it, and two committed it there; 9 of 10 runs in that cell were affected. All results from that batch were discarded, and the confinement above was built in response ([#164 results](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/164-trigger-audit/results.md), [PR #168](https://github.com/toolboxmd/agentsmd/pull/168)). The pilot model's scores are not part of this study.

### The harness passed its tests while the agent could not read the procedures

[PR #168](https://github.com/toolboxmd/agentsmd/pull/168) merged the harness with 349 unit tests passing, guard and cleanup self-checks passing on all four hosts, and an independent APPROVE on the exact head. Two defects were live:

- **Claude Code could not read the plugin copy.** The Claude command allowed only the run's repository (`--add-dir <repo>`), so `claude -p --permission-mode acceptEdits` refused every Read or `cat` of a procedure file in the plugin copy. The live setting is `bypassPermissions`, so live use was not affected ([#174 results](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/174-routing-injection/results.md)).
- **The scorer counted the refused attempt as a read**, and scored a positive run that never edited as `fired`.

The first #174 batch shows the effect. Arm B (the pointer) scored Opus 17/20 "target read before first edit", and 10 of those 17 runs never edited; arm C had the same 10 of 17 ([`records-prefix.jsonl`](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/174-routing-injection/records-prefix.jsonl), recomputed from `first_edit`). An independent analysis for #174 (Opus 5.5 xhigh) reproduced the refusals in the harness's own configuration: every procedure read appeared in `permission_denials`, and the model stopped because it could not read the procedure. The analysis report is not public; [#6](https://github.com/toolboxmd/building-agentskills/issues/6) summarizes it. None of the Claude cells in that batch are valid, including the A/B/C comparison.

### OpenCode refused reads through the Skill's config-directory link (#174)

OpenCode gives the Skill's base directory as the config-directory link, which the harness's `external_directory` rule denied; the model then retried through the plugin path. Those reads are OpenCode `error` parts, and the old scorer counted them. The OpenCode cells of the first #174 batch are invalid for the same reason ([#174 results](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/174-routing-injection/results.md), [PR #179](https://github.com/toolboxmd/agentsmd/pull/179)).

### No-edit runs scored as passes

A run that read the procedure and then stopped had no first edit to score against, and the scorer returned `fired`. That is how the 10 no-edit runs above became hits.

### `acceptEdits` hid the verification moment (#174)

After the read fix, Claude still could not reach `gh pr create`: `claude -p --permission-mode acceptEdits` denied every non-read Bash call (`git checkout -b`, the tests, the commit), so Opus edited and ended without attempting the PR. [PR #179](https://github.com/toolboxmd/agentsmd/pull/179) reported the cell as not measurable (0 of 10 runs reached `gh pr create`).

### Shell reads with a non-zero chained exit were dropped (#174)

Claude reports a chained command such as `cat prose.md; ls missing` as an error although the file was read. The scorer treated any errored call as a failed read. A diagnostic canary with tool results visible exposed it ([PR #181](https://github.com/toolboxmd/agentsmd/pull/181)).

### Allowing Bash opened the whole machine, and the first sandbox confined writes only

`--allowedTools Bash` let the model's shell reach any path, while the guard only snapshots selected checkouts and configuration; an escape elsewhere would pass unseen. The first fix used Claude Code's Bash sandbox, whose default confines writes but leaves reads open to the whole computer, including the keychain link in the temporary HOME. Independent reviews flagged both as High, on #181 and on #183 ([PR #183](https://github.com/toolboxmd/agentsmd/pull/183)).

### The sweep's own instrument errors (#182)

Reading every miss's call list exposed four more ([#182 results](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/182-routing-sweep/results.md), [PR #184](https://github.com/toolboxmd/agentsmd/pull/184)):

- **Moments matched the wrong action.** `git tag` (listing) and `git merge-base` counted as releasing; `command -v grok` counted as consulting Grok. Those delivery and use-grok runs were dropped and rerun.
- **The fixture made the action impossible.** The `fix/divide` branch had no commits, so there was nothing to merge and Opus correctly stopped.
- **Record keys collided.** Many procedures are named `index.md`, and the negatives' keys collapsed into one; the first negative batch was dropped and rerun.
- **Reads through `cd <dir> && cat <file>` were missed**, because the scorer looked for the joined path.

Re-scoring every kept call list under the final rules changed 12 verdicts: 10 runs that read the procedure and took no action (previously misses) and 2 domain-modeling runs that read through `cd <dir> && cat <file>`.

### What the routing itself got wrong

With a valid instrument, the Skill had four real gaps:

1. **Descriptions alone do not load the Skill on Claude Code.** Opus 5.5 loaded `operations` in 0/40 naive runs in #164 and edited directly, although the global contract tells every host to invoke it. Codex and Grok loaded it 20/20.
2. **A bare conjunct is optional to Opus.** The writing-for-agents row read "Writing for agents **and prose**; SKILL-MECHANICS.md **before editing a SKILL.md or a Skill description**". On a Skill-description prompt Opus read SKILL-MECHANICS.md, the file inside the before-clause, and skipped prose.md, the bare second link. In the fixed #174 base arm it read neither (0/5 each); once the pointer loaded the Skill and prose had its own before-clause, it read both 5/5. Injecting the whole routing table at session start (pre-fix arm A) did not help: SKILL-MECHANICS.md 5/5, prose.md 0/5 (read attempts, [`records-prefix.jsonl`](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/174-routing-injection/records-prefix.jsonl)). Codex and Grok read every link in the row.
3. **A trigger that does not name the action does not fire.** "Choose or run proof, review, or claim readiness" never names opening a PR; Opus read verification.md before `gh pr create` in 0/5 runs on both arms ([`midtask.jsonl`](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/174-routing-injection/midtask.jsonl)).
4. **Answer-only work never opened the Skill.** Research, prototype and grilling missed (0/3, 1/3, 2/3) because the pointer named only the first edit, commit, Issue and PR. Diagnosis missed (0/3) for a different reason: Opus reproduced before reading.

## Fixes

### Instrument

| Fix | Where | Effect |
| --- | --- | --- |
| Successful-read scoring: `failed_calls` lists Claude tool uses in the result event's `permission_denials` or answered by an error, and OpenCode parts in state `error`; those are attempts, not reads | [PR #179](https://github.com/toolboxmd/agentsmd/pull/179) | Refused reads stop counting |
| `read-noedit` and `skip-noedit` for positive runs with no edit; `read-noaction` and `skip-nomoment` when the moment never happens | #179, #184 | No-action runs get their own verdict |
| `--add-dir <plugin copy>` on Claude | #179 | Procedure reads succeed |
| OpenCode's config directory allowed, as the live `"permission": "allow"` does | #179 | Reads through the Skill link succeed |
| `--allowedTools Bash` on Claude | [#181](https://github.com/toolboxmd/agentsmd/pull/181) | The verification moment is reachable: `gh pr create` reached in 10/10 runs |
| A shell call fails only when it is in `permission_denials`; Read calls still fail on an error result | #181 | Chained reads with a non-zero exit count |
| Claude Code Bash sandbox in the temporary HOME: `sandbox.enabled: true`, `allowUnsandboxedCommands: false`, `failIfUnavailable: true`, `filesystem.denyRead` of the real home and the keychain link, `filesystem.allowRead` of the temporary HOME (a narrower rule wins) | [#183](https://github.com/toolboxmd/agentsmd/pull/183) | Shell writes limited to the repository, the `--add-dir` directories and the per-user temp directory; shell reads of the real home and login denied |
| Moments match only the real action (`git merge <branch>`, `git tag v1.0.1`, `grok --prompt-file`); fixture branches carry commits; record keys use the full path when names collide; a shell read matches every path part | [#184](https://github.com/toolboxmd/agentsmd/pull/184) | 12 verdicts changed on re-scoring |

Each is pinned in [test_trigger_harness.py](https://github.com/toolboxmd/agentsmd/blob/06b7af6/tests/test_trigger_harness.py).

The sandbox was proven with real denials, not only a settings test. In smoke runs (Opus 5.5 medium, harness setup) a `cat` of a file in a fresh directory under the real home, a `touch` there, and an `ls` of the temporary HOME's keychain link all got `Operation not permitted`, and no file was created. `head` of the repository README and of the plugin copy's SKILL.md, and a `touch` in the repository, succeeded. Branch, commit, a python import, a `cat` of a procedure and `gh pr create` behaved as before, so the benchmark was not rerun. A first smoke prompt that named the keychain file was refused by the model as credential access, so the check lists the link instead ([PR #183](https://github.com/toolboxmd/agentsmd/pull/183)).

### Routing

| Fix | Where | Before | After |
| --- | --- | --- | --- |
| Session-start pointer on Claude Code and OpenCode: 417 characters (about 105 tokens) naming the Skill and the first edit, commit, Issue and PR | [#179](https://github.com/toolboxmd/agentsmd/pull/179) | Opus 3/20 naive (base) | 20/20 |
| One before-clause per required file: "...; prose before editing a SKILL.md, AGENTS.md, CLAUDE.md, or other agent instructions; SKILL-MECHANICS.md before editing a SKILL.md or a Skill description" | #179 | writing-for-agents prose.md 0/5 (base) | 5/5 |
| Name the next required file in the file the model reliably reads: SKILL-MECHANICS.md's opening names prose | #179 | not measured alone | writing-for-agents 5/5 on all four hosts (B3) |
| Name the action in the trigger: "Before opening or updating a PR, claiming readiness, or choosing or running proof or review" | [#184](https://github.com/toolboxmd/agentsmd/pull/184) | verification 0/5 | 5/5 |
| Widen the pointer to every task start and each new kind of action: "at the start of every task, and again before each new kind of action (researching, an experiment, reproducing a defect, the first file edit, a commit, a GitHub Issue or a pull request)"; 482 characters | #184 (fix2) | research 0/3, prototype 1/3, grilling 2/3 | 5/5 each |
| Read the procedure as its own step: "Read it as its own step, before any command for that action", plus the diagnosis row "Before running, reproducing, or testing anything for a defect, a fix, or runtime behavior or performance" | #184 (fix3) | diagnosis 0/3 on main, 8/10 on fix2 | 5/5 |
| Row-level exclusion for the research row: "(not for a direct answer from the code at hand)" | #184 (fix3) | OpenCode question negative 0/5 clean on fix2 | 5/5 clean |

Three intermediate results matter for later work:

- **A task-start wording regressed an action.** fix1's pointer ("before its first tool call … for the next action") fixed research, prototype and grilling but dropped verification to 3/5 and opened the research procedure on the plain question in 2/5 runs. fix2 does neither.
- **Reading in the same call as the action is too late.** On fix2, diagnosis's two misses read the procedure with `cat` in the same shell call that ran the reproduction, so the reproduction was chosen before the procedure was seen.
- **An always-loaded change reaches every host it loads on.** The fix2 pointer made OpenCode load `operations` for every task, including "What does add(2, 3) return? Answer from the code only.", and it then opened the research procedure in 5/5 runs, against 0/5 on the released rows. Opus did not. The negatives on the tuning host alone would have shipped the regression.

## Results

All cells count runs where every required file was read successfully before the moment. Commands to regenerate them are under Reproduce.

### #164: four hosts, released rows (main) against reworded rows (branch)

Arm `main` is `53296e5`; arm `branch` is `ae9e261`. 80 runs per host and model.

| Host, model | Entry point loaded, naive: main / branch | Target read before first edit: main / branch | Negatives clean: main / branch |
| --- | --- | --- | --- |
| Claude Code, Opus 5.5, medium | 0/20 / 0/20 | 0/20 / 0/20 | 20/20 / 20/20 |
| Codex, `gpt-6-astra`, low | 20/20 / 20/20 | 15/20 / 20/20 | 20/20 / 20/20 |
| Codex, `gpt-6-luna`, high | 20/20 / 20/20 | 9/20 / 20/20 | 20/20 / 20/20 |
| Grok Build, `grok-4.7`, medium | 20/20 / 20/20 | 15/20 / 20/20 | 20/20 / 20/20 |
| OpenCode, Muse 1.3 | 16/20 / 16/20 | 0/20 / 16/20 | 20/20 / 20/20 |

Where the entry point loads, the reworded rows make the read happen. Opus never loaded it on a naive prompt, so no wording could act. The OpenCode cells were scored before successful-read scoring existed (see Caveats).

### #174: the pointer, per host

Arms: base `42152be` (v14.3.1), B2 `3dee7d6` (pointer plus the prose before-clause), B3 `cbf7357` (B2 plus the SKILL-MECHANICS.md opening; the shipped state). Target read before the first edit, naive prompts, fixed harness:

| Host, model | base | shipped | Negatives clean |
| --- | --- | --- | --- |
| Claude Code, Opus 5.5, medium | 3/20 | 20/20 (B2); writing-for-agents 5/5 (B3) | 20/20 (B2), 5/5 (B3) |
| OpenCode, Muse 1.3 | 16/20 (#164) | 20/20 (B3) | 20/20 |
| Codex, `gpt-6-astra`, low | 20/20 (#164) | writing-for-agents 5/5 (B2 and B3) | 5/5 each |
| Grok Build, `grok-4.7`, medium | 20/20 (#164) | writing-for-agents 5/5 (B2 and B3) | 5/5 each |

With the pointer, Opus invoked `operations` in 20/20 naive runs (base 4/20). Codex and Grok get no pointer; only the writing-for-agents row changed for them, so that case is their regression check.

Mean tokens per run (input including cache, plus output):

| Host, model | base | B2 | B3 |
| --- | --- | --- | --- |
| Claude Code, Opus 5.5 | 150,264 | 182,323 | 220,378 (writing-for-agents only) |
| OpenCode, Muse 1.3 | not run | 252,247 (writing-for-agents only) | 232,852 |
| Codex, `gpt-6-astra` (writing-for-agents) | not run | 173,287 | 192,131 |
| Grok, `grok-4.7` (writing-for-agents) | not run | 284,978 | 278,897 |

The pointer itself is about 105 tokens; most of the Opus difference is the procedure reads the change asks for.

Mid-task moments, procedure read before the first `git commit` or `gh pr create`:

| Host, model | Version control: base / shipped | Verification: base / shipped |
| --- | --- | --- |
| Claude Code, Opus 5.5, medium | 0/5 / 5/5 | 0/5 / 0/5 |
| OpenCode, Muse 1.3 | 4/5 / 5/5 | 5/5 / 5/5 |
| Codex, `gpt-6-astra`, low (pre-fix batch) | 4/5 | 5/5 |
| Grok Build, `grok-4.7`, medium (pre-fix batch) | 5/5 | 4/5 |

Claude's version-control cell ran with Bash denied (arms `42152be` and `8094d41`) and scores the read against the first `git commit` attempt. Claude's verification cell is the #181 rerun with Bash allowed (arms `42152be` and `3fa82c0`): every run branched, tested, committed and called `gh pr create`, and none read verification.md first.

### #182: every row on Claude Code, Opus 5.5 medium

Arms: main `9578065` (v14.4.x rows), row reword only `c276fd6`, fix1 `0da08e7`, fix2 `4a4f7e1`, fix3 `cc0bb2e` (shipped in v14.5.0). fix3 was measured on verification, research, diagnosis and the negatives; the other rows' text is the same in fix2 and fix3.

"Fired" is the harness's `--summary` count: the procedure was read before the moment, and the moment happened. "Read" also counts `read-noaction` runs, which read the procedure and then stopped without acting; that is the rule the [#182 results](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/182-routing-sweep/results.md) use.

| Row | main: fired / read | fix2: fired / read | fix3 or notes |
| --- | --- | --- | --- |
| context | 3/3 / 3/3 | 3/3 / 3/3 | |
| project-direction | 2/3 / 3/3 | 2/3 / 3/3 | |
| research | 0/3 / 0/3 | 5/5 / 5/5 | fix1 5/5; fix3 5/5 |
| software-design | 3/3 / 3/3 | 3/3 / 3/3 | |
| prototype | 1/3 / 1/3 | 5/5 / 5/5 | fix1 5/5 |
| diagnosis | 0/3 / 0/3 | 8/10 / 8/10 | fix1 5/5; fix3 5/5 |
| grilling | 2/3 / 2/3 | 5/5 / 5/5 | fix1 5/5 |
| wayfinder | 3/3 / 3/3 | 3/3 / 3/3 | |
| to-spec | 3/3 / 3/3 | 3/3 / 3/3 | |
| implementation | 3/3 / 3/3 | 3/3 / 3/3 | |
| orchestration | 3/3 / 3/3 | 3/3 / 3/3 | |
| project-verification | 3/3 / 3/3 | 3/3 / 3/3 | |
| artifacts | 3/3 / 3/3 | 3/3 / 3/3 | |
| reflection | 3/3 / 3/3 | 3/3 / 3/3 | |
| preferences-pruning | 3/3 / 3/3 | 3/3 / 3/3 | |
| delivery-profile | 3/3 / 3/3 | 3/3 / 3/3 | |
| delivery | 1/3 / 3/3 | 3/3 / 3/3 | |
| finalization | 0/3 / 3/3 | 0/3 / 3/3 | |
| repository-setup | 0/3 / 3/3 | 0/3 / 3/3 | |
| reconciliation | 0/3 / 3/3 | 0/3 / 3/3 | |
| use-grok | 3/3 / 3/3 | 3/3 / 3/3 | |
| verification | 0/5 (#181) | 5/5 / 5/5 | row reword only 5/5; fix1 3/5; fix3 5/5 |
| domain-modeling (#174 case) | not run | 8/8 | |
| technical-writing (#174 case) | not run | 3/3 | |
| test-design (#174 case) | not run | 3/3 | |
| writing-for-agents (#174 case) | not run | 3/3 | |

Finalization, repository setup and reconciliation always read and then stopped: their actions delete branches or change repository settings, and the fixture offers no Issue or remote. The main verification cell comes from #181's `midtask.jsonl`, not from the sweep records.

Negatives (two shared prompts, every row's procedure): clean on main 6/6, fix2 10/10 and fix3 10/10; on fix1 the question prompt opened the research procedure in 2/5. The #174 first-edit negatives stayed clean on fix2 (17/17).

Other hosts, 5 runs each, on `10ece7c` (fix2 plus the final scorer) unless marked:

| Host, model | Verification before `gh pr create`: fired / read | Question negative clean |
| --- | --- | --- |
| Codex, `gpt-6-astra`, low | 3/5 / 5/5 (2 read, no PR) | 5/5 |
| Grok Build, `grok-4.7`, medium | 5/5 / 5/5 | 5/5 |
| OpenCode, Muse 1.3 | 5/5 on fix2; 5/5 on fix3 | 0/5 on fix2; 5/5 on main `9578065`; 5/5 on fix3 |

OpenCode on fix3 also read the research procedure 5/5. Before #184 the verification cells were Codex 5/5, Grok 4/5 and OpenCode 5/5 (#181's `midtask-prefix.jsonl` and `midtask.jsonl`), so verification did not regress.

### Post-install canaries

One naive technical-writing prompt per host against the live installs (not harness copies), in a fresh throwaway repository. prose.md was read before the first edit on all four hosts both times, and the canonical checkout was unchanged afterwards:

- v14.4.0: 4/4 ([`canary.jsonl`](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/174-routing-injection/canary.jsonl)).
- v14.5.0: 4/4 ([#182 comment 5897168360](https://github.com/toolboxmd/agentsmd/issues/182#issuecomment-5897168360)).

## Caveats

- **#164 records carry no `failed_calls`.** Its cells were scored before successful-read scoring. The OpenCode cells were never rescored and may include reads refused through the config-directory link; the Claude cells are all zero, so they cannot be inflated.
- **Opus base in #174 may be higher than 3/20.** The [#174 results](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/174-routing-injection/results.md) say two base-arm test-design runs read test-design.md through a chained `cat` that exited non-zero and were scored `skip` under the rule then in force, so the base may be 5/20. The kept call lists show one such read before the first edit (test-design run 4). No shipped-arm cell is affected.
- **The pre-fix batches are invalid for Claude Code and OpenCode**: [`records-prefix.jsonl`](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/174-routing-injection/records-prefix.jsonl) and the Claude and OpenCode cells of [`midtask-prefix.jsonl`](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/174-routing-injection/midtask-prefix.jsonl). The one conclusion carried forward from them is that the pointer gets Opus to load `operations`.
- **The Codex and Grok mid-task cells come from the pre-fix batch.** The [#174 results](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/174-routing-injection/results.md) state the defects did not affect those hosts; this study did not re-check that.
- **Small samples.** 3 to 10 runs per cell, one model per host, one fixture. The results rank wordings on these prompts; they are not variance estimates.
- **Moments come from tool-call patterns.** A regex decides what counts as a commit, a merge or a release; #182 shows how that goes wrong.
- **The global contract was a copy, not a link.** In 34 of 80 `gpt-6-luna` runs the model searched the temp directory for the canonical clone and read contract files from the batch's archive; none read a target from there or wrote outside its repository ([#164 results](https://github.com/toolboxmd/agentsmd/blob/06b7af6/docs/work/164-trigger-audit/results.md)).
- **`--summary` cannot read `canary.jsonl`**: the canary records have no `source` or `login_files_changed` field and the summary raises `KeyError`. The 4/4 is counted from the four records' `verdict` fields.
- **Evidence, not release gates.** AgentsMD treats these benchmarks as evidence. Behavioral Live Verification in real projects stays with the user.

## Lessons for Skill design, routing and trigger benchmarks

For Skill and routing design:

- **Do not rely on a description to load a Skill on Claude Code.** Opus 5.5 loaded `operations` in 0/40 naive runs from its description and an always-loaded instruction to invoke it; a session-start pointer of 417 characters took it to 20/20.
- **Name the action as a before-clause.** "Before opening or updating a PR" fired where "claim readiness" did not (0/5 to 5/5).
- **Give each required file its own before-clause.** A file joined with "and" was treated as optional by Opus, while Codex and Grok read it.
- **Name the next required file in the file the model reliably reads.**
- **Ask for the read as its own step.** A `cat` in the same shell call as the action does not change the action.
- **Word the pointer for every new kind of action, not only task start.** A one-time task-start check regressed verification to 3/5.
- **Run negatives on every host an always-loaded change reaches.** The pointer tuned on Claude Code made OpenCode over-read research until a row-level exclusion fixed it.

For trigger benchmarks:

- **Count a read only when its tool result succeeded.** Check permission denials, error results and host error parts.
- **Give runs without the action their own verdict.** A read with no edit, PR or merge is neither a hit nor a miss.
- **Grant the harness the reads and commands the live setup allows**, then confine the shell at the OS level and prove the confinement with real denials.
- **Match a moment only on the real action**, and check that the fixture makes the action possible.
- **Read the call lists of every miss.** Four of the #182 instrument errors surfaced only there.
- **Do not read green harness tests as a valid instrument.** #168 merged with 349 passing tests and an APPROVE while the instrument could not see refused reads.

The testing method pages will build on these; see [Benchmark integrity](/docs/06-testing/benchmark-integrity) and [Triggers](/docs/05-authoring/triggers).

## Reproduce

Extract the records read-only and regenerate a table:

```sh
T=$(mktemp -d)
git -C <agentsmd checkout> archive 06b7af6 docs/work tests/test_trigger_harness.py | tar -x -C "$T"
cd "$T/docs/work/182-routing-sweep"
python3 ../164-trigger-audit/trigger_test.py --summary records.jsonl
```

Use the same command in `164-trigger-audit` and `174-routing-injection` for `records.jsonl`, `midtask.jsonl`, `records-prefix.jsonl` and `midtask-prefix.jsonl`. The prefix files include runs outside this study's scope, which are not reported here.

## Sources

- [toolboxmd/agentsmd#164](https://github.com/toolboxmd/agentsmd/issues/164), [#174](https://github.com/toolboxmd/agentsmd/issues/174), [#182](https://github.com/toolboxmd/agentsmd/issues/182) with comments.
- PRs [#168](https://github.com/toolboxmd/agentsmd/pull/168) (harness, reworded first-edit rows, v14.2.0), [#179](https://github.com/toolboxmd/agentsmd/pull/179) (pointer, prose before-clause, read and verdict fixes, v14.4.0), [#181](https://github.com/toolboxmd/agentsmd/pull/181) (Claude verification cell, shell-read rule, v14.4.1), [#183](https://github.com/toolboxmd/agentsmd/pull/183) (Bash sandbox, v14.4.2), [#184](https://github.com/toolboxmd/agentsmd/pull/184) (row sweep and fixes, v14.5.0).
- Records and results at [`06b7af6`](https://github.com/toolboxmd/agentsmd/tree/06b7af6/docs/work), listed with line counts and SHA-256 in the [evidence manifest](/case-studies/evidence/2026-09-29-agentsmd-routing-benchmarks.json).
- The two independent miss analyses for #174 (Opus 5.5 xhigh, Grok 4.7 xhigh), summarized in [toolboxmd/building-agentskills#6](https://github.com/toolboxmd/building-agentskills/issues/6).

Cross-links: [Benchmark integrity](/docs/06-testing/benchmark-integrity), [Triggers](/docs/05-authoring/triggers), [Mechanism vs decoration](/docs/07-mechanism-vs-decoration), [Anti-patterns](/docs/10-anti-patterns).
