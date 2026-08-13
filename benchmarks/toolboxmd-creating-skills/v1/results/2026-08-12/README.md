# ToolboxMD creating-skills benchmark result

## Decision

The v1 benchmark has no eligible creator comparison after a post-result isolation-evidence correction. The frozen `toolboxmd-creating-skills` candidate remains unpromoted because it did not clear its promotion gate. This result does not establish that the built-in creator is better.

The retained compact event audits cover 15 model streams: one candidate-authoring stream, six case-authoring streams, six downstream streams, and two blind-review streams. Every audit records `commandCount > 0`; none records independently verifiable evidence for a sanitized environment, filesystem read and write confinement, and syscall-level network enforcement. All 15 streams are therefore ineligible under the repository-wide isolation rule.

The corresponding raw model-event JSONL files were not committed and are no longer present in this checkout. Exact commands cannot be re-audited. The correction preserves the original compact diagnostic reasons and usage, and relies only on their retained command counts plus the absence of trust-bearing isolation evidence. It added zero model sessions.

## Retained diagnostic observations

| Case | Deterministic observation | Frozen semantic observation | Eligible outcome |
|---|---|---|---|
| `webhook-triage` | Both downstream outputs recorded 21/21 checks. The baseline authoring boundary audit also recorded bytecode outside its allowed output. | The frozen initial judge recorded a 20 to 20 tie. The replay remained invalid under the frozen verdict rule. | None; authoring, downstream, and judging evidence is ineligible. |
| `csv-sanitizer` | Both downstream outputs recorded 20/20 checks. | The pair was already excluded because baseline bytecode embedded an absolute path containing treatment identity. | None; authoring and downstream evidence is ineligible, and the pair also retained its identity-leak failure. |
| `release-evidence` | Both downstream outputs recorded 26/26 checks. | The frozen judge recorded a 20 to 17 preference for the built-in package. | None; authoring, downstream, and judging evidence is ineligible. |

These scores and judgments remain inspectable historical observations. They cannot support a quality, cost, trigger, tie, case-winner, or general creator claim. The existing loader and public recommendation remain unchanged.

## Evidence

- `manifest.json` records the corrected decision, frozen hashes, run settings, diagnostic usage, amendments, and claim boundary.
- `sealed-cases/` contains the exact post-freeze cases used by both treatments.
- `candidate/` contains the byte-identical frozen candidate, retained as a benchmark artifact rather than a distributed skill.
- `cases/` contains both generated packages, downstream outputs, deterministic grades, boundary audits, and corrected compact event audits.
- `blind/` contains the original review, invalid replay, validation reports, revealed identity map, and corrected compact event audits.
- `preflight/` records that no implicit skills were visible and the outbound DNS probe failed. This behavioral observation is not independent proof of strict isolation.

Full model-event JSONL streams were left in an ignored local benchmark workspace and are not retained in this checkout. The tracked result keeps compact audits and exact output artifacts, but it cannot reconstruct the commands or prove the execution boundary retrospectively.

## Interpretation limit

This was one run on Codex CLI 0.147.0 with `gpt-5.6-sol` at medium reasoning effort. No creator comparison remains eligible. The retained evidence supports only the conservative release action not to promote this candidate; it does not rank either creator, estimate variance, or establish cross-model or cross-provider behavior.
