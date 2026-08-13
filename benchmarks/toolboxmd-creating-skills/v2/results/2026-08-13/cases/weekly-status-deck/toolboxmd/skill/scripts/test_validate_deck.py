#!/usr/bin/env python3
"""Focused tests for validate_deck.py."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("validate_deck.py")
VALID_DECK = """---
marp: true
theme: default
paginate: true
footer: Aster Weekly | Internal
---
# Aster Weekly Status

2026-07-27 to 2026-07-31

---
# Outcomes

- **DONE** — Help center refresh shipped. [E1]
- **DONE** — Tagged contacts fell 8% week over week. [E2]

---
# Work in progress

- **ON TRACK** — Tutorial edit is 60% complete with no blocker. [E3]

---
# Risks

- **BLOCKED** — Legal review awaits the data-processing addendum. [E4]

---
# Decisions and asks

- Approve the addendum by 2026-07-31. [E5]
- **UNCONFIRMED** — Trial activation is 38%; no prior comparison exists. [E6]
"""


class ValidateDeckTests(unittest.TestCase):
    def run_validator(self, deck_text: str, *extra: str) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            deck = root / "status-deck.md"
            deck.write_text(deck_text, encoding="utf-8")
            expanded = [arg.replace("{tmp}", str(root)) for arg in extra]
            return subprocess.run(
                [sys.executable, str(SCRIPT), str(deck), *expanded],
                text=True,
                capture_output=True,
                check=False,
            )

    def test_valid_deck_passes_check_only(self) -> None:
        result = self.run_validator(VALID_DECK)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "valid\n")

    def test_uncited_bullet_fails(self) -> None:
        result = self.run_validator(VALID_DECK.replace(" [E4]", ""))
        self.assertEqual(result.returncode, 1)
        self.assertIn("factual bullet must end", result.stderr)

    def test_receipt_requires_semantic_review_flag(self) -> None:
        result = self.run_validator(
            VALID_DECK, "--receipt", "{tmp}/deck-check.json"
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("--claim-boundary-reviewed", result.stderr)

    def test_receipt_has_exact_ordered_shape(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            deck = root / "status-deck.md"
            receipt = root / "deck-check.json"
            deck.write_text(VALID_DECK, encoding="utf-8")
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    str(deck),
                    "--receipt",
                    str(receipt),
                    "--claim-boundary-reviewed",
                ],
                text=True,
                capture_output=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            payload = json.loads(receipt.read_text(encoding="utf-8"))
            self.assertEqual(
                list(payload),
                [
                    "schema_version",
                    "slide_count",
                    "required_sections",
                    "evidence_ids",
                    "unsupported_claims",
                    "checks",
                ],
            )
            self.assertEqual(payload["evidence_ids"], ["E1", "E2", "E3", "E4", "E5", "E6"])
            self.assertEqual(payload["unsupported_claims"], 0)


if __name__ == "__main__":
    unittest.main()
