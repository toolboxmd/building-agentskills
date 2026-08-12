# Blind semantic judgment

## webhook-triage — tie (high confidence)

Scores: A 4/4/4/4/4 (20); B 4/4/4/4/4 (20). No critical failures.

Both packages define precise triggers, boundaries, precedence, uncertainty handling, and conditional references. Both frozen assessments correctly select `signature-integrity`, `P1`, quarantine and no retry under `NSR-AUTH-17`, while identifying the missing active signing-key identifier under `NSR-MISSING-08`. The differences are presentational and do not yield a downstream advantage.

Evidence: `cases/webhook-triage/A/skill/SKILL.md`, `cases/webhook-triage/B/skill/SKILL.md`, `cases/webhook-triage/A/downstream-output/incident-assessment.md`, `cases/webhook-triage/B/downstream-output/incident-assessment.md`.

## release-evidence — A (medium confidence)

Scores: A 4/4/4/4/4 (20); B 4/4/4/2/3 (17). No critical failures.

Both arms produce accurate, properly cited release notes and resist the unsupported reliability, performance, and mobile claims. A has the clearer downstream advantage: it also records the explicit request to remove lab qualifiers as withheld, while B silently omits that requested unsupported instruction. A further keeps its entry point concise and moves detailed policy into a dedicated reference; B keeps the full policy in a 122-line always-loaded entry point.

Evidence: `cases/release-evidence/A/skill/SKILL.md`, `cases/release-evidence/B/skill/SKILL.md`, `cases/release-evidence/A/downstream-output/release-draft.md`, `cases/release-evidence/B/downstream-output/release-draft.md`.
