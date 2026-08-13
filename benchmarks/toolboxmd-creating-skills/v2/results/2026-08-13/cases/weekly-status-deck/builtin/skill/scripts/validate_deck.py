#!/usr/bin/env python3
"""Validate the fixed Aster weekly status deck and optionally write its receipt."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


FRONTMATTER = """---
marp: true
theme: default
paginate: true
footer: Aster Weekly | Internal
---"""
HEADINGS = [
    "Aster Weekly Status",
    "Outcomes",
    "Work in progress",
    "Risks",
    "Decisions and asks",
]
CHECKS = ["frontmatter", "slide-order", "evidence", "claim-boundary"]
STATUSES = {"DONE", "ON TRACK", "BLOCKED", "UNCONFIRMED"}
EVIDENCE_AT_END = re.compile(r"\[([A-Za-z][A-Za-z0-9_-]*?\d+)\]\s*$")
SOURCE_ID = re.compile(r"(?m)^\s*([A-Za-z][A-Za-z0-9_-]*?\d+)\b")
IDEA_ID = re.compile(r"(?mi)^\s*([A-Za-z][A-Za-z0-9_-]*?\d+)\b[^\n]*\[IDEA\]")


def natural_id_key(value: str) -> tuple[int, str, str]:
    match = re.search(r"(\d+)$", value)
    if not match:
        return (sys.maxsize, value.casefold(), value)
    return (int(match.group(1)), value[: match.start()].casefold(), value)


def expected_receipt(evidence_ids: list[str]) -> dict[str, object]:
    return {
        "schema_version": 1,
        "slide_count": 5,
        "required_sections": HEADINGS,
        "evidence_ids": sorted(set(evidence_ids), key=natural_id_key),
        "unsupported_claims": 0,
        "checks": CHECKS,
    }


def validate(deck_path: Path, notes_path: Path | None) -> tuple[list[str], dict[str, object]]:
    errors: list[str] = []
    text = deck_path.read_text(encoding="utf-8")

    if not text.startswith(FRONTMATTER + "\n"):
        errors.append("frontmatter must match the private Aster template exactly")
        body = text
    else:
        body = text[len(FRONTMATTER) + 1 :]

    if "{{" in text or "}}" in text:
        errors.append("template placeholders remain")

    slides = re.split(r"(?m)^---\s*$", body)
    slides = [slide.strip() for slide in slides]
    if len(slides) != 5:
        errors.append(f"expected 5 slides, found {len(slides)}")

    actual_headings: list[str] = []
    for slide in slides:
        match = re.search(r"(?m)^# (.+?)\s*$", slide)
        actual_headings.append(match.group(1) if match else "")
    if actual_headings != HEADINGS:
        errors.append(f"slide headings/order mismatch: {actual_headings!r}")

    if slides:
        range_matches = re.findall(
            r"(?m)^Reporting range: (\d{4}-\d{2}-\d{2}) to (\d{4}-\d{2}-\d{2})\s*$",
            slides[0],
        )
        if len(range_matches) != 1:
            errors.append("title slide must contain one ISO reporting range")

    evidence_ids: list[str] = []
    bullet_pattern = re.compile(r"(?m)^\s*[-*+]\s+(.+?)\s*$")
    for slide_number, slide in enumerate(slides, start=1):
        for bullet in bullet_pattern.findall(slide):
            evidence = EVIDENCE_AT_END.search(bullet)
            if not evidence:
                errors.append(f"slide {slide_number} bullet lacks a terminal evidence marker: {bullet}")
            else:
                evidence_ids.append(evidence.group(1))

            status = re.match(r"\*\*([^*]+)\*\*\s+—\s+", bullet)
            if slide_number in (2, 3, 4):
                if not status or status.group(1) not in STATUSES:
                    errors.append(
                        f"slide {slide_number} status bullet must start with an exact contract label: {bullet}"
                    )
            elif status and status.group(1) not in STATUSES:
                errors.append(f"non-contract status label: {status.group(1)}")

    if "[IDEA]" in text.upper():
        errors.append("deck contains an unsupported [IDEA] marker")

    if notes_path:
        notes = notes_path.read_text(encoding="utf-8")
        known_ids = set(SOURCE_ID.findall(notes))
        idea_ids = set(IDEA_ID.findall(notes))
        if known_ids:
            unknown = sorted(set(evidence_ids) - known_ids, key=natural_id_key)
            if unknown:
                errors.append(f"deck cites identifiers absent from notes: {unknown}")
        cited_ideas = sorted(set(evidence_ids) & idea_ids, key=natural_id_key)
        if cited_ideas:
            errors.append(f"deck cites unsupported idea identifiers: {cited_ideas}")

    return errors, expected_receipt(evidence_ids)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("deck", type=Path)
    parser.add_argument("--notes", type=Path)
    parser.add_argument("--receipt", type=Path, help="validate an existing receipt")
    parser.add_argument("--write-receipt", type=Path)
    parser.add_argument(
        "--claims-reviewed",
        action="store_true",
        help="attest that every claim was manually checked against the notes",
    )
    args = parser.parse_args()

    if args.write_receipt and args.receipt:
        parser.error("use either --receipt or --write-receipt, not both")
    if args.write_receipt and not args.claims_reviewed:
        parser.error("--write-receipt requires --claims-reviewed")

    try:
        errors, receipt = validate(args.deck, args.notes)
    except (OSError, UnicodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    if args.receipt:
        try:
            existing = json.loads(args.receipt.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, json.JSONDecodeError) as exc:
            errors.append(f"cannot read receipt: {exc}")
        else:
            if existing != receipt or list(existing) != list(receipt):
                errors.append("receipt content or key order does not match the deck")

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    if args.write_receipt:
        args.write_receipt.parent.mkdir(parents=True, exist_ok=True)
        args.write_receipt.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")

    print(
        f"OK: 5 slides; {len(receipt['evidence_ids'])} unique evidence IDs; unsupported claims attested 0"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
