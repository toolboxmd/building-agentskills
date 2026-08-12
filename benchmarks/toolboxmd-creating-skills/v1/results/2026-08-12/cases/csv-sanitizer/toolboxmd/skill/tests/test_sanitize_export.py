from __future__ import annotations

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SKILL_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = SKILL_ROOT / "scripts" / "sanitize_export.py"
HEADER = b"customer_ref,email,region,display_name,note,status\n"


class SanitizerTests(unittest.TestCase):
    def invoke(self, source: bytes, *, same_output: bool = False):
        temporary = tempfile.TemporaryDirectory(dir=SKILL_ROOT / "tests")
        self.addCleanup(temporary.cleanup)
        work = Path(temporary.name)
        input_path = work / "input.csv"
        output_path = input_path if same_output else work / "nested" / "output.csv"
        audit_path = work / "audit" / "audit.json"
        input_path.write_bytes(source)
        if not same_output:
            output_path.parent.mkdir(parents=True)
            output_path.write_bytes(b"stale output")
        audit_path.parent.mkdir(parents=True)
        audit_path.write_bytes(b"stale audit")
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--input", str(input_path),
             "--output", str(output_path), "--audit", str(audit_path)],
            cwd=SKILL_ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        return result, output_path, audit_path

    def test_normalizes_sorts_audits_and_is_byte_deterministic(self):
        source = HEADER + (
            " cus-0007 ,MIRA@EXAMPLE.TEST,nord,  Mira   Sol  ,\"prefers, email\",enabled\n"
            "CUS-0002,ivo@example.test,SOUTH,Ivo Lane,,paused\n"
            "\n"
            "CUS-0009,zoe@example.test,n,Zoë Reed,  VIP   customer  ,ACTIVE\n"
        ).encode("utf-8")
        result, output_path, audit_path = self.invoke(source)
        self.assertEqual(result.returncode, 0, result.stderr.decode())
        expected = HEADER + (
            "CUS-0007,mira@example.test,NORTH,Mira Sol,\"prefers, email\",ACTIVE\n"
            "CUS-0009,zoe@example.test,NORTH,Zoë Reed,VIP customer,ACTIVE\n"
            "CUS-0002,ivo@example.test,SOUTH,Ivo Lane,,PAUSED\n"
        ).encode("utf-8")
        self.assertEqual(output_path.read_bytes(), expected)
        expected_audit = {
            "schema_version": 1,
            "input_sha256": hashlib.sha256(source).hexdigest(),
            "output_sha256": hashlib.sha256(expected).hexdigest(),
            "rows_read": 3,
            "rows_written": 3,
            "region_counts": {"NORTH": 2, "SOUTH": 1},
            "status_counts": {"ACTIVE": 2, "PAUSED": 1},
        }
        first_audit = audit_path.read_bytes()
        self.assertEqual(json.loads(first_audit), expected_audit)
        self.assertTrue(first_audit.endswith(b"\n"))

        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--input", str(Path(output_path).parents[1] / "input.csv"),
             "--output", str(output_path), "--audit", str(audit_path)],
            cwd=SKILL_ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr.decode())
        self.assertEqual(output_path.read_bytes(), expected)
        self.assertEqual(audit_path.read_bytes(), first_audit)

    def test_duplicate_after_normalization_removes_stale_artifacts(self):
        source = HEADER + (
            b"cus-0011,one@example.test,north,One,first,active\n"
            b"CUS-0011,two@example.test,south,Two,second,paused\n"
        )
        result, output_path, audit_path = self.invoke(source)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"duplicate customer_ref", result.stderr)
        self.assertFalse(output_path.exists())
        self.assertFalse(audit_path.exists())

    def test_rejects_malformed_utf8_csv_and_path_collision(self):
        cases = (
            (HEADER + b"CUS-0001,a@example.test,north,Name,,active\xff\n", b"valid UTF-8"),
            (HEADER + b'CUS-0001,a@example.test,north,"Name,,active\n', b"malformed CSV"),
            (HEADER + b'CUS-0001,a@example.test,north,Na"me,,active\n', b"unquoted field"),
        )
        for source, diagnostic in cases:
            with self.subTest(diagnostic=diagnostic):
                result, output_path, audit_path = self.invoke(source)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(diagnostic, result.stderr)
                self.assertFalse(output_path.exists())
                self.assertFalse(audit_path.exists())

        valid = HEADER + b"CUS-0001,a@example.test,north,Name,,active\n"
        result, input_path, audit_path = self.invoke(valid, same_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b"three distinct paths", result.stderr)
        self.assertEqual(input_path.read_bytes(), valid)
        self.assertFalse(audit_path.exists())


if __name__ == "__main__":
    unittest.main()
