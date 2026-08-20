---
name: "safe-archive-inspector"
description: "Inspect an untrusted TAR or ZIP archive without extraction when a user asks to screen, audit, or list it. Do not use for creating archives, general compression questions, or extracting trusted files."
---

# Safe Archive Inspector

Use the helper to screen archive metadata before a human extraction decision.
The result proves only that no frozen-policy violation was found; it does not
prove authenticity, malware safety, payload safety, or permission to extract.

```bash
"<skill-dir>/scripts/inspect_archive.py" \
  --archive "<archive>" \
  --max-entries 1000 \
  --max-total-bytes 100000000
```

Treat `unsafe` and `error` as fail-closed outcomes. Never extract automatically.
