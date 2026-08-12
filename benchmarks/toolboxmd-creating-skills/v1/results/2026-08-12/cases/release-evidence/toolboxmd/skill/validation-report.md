# Validation report

## Package and design

Created `SKILL.md`, `evals/evals.json`, and this report. The skill is the right primitive for reusable semantic judgment over mixed release evidence; it does not claim to enforce publication. It is intended for agent discovery or explicit user invocation. Semantic rules remain advisory; hooks, protected CI, approval gates, or publishing permissions are identified for enforcement.

The entry point is budgeted well below 500 lines, its portable description is below 1,024 characters, and there are no conditional references or always-on integrations. No helper script was added: exact citation and identifier checks can be deterministic, but semantic support cannot be.

## Checks performed

- Inspected portable frontmatter, directory/name agreement, package paths, citation examples, output headings, and line budget.
- Parsed the eval JSON and checked that its `skill_name` agrees with the package name.
- Prepared three cases covering a normal draft, benefit-broadening pressure, and an out-of-scope/stop-condition request.
- Ran the offline package validator against the complete package after this report was written.
- Inspected the final tree after validation and made no subsequent package changes.

## Evidence-boundary scenarios

- Shipped implementation supports a change only in the local archive importer.
- One passed synthetic Linux fixture supports only its recorded no-duplicate observation and conditions.
- An unshipped plan cannot support remote-import or rollback release claims.
- A rejected universal zero-loss proposal cannot support a guarantee.
- An unverified speed impression cannot support a performance claim.
- A missing stable identifier or conflicting status stops the affected required claim; an optional unsupported claim is withheld while independent supported drafting continues.

## Limitations and delivery state

The package provides advisory semantic review and cannot itself block publication. Mechanical validation establishes package structure, not the truth of release prose. Evaluation cases were prepared and boundary behavior was manually reviewed, but no fresh-agent smoke run was performed because the permitted offline context excludes another model or agent.

- Validated: yes — offline package validation passed.
- Tested: partial — three eval cases prepared and manually reviewed; no fresh-agent execution.
- Committed: no — not requested.
- Pushed: no — not requested, and nothing was published.
