
### claude-code, `claude-opus-5-5`, effort medium

31 of 31 runs valid (a run with no tool call is excluded).

| Measure | loader: author | loader: audit | loader: tool | loader: negative | control: author | control: audit | control: tool | desc: tool | desc: negative |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Loader loaded before the first edit | 5/5 | 5/5 | 0/5 |  | 1/2 | 0/2 | 0/1 | 5/5 |  |
| Loader loaded and a routed page read before the first edit (fired) | 5/5 | 5/5 | 0/5 |  | 1/2 | 0/2 | 0/1 | 4/5 |  |
| Triggers page read before the first edit | 5/5 | 5/5 | 0/5 |  | 1/2 | 0/2 | 0/1 | 5/5 |  |
| Anti-patterns page read before the first edit | 0/5 | 5/5 | 0/5 |  | 0/2 | 0/2 | 0/1 | 0/5 |  |
| No edit (read-noedit or skip-noedit) | 0/5 | 0/5 | 1/5 |  | 0/2 | 0/2 | 0/1 | 1/5 |  |
| Negative clean (loader and pages never opened) |  |  |  | 3/3 |  |  |  |  | 3/3 |
| Mean tokens per run (input incl. cache, plus output) | 296,566 | 310,854 | 127,145 | 79,782 | 282,069 | 221,641 | 136,611 | 220,400 | 80,107 |

Other Skills invoked: `anthropic-skills:skill-creator` 1, `claude-api` 2

### codex, `gpt-6-astra`, effort low

31 of 31 runs valid (a run with no tool call is excluded).

| Measure | loader: author | loader: audit | loader: tool | loader: negative | control: author | control: audit | control: tool | desc: tool | desc: negative |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Loader loaded before the first edit | 5/5 | 5/5 | 0/5 |  | 0/2 | 0/2 | 0/1 | 5/5 |  |
| Loader loaded and a routed page read before the first edit (fired) | 5/5 | 5/5 | 0/5 |  | 0/2 | 0/2 | 0/1 | 5/5 |  |
| Triggers page read before the first edit | 5/5 | 5/5 | 0/5 |  | 0/2 | 0/2 | 0/1 | 5/5 |  |
| Anti-patterns page read before the first edit | 0/5 | 5/5 | 0/5 |  | 0/2 | 0/2 | 0/1 | 0/5 |  |
| No edit (read-noedit or skip-noedit) | 0/5 | 0/5 | 0/5 |  | 0/2 | 0/2 | 0/1 | 0/5 |  |
| Negative clean (loader and pages never opened) |  |  |  | 3/3 |  |  |  |  | 3/3 |
| Mean tokens per run (input incl. cache, plus output) | 183,984 | 181,609 | 87,513 | 55,385 | 93,026 | 92,820 | 93,067 | 99,260 | 55,368 |

### grok, `grok-4.7`, effort medium

11 of 11 runs valid (a run with no tool call is excluded).

| Measure | loader: author | loader: audit | loader: tool | loader: negative |
| --- | --- | --- | --- | --- |
| Loader loaded before the first edit | 3/3 | 3/3 | 3/3 |  |
| Loader loaded and a routed page read before the first edit (fired) | 3/3 | 3/3 | 3/3 |  |
| Triggers page read before the first edit | 3/3 | 3/3 | 3/3 |  |
| Anti-patterns page read before the first edit | 0/3 | 3/3 | 2/3 |  |
| No edit (read-noedit or skip-noedit) | 0/3 | 0/3 | 0/3 |  |
| Negative clean (loader and pages never opened) |  |  |  | 2/2 |
| Mean tokens per run (input incl. cache, plus output) | 533,649 | 562,440 | 363,734 | 62,986 |

### opencode, `opencode-go/muse-spark-1.3-contributor`

11 of 11 runs valid (a run with no tool call is excluded).

| Measure | loader: author | loader: audit | loader: tool | loader: negative |
| --- | --- | --- | --- | --- |
| Loader loaded before the first edit | 3/3 | 3/3 | 2/3 |  |
| Loader loaded and a routed page read before the first edit (fired) | 3/3 | 3/3 | 2/3 |  |
| Triggers page read before the first edit | 3/3 | 3/3 | 2/3 |  |
| Anti-patterns page read before the first edit | 0/3 | 3/3 | 1/3 |  |
| No edit (read-noedit or skip-noedit) | 0/3 | 0/3 | 0/3 |  |
| Negative clean (loader and pages never opened) |  |  |  | 2/2 |
| Mean tokens per run (input incl. cache, plus output) | 384,948 | 363,937 | 193,743 | 32,730 |
