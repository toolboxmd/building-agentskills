# Existing architecture consultation evidence

This directory retains a pre-existing explicit `toolboxmd-use-grok`
consultation about one creator-validator architecture decision. It was found in
local temporary evidence and copied into the repository on 2026-08-14 without
calling Grok or any other model again.

The exact source was
`/private/tmp/toolboxmd-grok-architecture.tvu9yv`, adapter run
`1c59b683-8daa-4525-bec1-ebc0c8fd58bd`. Grok CLI 1.0.3 reported runtime model
`grok-4.6` and the result usage key `grok-4.6-build`. The result was
`subtype=success`, `is_error=false`, `num_turns=1`, and `end_turn`. Runtime init
advertised `todo_write`, `search_tool`, and `use_tool`, but the retained stream
showed zero tool calls and zero web requests.

The consultation returned `REPLAN`. Its strongest recommendation was to shrink
the validator contract to a closed set of fenced shell examples and declared
executable files instead of extending an open-ended shell lexical scanner with
another wrapper-specific state. The advice also identified migration choices
that remain repository decisions, not facts established by the model.

This is product-use evidence, not a creator benchmark, a superiority result, or
an automatic-mode acceptance. The designated synthetic explicit adapter
acceptance remains the separate call under `../../2026-08-13/real-explicit/`.
Automatic review remains disabled.

Retained here:

- `prompt.md`: the exact standalone architecture prompt;
- `review.json`: the exact closed-schema structured review;
- `manifest.json`: source hashes, bounded runtime facts, retention choices, and
  the claim boundary.

The 43,453-byte raw stream is not duplicated here. Its SHA-256 and byte count
are recorded in the manifest; the exact structured result is retained in
`review.json`. This keeps the architecture record inspectable without treating
model thinking or a provider signature as additional doctrine evidence.

The source metadata did not record the adapter digest used for this run. The
manifest therefore leaves that value null instead of claiming that the current
adapter bytes produced the older consultation. A bounded credential and local
path scan of the copied prompt and review found zero matches; the exact pattern
classes and the limits of that claim are recorded in the manifest.
