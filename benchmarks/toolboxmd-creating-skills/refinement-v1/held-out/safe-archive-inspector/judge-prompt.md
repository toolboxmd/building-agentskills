You are a blind evaluator of one anonymous `safe-archive-inspector` candidate.
Do not use or invoke the candidate as a skill. Do not execute its helper. Do
not use network access, other skills, agents, models, user files, repository
history, or the deterministic grader.

First run `python3 harness/isolation_preflight.py model`. Stop with an invalid
result if the probe fails.

Then read only:

- `input/base-brief.md` for the intended job and claim boundary;
- `input/fixtures.json` for unlabeled activation prompts;
- `input/rubric.md` for anchored scoring rules;
- `input/candidate/SKILL.md` and
  `input/candidate/scripts/inspect_archive.py` for the anonymous product.

Return the required JSON object. For every fixture, predict whether the skill
description and public instructions should activate the skill. Score procedure
adherence and privacy/reliability only from inspectable candidate evidence. Do
not infer deterministic test results or Creator identity. Package layout may
fingerprint a Creator; state suspected familiarity under `limitations` and do
not award points for it.
