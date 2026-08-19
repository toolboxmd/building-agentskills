# `toolboxmd-use-grok` acceptance evidence

## Result

The fake contract suite passed. One bounded real explicit consultation also
completed, but automatic review remains disabled and fails closed.

The real acceptance supports only these claims:

- the process exited zero after one model turn with `end_turn`;
- the closed schema produced a valid `structured_output` object;
- `--json-schema` and explicit `streaming-messages-json` produced both an init
  frame and a result frame in local Grok 1.0.3;
- runtime init exposed `skills=[]` and `mcp_servers=[]`;
- runtime advertised `todo_write`, `search_tool`, and `use_tool`;
- no tool call or server-tool call was observed in the three retained frames;
- web search requests were zero;
- retained artifacts contain no detected credential, private-key marker, user
  home path, or prompt text.

It does not support these claims:

- automatic review is accepted;
- a dedicated authenticated `GROK_HOME` passed real acceptance;
- permission deny behavior was exercised by a model tool call;
- empty `GROK_HOME` alone provides isolation;
- the result generalizes beyond Grok 1.0.3.

## Historical invocation and refinement

The designated acceptance call used `--deny '*'` and `--deny 'MCPTool(*)'`. Source review
after that call found that the bare star is an `Any` pattern, not a tool-wide
global deny. The active adapter therefore uses bare `Read` and bare `MCPTool`,
which current source parses as tool-wide deny classes. No second call was made
to behaviorally re-test those rules. They are source-backed and fake-tested,
but not behaviorally accepted against a real tool attempt.

Three targeted, non-model tests from the pinned upstream source also pass:
bare `MCPTool` parsing, `UseTool` to MCP access mapping, and MCP deny-policy
evaluation. `source-behavior/summary.json` records that bounded evidence. It
still does not replace a real CLI tool-attempt acceptance.

The active adapter keeps `--tools todo_write`. Current source treats a
recognized non-empty allowlist as restrictive but always retains the MCP
meta-tools. An empty allowlist does not apply that clamp, and an unknown entry
can fall back to the full toolset. The active adapter checks the exact observed
runtime surface and rejects any emitted tool call.

## Authentication boundary

The real explicit call used existing default-profile OAuth in place. No auth
file was copied or read, and no API key was present. Automatic mode requires a
stable dedicated non-default profile plus detected auth presence, a frozen
version, clean inspect output, clean runtime init, and zero observed tool calls.
No dedicated authenticated profile was accepted, so the marketplace skill does
not enable automatic review and no personal policy was changed.

## Evidence retention

`real-explicit/stdout.raw.jsonl`, `stderr.raw.txt`, `metadata.json`, and
`review.json` retain the sanitized adapter output from the only real call. The
prompt is represented only by byte count and SHA-256. Full inspect output was
not retained because it included unrelated bundled skill descriptions. Its
digest and minimized contract fields are in `real-explicit/inspect-summary.json`.

The non-model isolation recheck likewise retains raw digests plus bounded
counts and names in `isolation-inspect-summary.json`. `sources.json` pins the
official source commits, URLs, and licenses used to interpret the behavior.

## Later architecture consultation

A separate, pre-existing explicit product-use call reviewed one creator
validator architecture decision on 2026-08-14. Its prompt, structured `REPLAN`
result, source-artifact hashes, and claim boundary are retained under
[`../2026-08-14/architecture-consultation/`](../2026-08-14/architecture-consultation/).
It is not counted as a repeat of the designated adapter acceptance, a creator
benchmark, or automatic-mode evidence. No model call was made while retaining
that existing evidence in the repository.

## Parent-validator diagnostic

The active two-file package also passes the exact committed validator blob at
parent commit `23b9c693bbd1edabf229ec3a56e9dd4b260f96eb` from an external working
directory with `--creation-mode` and `--warnings-as-errors`. Because
`scripts/consult-grok` is an extensionless Python executable, the invocation
must bind its current bytes through the validator's exact-digest interface:

```sh
script_sha="$(shasum -a 256 "<target-skill-dir>/scripts/consult-grok" | awk '{print $1}')"
(
  cd "<external-cwd>"
  PYTHONDONTWRITEBYTECODE=1 python3 -B \
    "<creator-skill-dir>/scripts/validate_skill.py" \
    --json \
    --creation-mode \
    --warnings-as-errors \
    --script-syntax-checked "scripts/consult-grok=$script_sha" \
    --max-description-chars 400 \
    --max-skill-lines 150 \
    --max-skill-bytes 10500 \
    --max-files 2 \
    --max-package-bytes 45000 \
    --max-reference-files 0 \
    --max-eval-files 0 \
    --max-script-files 1 \
    "<target-skill-dir>"
)
```

The recorded run passed with zero warnings and zero errors for adapter SHA-256
`80171856e3040fc6c67ccfff55f97f8ff56920ff62d5bb97188046b5341f0210`.
[`../2026-08-14/validator-diagnostic.json`](../2026-08-14/validator-diagnostic.json)
records the exact committed-validator hash, argv, package aggregate, and claim
boundary. This is a child-package diagnostic only. The parent creator review is
still unresolved, so `validatorLineagePendingParentReview` remains true.
