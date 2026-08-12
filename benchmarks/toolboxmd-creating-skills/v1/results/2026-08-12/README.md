# ToolboxMD creating-skills benchmark result

## Decision

The frozen `toolboxmd-creating-skills` candidate did not pass the v1 directional benchmark and is not the preferred creator.

All three candidate-authored packages passed the mechanical and held-out deterministic checks. That was not enough to establish better downstream skill quality:

| Case | Deterministic result | Blind semantic result | Final treatment outcome |
|---|---|---|---|
| `webhook-triage` | Both downstream outputs passed 21/21 checks. The baseline authoring run also wrote bytecode outside its allowed output. | Valid initial review: tie, 20 to 20. A replay proposed A because of the baseline boundary failure, but failed the frozen clear-win rule and is retained as invalid. | Tie |
| `csv-sanitizer` | Both downstream outputs passed 20/20 checks. | Invalid before review because baseline bytecode embedded an absolute path containing treatment identity. | Invalid |
| `release-evidence` | Both downstream outputs passed 26/26 checks. | Baseline won 20 to 17 on package partitioning and completeness of the withheld-claims output. | Baseline win |

The candidate therefore recorded zero valid blind wins against the required minimum of two. The existing loader and public recommendation remain unchanged.

## Evidence

- `manifest.json` records the decision, frozen hashes, run settings, usage, amendments, and claim boundary.
- `sealed-cases/` contains the exact post-freeze cases used by both treatments.
- `candidate/` contains the byte-identical frozen candidate, retained as a benchmark artifact rather than a distributed skill.
- `cases/` contains both generated packages, downstream outputs, deterministic grades, and compact isolation evidence.
- `blind/` contains the initial review, invalid replay, validation reports, and revealed identity map.
- `preflight/` records the behavioral proof that no implicit skills were visible and outbound DNS failed.

Full JSONL event streams remain in the ignored local benchmark workspace. The tracked result keeps compact audits and the exact artifacts needed to inspect the decision without publishing machine-local run databases or full transcripts.

## Interpretation limit

This was one directional run on Codex CLI 0.147.0 with `gpt-5.6-sol` at medium reasoning effort. It does not estimate variance or establish cross-model or cross-provider rankings. It supports only the negative decision not to promote this candidate.
