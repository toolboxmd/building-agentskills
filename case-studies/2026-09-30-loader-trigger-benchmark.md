# Case study: does the building-agentskills loader load?

- **Date:** 2026-09-30
- **Subject:** whether the loader Skill in this repository is discovered when installed, and whether agents load it and read a routed page before acting on authoring, audit and tool-description requests, on Claude Code, Codex, Grok Build and OpenCode
- **Issue:** [#17](https://github.com/toolboxmd/building-agentskills/issues/17)
- **Records:** [`evidence/2026-09-30-loader-trigger-benchmark/`](https://github.com/toolboxmd/building-agentskills/tree/main/case-studies/evidence/2026-09-30-loader-trigger-benchmark), 84 run records and the discovery output
- **Evidence manifest:** [machine-readable manifest](/case-studies/evidence/2026-09-30-loader-trigger-benchmark.json)

Nobody had checked that the loader installs or triggers. It did not install: the plugin manifest gave `author` as a string, so Claude Code refused to load the plugin and Grok Build installed it with no Skills. With `author` fixed to an object, all four hosts list the loader. On naive authoring and audit prompts it then loaded and routed to a page before the first edit in every run on every host (32 of 32), and it stayed closed on the negative prompt (10 of 10). On a tool-description prompt Claude Code and Codex never loaded it (0 of 10); one added before-clause in the description took both to loading it 10 of 10.

Terms such as naive prompt, moment, successful read and verdict are defined in the [glossary](https://github.com/toolboxmd/building-agentskills/blob/main/GLOSSARY.md). The method is [Trigger benchmarks](/docs/06-testing/trigger-benchmarks).

## Discovery

### What the docs say

- **Claude Code** scans a plugin's `skills/` directory by default; a `skills` field in `plugin.json` adds directories to that scan and is not needed for `skills/<name>/SKILL.md`. `author` is an object with a required `name`. A manifest that fails validation does not load; `claude plugin validate` reports the same problem Claude Code reports at load ([Plugin manifest reference](https://code.claude.com/docs/en/plugins-reference), read 2026-09-30).
- **Codex** reads Skills from `.agents/skills/` in the repository and `$HOME/.agents/skills/`, from admin and system locations, and from installed plugins; it picks a Skill implicitly by its `description` ([Build skills](https://learn.chatgpt.com/docs/build-skills), read 2026-09-30; the old `developers.openai.com/codex/skills` URL redirects there). Plugin installation through a local marketplace is covered in [Codex](/docs/11-cross-platform/codex).

The old draft diagnosis quoted in Issue #17 (a missing `skills:` field) was wrong: the docs need no such field, and the real defect was `author`.

### What the hosts did

[`discover.py`](https://github.com/toolboxmd/building-agentskills/blob/main/case-studies/evidence/2026-09-30-loader-trigger-benchmark/discover.py) installs the repository from a git ref into a throwaway HOME on each host and prints the host's own listing, with no model call. Full output: [`discovery.txt`](https://github.com/toolboxmd/building-agentskills/blob/main/case-studies/evidence/2026-09-30-loader-trigger-benchmark/discovery.txt).

| Host, version | Install | `main` at `53f1864` | With the fix (`f8db18e`) |
| --- | --- | --- | --- |
| Claude Code 2.1.284 | `--plugin-dir` | `claude plugin validate`: `author: Invalid input`; `plugin list`: `Failed to load plugin` | validation passed; `building-agentskills@inline`, loaded |
| Codex 0.159.0 | local marketplace, `codex plugin add` | listed | listed |
| Grok Build 1.0.44 | `grok plugin install <copy> --trust` | `expected struct Author`; installed under a hashed name with `Skills (0)` | `Skills (1)`: `building-agentskills` |
| OpenCode 1.18.33 | `skills.paths` in `opencode.json` | listed | listed |

Codex reads the same `.claude-plugin/plugin.json` and accepted the string `author`. OpenCode never reads the manifest.

Two install details matter for the loader's relative paths (`../../docs/...` from the Skill's own directory):

- **OpenCode and Codex report a linked Skill at the link's path.** With the Skill directory linked into `OPENCODE_CONFIG_DIR/skills/` or `$HOME/.agents/skills/`, the listed location is the link, so `../../docs` points outside the repository and the loader falls back to GitHub. `skills.paths` pointing at the clone's `skills/` directory (OpenCode) and a plugin install (Codex, which copies the whole repository into its plugin cache) keep the pages local; the benchmark used those.
- **Claude Code's account sync adds competing Skills.** The throwaway HOME logged in with the user's account loaded claude.ai-synced Skills, including `anthropic-skills:skill-creator`. That is the real environment for this account, so it was kept.

The fix is one change to [`.claude-plugin/plugin.json`](https://github.com/toolboxmd/building-agentskills/blob/main/.claude-plugin/plugin.json): `"author": { "name": "lukaszmaj" }`. [Packaging as plugin](/docs/08-packaging-as-plugin) already showed the object form; this repository's own manifest did not follow it.

## Benchmark setup

### Harness and fixture

[`trigger_test.py`](https://github.com/toolboxmd/building-agentskills/blob/main/case-studies/evidence/2026-09-30-loader-trigger-benchmark/trigger_test.py) is a trimmed adaptation of the [AgentsMD harness](/case-studies/2026-09-29-agentsmd-routing-benchmarks) with the same scoring rules. Each run gets a fresh throwaway git repository: a small greeter app, a `greet` Skill whose description is `Greeting stuff.`, and an MCP server whose `search_orders` tool is described as `Search.`. No global instruction file is installed, so the loader's description is the only guidance.

### Prompts

No prompt names the loader, this repository or a page.

| Case | Kind | Prompt (paths shortened) |
| --- | --- | --- |
| author | naive | Create a new skill in skills/ that helps agents write release notes from the git log. It should get used whenever someone asks for release notes. |
| audit | naive | Agents never pick the greet skill at skills/greet/SKILL.md, even when a user asks for a greeting. Audit the skill and fix what is wrong. |
| tool | naive | Agents skip the search_orders tool in mcp/server.py when they should use it, and call it for questions it cannot answer. Its description is too vague. Rewrite the tool description so agents call it at the right time. |
| negative | negative | greet() in src/app.py returns 'Helo' instead of 'Hello'. Fix the typo. |

The tool case was added at the planner's request: [#4](https://github.com/toolboxmd/building-agentskills/issues/4) adds a tool-description row to the loader, and the description did not mention tool descriptions.

### Arms, hosts and runs

| Arm | Ref | What it is |
| --- | --- | --- |
| loader | `f8db18e` | the loader as on `main`, plus the manifest fix, installed |
| control | `f8db18e` | the same copy present in the throwaway HOME and readable, not installed |
| desc | `eec057d` | `loader` plus one before-clause in the description: "before writing or changing an MCP or agent tool description" |

The arm refs predate this branch's rebase; they stay reachable on the [`evidence/17-loader-benchmark-arms`](https://github.com/toolboxmd/building-agentskills/tree/evidence/17-loader-benchmark-arms) branch. `main` at `53f1864` is the ref before #17.

| Host | Version | Model | Runs |
| --- | --- | --- | --- |
| Claude Code | 2.1.284 | Opus 5.5 (`claude-opus-5-5`), effort medium | loader 5 per naive case and 3 negatives; control 5; desc 5 tool and 3 negatives |
| Codex | 0.159.0 | `gpt-6-astra`, effort low | same as Claude Code |
| Grok Build | 1.0.44 | `grok-4.7`, effort medium | loader 3 per naive case and 2 negatives |
| OpenCode | 1.18.33 | Muse 1.3 (`opencode-go/muse-spark-1.3-contributor`) | same as Grok Build |

Issue #17 names Claude Code and Codex; the planner added Grok Build and OpenCode with a budget of about 60 runs. Those two hosts got 3 runs per cell, the size the AgentsMD sweep used to find misses. The control arm rotates the three naive prompts (2, 2 and 1 runs). The benchmark batch was 68 runs, interleaved by arm and case; the `desc` re-measure added 16.

### Scoring

The moment is the first file edit. A run **fired** when the loader loaded (a Skill tool call for `building-agentskills` or a successful read of its `SKILL.md`) and any page the loader routes to was read successfully before that edit. A run with no edit gets `read-noedit` or `skip-noedit` and is reported beside the fired count. A negative run is **clean** when neither the loader nor any routed page was opened. Refused reads (Claude Code permission denials and error results for non-shell tools, OpenCode `error` parts) do not count. One record per run keeps the ordered tool calls up to the moment with paths replaced by placeholders, and no prompt text or file contents.

### Confinement

Each run had a temporary HOME holding the arm's copy and links to the host's existing login; nothing was installed into the live configuration. After every run, the three checkouts a run could reach (this worktree, the main building-agentskills checkout and the live AgentsMD install) and the live host configuration files had to match their pre-batch state, or the batch would abort; none did. Guard, cleanup and scorer self-checks passed on all four hosts before the batch.

Reads and writes were confined per host and proven with real denials against a probe file under the real home, before any benchmark run:

| Host | Confinement | Probe read / write | Loader copy read, repository write |
| --- | --- | --- | --- |
| Claude Code | Bash sandbox: `denyRead` of the real home and the keychain link, `allowRead` of the temporary HOME, no unsandboxed fallback | `Operation not permitted` / `Operation not permitted` | both succeeded |
| Codex | permission profile in `CODEX_HOME/config.toml`: `":root" = "read"`, `":project_roots"` and `":tmpdir"` write, the real home `"none"` (checked with `codex sandbox`) | `Operation not permitted` / `Operation not permitted` | both succeeded |
| Grok Build | custom sandbox profile extending `workspace` with a kernel `deny` of every entry in the real home except `~/.grok` | `Operation not permitted` / `Operation not permitted` | both succeeded |
| OpenCode | `external_directory` denied except the loader copy and the run's repository | refused by the permission rule, for the read tool and for `cat` in the shell / refused | both succeeded |

Four setup defects surfaced in the smoke runs, each fixed before the benchmark:

- **Codex's `workspace-write` and Grok's `workspace` read the whole disk.** Both read the probe file until the profiles above replaced them.
- **Denying the real home stopped Grok from starting.** Grok's own process obeys its sandbox profile and reads its login and binary from `~/.grok`; with the whole home denied it reported `Not signed in`. The profile denies every entry of the home except `~/.grok` instead.
- **OpenCode treated the run's repository as an external directory.** It saw the repository under `/var/folders/...` while running in `/private/var/folders/...`, and refused a write there. The rule now allows both spellings.
- **Models refuse commands their policy forbids, which hides whether the OS would.** Codex declined to run the probe commands at all, so `codex sandbox` with the same configuration supplied the OS-level proof; OpenCode's model declined shell reads until the smoke prompt asked for its read and write tools.

## Results

Every number below comes from [`summary.md`](https://github.com/toolboxmd/building-agentskills/blob/main/case-studies/evidence/2026-09-30-loader-trigger-benchmark/summary.md), which `trigger_test.py --summary records.jsonl` regenerates. All 84 runs made at least one tool call, so none were excluded.

### Loader arm: fired, naive prompts

| Host, model | author | audit | tool | Negative clean |
| --- | --- | --- | --- | --- |
| Claude Code, Opus 5.5, medium | 5/5 | 5/5 | 0/5 | 3/3 |
| Codex, `gpt-6-astra`, low | 5/5 | 5/5 | 0/5 | 3/3 |
| Grok Build, `grok-4.7`, medium | 3/3 | 3/3 | 3/3 | 2/2 |
| OpenCode, Muse 1.3 | 3/3 | 3/3 | 2/3 | 2/2 |

All 47 fired runs, across every arm, also read [Triggers](/docs/05-authoring/triggers) before the first edit. On the audit prompt every run on every host read [Anti-patterns](/docs/10-anti-patterns), the page the row "Before auditing a Skill that does not trigger or fails" names; no author run did. On the author prompt, every Claude Code run invoked the Skill first and then read Quickstart (four of five in one shell call with Frontmatter, Triggers and Prose discipline). In all 10 Codex author and audit runs Codex read its bundled `skill-creator` beside the loader, then the pages.

### Tool prompt: before and after the description change

| Host, model | Loader loaded before the first edit: loader / desc | Fired: loader / desc | Negative clean: loader / desc |
| --- | --- | --- | --- |
| Claude Code, Opus 5.5, medium | 0/5 / 5/5 | 0/5 / 4/5 | 3/3 / 3/3 |
| Codex, `gpt-6-astra`, low | 0/5 / 5/5 | 0/5 / 5/5 | 3/3 / 3/3 |

The one `desc` run on Claude Code that did not fire loaded the loader and read Triggers, then ended without an edit (`read-noedit`). On the `loader` arm, two Claude Code tool runs invoked the built-in `claude-api` Skill instead (the call failed), and one ended without an edit. Grok Build and OpenCode loaded the loader on the tool prompt without the change (3/3, 2/3), so they were not re-measured.

### Control arm

With the copy present but not installed, Codex never opened the loader (0/5). Claude Code opened it in 1 of 5 runs, the second author run of the rotation: it listed the directory it had been given with `--add-dir`, read the copy's `AGENTS.md`, then the loader and its pages. That is discovery by browsing a directory the harness handed it, not by description. The other control author run invoked `anthropic-skills:skill-creator`.

### Cost

Mean tokens per run (input including cache, plus output) on the author prompt: Claude Code 296,566 with the loader against 282,069 in the control; Codex 183,984 against 93,026; Grok Build 533,649; OpenCode 384,948. The negative prompt cost 32,730 to 79,782. The loader's routes make the model read several pages before writing, so a loaded run costs more; these cells do not say whether the resulting Skill is better.

## Caveats

- **Small samples, one fixture, one model per host.** 3 to 5 runs per cell. The results show the loader loads on these prompts; they are not rates.
- **Grok Build and OpenCode ran 3 runs per cell and no control or re-measure.** Issue #17 scoped the hosts to Claude Code and Codex.
- **The control arm is not a pure baseline on Claude Code.** The harness passes the copy as an `--add-dir` directory in every arm, which invites browsing.
- **Fired needs any routed page, not a specific one.** The author prompt matches several rows (Quickstart, Three questions, Frontmatter, Triggers); the table reports Triggers and Anti-patterns separately.
- **The `desc` arm does not include [#4](https://github.com/toolboxmd/building-agentskills/issues/4)'s tool-description row**, which merged after the runs. It measures only whether the description loads the loader; which page the loader then routes to on `main` now also depends on that row, which was not measured.
- **OpenCode's confinement is a permission rule, not an OS sandbox.** A shell command that reaches a path indirectly (for example through an interpreter) is not stopped by `external_directory`; the guard would still see a change to a guarded checkout.
- **Records were scrubbed once after the batch.** Two anonymization rules were added after the runs (Claude Code session directory names, and a macOS user-home path from another machine that a Grok run typed); `trigger_test.py`'s `scrub` applies them, and the summary is identical before and after.
- **Evidence, not a release gate.** Behavioral verification in real projects stays with the user.

## Lessons

- **Validate the manifest on every host you ship to.** A string `author` passed Codex, which also reads `.claude-plugin/plugin.json`, and silently removed the Skill from Claude Code and Grok Build. `claude plugin validate` and `grok plugin validate` both reported it.
- **A description loads a Skill only for the artifacts it names.** The loader loaded on every Skill authoring and audit prompt, and never on a tool description until the description named tool descriptions (0/10 to 10/10 on two hosts).
- **Check how a host reports a linked Skill's location before relying on relative paths.** OpenCode and Codex report the link's path, not the target.
- **Prove confinement against the model's reluctance.** A model that refuses a forbidden command shows its policy, not the OS; prove the denial with the host's own sandbox command or a tool the model will use.

## Reproduce

```sh
cd case-studies/evidence/2026-09-30-loader-trigger-benchmark
python3 trigger_test.py --summary records.jsonl   # regenerates summary.md
python3 trigger_test.py --scorer-test
python3 discover.py 53f1864 f8db18e               # needs the four CLIs and their logins
```

`tests/check-loader-benchmark-records.test.sh` runs the first two in `npm test`. A new batch: `python3 trigger_test.py --host <host> --model <model> --effort <effort> --arms loader=<ref>,control=<ref> --plan full --record <file outside the checkout>`.

## Sources

- Issue [#17](https://github.com/toolboxmd/building-agentskills/issues/17); the tool case from [#4](https://github.com/toolboxmd/building-agentskills/issues/4).
- [Claude Code plugin manifest reference](https://code.claude.com/docs/en/plugins-reference) and [Codex Build skills](https://learn.chatgpt.com/docs/build-skills), read 2026-09-30.
- [Grok Build sandbox profiles](https://github.com/xai-org/grok-build/blob/97f190f644ae1ba07fd6ee185ef54c650e142666/crates/codegen/xai-grok-pager/docs/user-guide/18-sandbox.md) and Codex permission profiles in [`permissions_tests.rs` at `rust-v0.159.0`](https://github.com/openai/codex/blob/rust-v0.159.0/codex-rs/core/src/config/permissions_tests.rs).
- Records, discovery output, harness and summary, listed with SHA-256 in the [evidence manifest](/case-studies/evidence/2026-09-30-loader-trigger-benchmark.json).

Cross-links: [Trigger benchmarks](/docs/06-testing/trigger-benchmarks), [Triggers](/docs/05-authoring/triggers), [Packaging as plugin](/docs/08-packaging-as-plugin), [AgentsMD routing benchmarks](/case-studies/2026-09-29-agentsmd-routing-benchmarks).
