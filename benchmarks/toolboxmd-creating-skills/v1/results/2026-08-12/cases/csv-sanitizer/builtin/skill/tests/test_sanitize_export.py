#!/usr/bin/env python3
"""Offline integration tests for sanitize_export.py."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "sanitize_export.py"
HEADER = "customer_ref,email,region,display_name,note,status\n"


class SanitizerTests(unittest.TestCase):
    def invoke(self, source: Path, output: Path, audit: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(SCRIPT), "--input", str(source),
             "--output", str(output), "--audit", str(audit)],
            text=True, capture_output=True, check=False,
        )

    def test_success_normalizes_sorts_audits_and_is_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            source = base / "source.csv"
            output = base / "nested" / "clean.csv"
            audit = base / "other" / "audit.json"
            source_bytes = (
                HEADER
                + " cus-0002 ,TWO@EXAMPLE.TEST,sud,  Two\tName  ,\"has, comma\",hold\n"
                + "CUS-0001,one@example.test,N,One   Name,   ,enabled\n"
                + "CUS-0003,three@example.test,north,Three,ok,active\n"
                + "\n"
            ).encode("utf-8")
            source.write_bytes(source_bytes)

            first = self.invoke(source, output, audit)
            self.assertEqual(first.returncode, 0, first.stderr)
            expected = (
                HEADER
                + "CUS-0001,one@example.test,NORTH,One Name,,ACTIVE\n"
                + "CUS-0003,three@example.test,NORTH,Three,ok,ACTIVE\n"
                + "CUS-0002,two@example.test,SOUTH,Two Name,\"has, comma\",PAUSED\n"
            ).encode("utf-8")
            self.assertEqual(output.read_bytes(), expected)
            document = json.loads(audit.read_text(encoding="utf-8"))
            self.assertEqual(list(document), [
                "schema_version", "input_sha256", "output_sha256", "rows_read",
                "rows_written", "region_counts", "status_counts",
            ])
            self.assertEqual(document["input_sha256"], hashlib.sha256(source_bytes).hexdigest())
            self.assertEqual(document["output_sha256"], hashlib.sha256(expected).hexdigest())
            self.assertEqual(document["rows_read"], 3)
            self.assertEqual(document["rows_written"], 3)
            self.assertEqual(document["region_counts"], {"NORTH": 2, "SOUTH": 1})
            self.assertEqual(document["status_counts"], {"ACTIVE": 2, "PAUSED": 1})
            first_output, first_audit = output.read_bytes(), audit.read_bytes()

            output.write_text("stale", encoding="utf-8")
            audit.write_text("stale", encoding="utf-8")
            second = self.invoke(source, output, audit)
            self.assertEqual(second.returncode, 0, second.stderr)
            self.assertEqual(output.read_bytes(), first_output)
            self.assertEqual(audit.read_bytes(), first_audit)
            self.assertTrue(audit.read_bytes().endswith(b"\n"))

    def test_duplicate_rejection_removes_stale_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            source, output, audit = base / "in.csv", base / "out.csv", base / "audit.json"
            source.write_text(
                HEADER
                + "cus-0011,one@example.test,north,One,first,active\n"
                + "CUS-0011,two@example.test,south,Two,second,paused\n",
                encoding="utf-8",
            )
            output.write_text("stale", encoding="utf-8")
            audit.write_text("stale", encoding="utf-8")
            result = self.invoke(source, output, audit)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("duplicate customer_ref CUS-0011", result.stderr)
            self.assertFalse(output.exists())
            self.assertFalse(audit.exists())

    def test_malformed_utf8_csv_schema_extra_cell_and_invalid_values_reject(self) -> None:
        cases = {
            "utf8": b"\xff",
            "csv": (HEADER + 'CUS-0001,a@b,north,"open,note,active\n').encode(),
            "bare_quote": (HEADER + 'CUS-0001,a@b,north,Na"me,n,active\n').encode(),
            "schema": b"email,customer_ref,region,display_name,note,status\n",
            "extra": (HEADER + "CUS-0001,a@b,north,A,n,active,extra\n").encode(),
            "email": (HEADER + "CUS-0001,a b@c,north,A,n,active\n").encode(),
            "region": (HEADER + "CUS-0001,a@b,east,A,n,active\n").encode(),
            "status": (HEADER + "CUS-0001,a@b,north,A,n,deleted\n").encode(),
        }
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            for name, content in cases.items():
                with self.subTest(name=name):
                    source = base / f"{name}.csv"
                    output = base / f"{name}.out.csv"
                    audit = base / f"{name}.audit.json"
                    source.write_bytes(content)
                    result = self.invoke(source, output, audit)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertTrue(result.stderr.startswith("error:"), result.stderr)
                    self.assertFalse(output.exists())
                    self.assertFalse(audit.exists())

    def test_resolved_paths_must_be_distinct_without_mutating_input(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            source = base / "source.csv"
            audit = base / "audit.json"
            original = (HEADER + "CUS-0001,a@b,north,A,,active\n").encode()
            source.write_bytes(original)
            result = self.invoke(source, source, audit)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("three distinct paths", result.stderr)
            self.assertEqual(source.read_bytes(), original)
            self.assertFalse(audit.exists())


if __name__ == "__main__":
    unittest.main()
