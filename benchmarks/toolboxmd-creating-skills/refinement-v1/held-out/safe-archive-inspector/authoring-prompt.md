Use the loaded `creator-under-test` skill to create the new skill described in
`input/base-brief.md` and `input/contract.json`.

First run `python3 harness/isolation_preflight.py model`. Stop if it fails.

Write the final distributed package only to
`output/skills/safe-archive-inspector/`. Temporary acceptance fixtures and
working notes may live elsewhere under `output/`, but they are not package
files. Do not read repository history, user configuration, credentials,
unrelated skills, or any path outside the visible sandbox. Do not use network,
package installation, Git, another agent, or another agentic CLI.

The helper must be executable, Python-standard-library-only, cwd-independent,
and compatible with both system Python 3.9 and the current Python runtime. Test
representative safe and unsafe TAR and ZIP cases without extracting or reading
member payloads. Run the Creator's validator with explicit package budgets.

Do not read or infer an external grader. Use only the supplied brief, contract,
primary documentation already quoted in the brief, and tests you derive from
that evidence.

Return the required final JSON message only after the package and its checks
are complete.
