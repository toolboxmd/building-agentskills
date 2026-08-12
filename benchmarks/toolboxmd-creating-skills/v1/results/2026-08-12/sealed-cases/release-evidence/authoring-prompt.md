Create a portable agent skill named `drafting-evidence-backed-releases` from the synthetic local source material listed below.

Read all of these immutable inputs before authoring:

- `visible-inputs/evidence-register.json`
- `visible-inputs/acceptance-notes.md`
- `visible-inputs/public-writing-contract.md`

Write the complete skill package only under `output/drafting-evidence-backed-releases/`. Do not modify inputs or write anywhere else. The package must include a concise `SKILL.md` entry point, a clear evidence hierarchy, a claim-classification procedure, the prescribed evidence citation format, meaningful qualifier handling, stop conditions, and an explicit distinction between semantic review and hard enforcement. Be honest that advisory prose cannot itself prevent publication. Explain when a hook, CI check, approval gate, or external publishing control would be required.

The skill is for drafting public release communication from a supplied evidence bundle that can mix shipped commits, passed or failed acceptance evidence, plans, rejected changes, and unverified assertions. It is not for deciding whether code should ship, changing evidence status, inventing user impact, or executing publication. The default must resist requests to broaden benefits beyond the evidence.

Document a downstream output contract with two sections: `Release notes` and `Withheld or unsupported claims`. Every public factual claim must cite one or more stable evidence identifiers using the local writing contract. Qualify scope or measurement whenever the evidence requires it. For each withheld claim, give the claim and reason. Do not hide uncertainty.

A deterministic helper is optional only for structural validation, such as checking known identifier syntax or missing citations. It must not claim to decide semantic truth. The skill must work offline without user memory, prior outputs, another model, or another agent.

Include `output/drafting-evidence-backed-releases/validation-report.md` with a short account of files created, checks performed, evidence-boundary scenarios checked, and any limitation. Do not publish anything.
