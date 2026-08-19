# Post-review active Grok validation

Exact-HEAD review of the four-arm diagnostic found that the active Grok adapter
could accept direct or enveloped output without a runtime init event and without
the complete inspect allowlist. The active adapter now applies the strict
inspect fallback whenever init is absent.

A subsequent exact-HEAD review found that retained evidence could still contain
a JSON-escaped copy of a protected multiline or quote-containing prompt. The
active adapter now redacts literal, UTF-8 JSON-escaped, and ASCII JSON-escaped
variants, with a focused fake-runtime regression test covering all three.

The next exact-HEAD review found that the pre-call input filter recognized only
a short vendor list. The active adapter now rejects generic credential
assignments such as API keys, secret keys, tokens, credentials, and database
connection values before invoking Grok, while a non-secret `MONKEY` assignment
remains accepted in the regression fixture.

The following exact-HEAD review found that applying the same assignment pattern
to serialized review JSON could corrupt otherwise valid output. Structured
review strings are now redacted recursively before serialization, with a
credential-shaped review fixture proving that the consultation remains `ok`
and the retained `review.json` remains valid.

The 36,206-byte two-file active package passes the final exact-reviewed Creator
vNext validator from commit `20fc268615079ade496e31cc5e55f51bcc5ad3b0` under
the same 45,000-byte downstream package profile. The exact validator, adapter,
arguments, and result are recorded in `validator-diagnostic.json`.

These corrections occurred after the four-arm authoring run. They do not replace
the historical acceptance-refined reference, repair the token-cap abort, enable
automatic Grok review, or provide evidence from a new real Grok call.
