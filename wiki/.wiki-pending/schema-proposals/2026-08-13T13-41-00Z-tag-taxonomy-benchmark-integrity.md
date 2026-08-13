---
title: "Schema proposal: bound tag taxonomy (lint flagged existing tags as new)"
captured_at: "2026-08-13T13:41:00Z"
trigger: "wiki-lint-tags.py on concepts/benchmark-integrity-for-agent-skills.md flagged benchmarks, blind-review, retrieval as new tags"
---

`schema.md`'s Tag Taxonomy section is unbound (no explicit tag list), so `wiki-lint-tags.py` flags every tag on every page as "new," including tags already in use on `concepts/benchmark-integrity-for-agent-skills.md` (agent-skills, benchmarks, blind-review, retrieval) and `concepts/provider-neutral-skill-runtime.md` (agent-skills, provider-adapters, orchestration, configuration). Recommend populating `schema.md`'s Tag Taxonomy with the tags already observed in use across the wiki, so future lint runs distinguish genuinely new tags from established ones.
