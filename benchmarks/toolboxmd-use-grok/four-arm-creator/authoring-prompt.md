Use the sole available skill for creating or updating agent skills. Create a
production-ready `toolboxmd-use-grok` package from the frozen inputs in
`input/base-brief.md` and `input/contract.json`.

Mandatory sequence:

1. First run `python3 harness/isolation_preflight.py model`. Stop and report
   `blocked` if it does not pass.
2. Read only the frozen input, harness, and sole Creator skill made available
   in this run. Do not inspect parent directories, user files, credentials,
   repository history, other skills, or any network resource.
3. Write the product only to `output/skills/toolboxmd-use-grok/`.
4. Do not call the real Grok CLI, any model, any agent, or any network service.
   You may use `harness/fake_grok.py` for local deterministic rehearsal.
5. Validate and rehearse the package locally before finishing.

The product must contain exactly these two regular files and no symlinks:

```text
output/skills/toolboxmd-use-grok/
├── SKILL.md
└── scripts/
    └── consult-grok
```

The adapter must be an executable Python 3 stdlib program with this stable
operator interface:

```text
consult-grok --mode explicit|automatic --prompt-file FILE --output-dir DIR
             --grok-home DIR --grok-bin FILE --timeout SECONDS
             --max-turns INTEGER
```

It must emit one JSON status object on stdout. Successful explicit review uses
`status: "ok"`; failures use the concrete categories from the frozen contract.
Keep automatic mode implemented but disabled and fail-closed because no stable
dedicated authenticated profile has passed real acceptance. Never interpolate
prompt content into a shell command.

Honor every budget in `input/contract.json`, including exactly two files,
`SKILL.md` at most 150 lines and 10,500 bytes, description at most 400
characters, and package at most 45,000 bytes. Do not add README, references,
evals, sidecars, manifests, or evidence inside the package.

Finish with a JSON object containing:

- `status`: `complete` or `blocked`;
- `package_path`: the relative package path;
- `tests`: commands run and their outcomes;
- `notes`: remaining limitations without superiority claims.
