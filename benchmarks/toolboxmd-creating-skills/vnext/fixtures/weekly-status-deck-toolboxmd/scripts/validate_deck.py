#!/usr/bin/env python3
"""Validate an Aster weekly status deck and optionally write its receipt."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


FRONTMATTER = [
    "---",
    "marp: true",
    "theme: default",
    "paginate: true",
    "footer: Aster Weekly | Internal",
    "---",
]
HEADINGS = [
    "Aster Weekly Status",
    "Outcomes",
    "Work in progress",
    "Risks",
    "Decisions and asks",
]
CHECKS = ["frontmatter", "slide-order", "evidence", "claim-boundary"]
SOURCE_AT_END = re.compile(r"\[([A-Za-z][A-Za-z0-9_-]*\d+)\]\s*$")
DATE_RANGE = re.compile(r"\b\d{4}-\d{2}-\d{2}\s+to\s+\d{4}-\d{2}-\d{2}\b")
PLACEHOLDER = re.compile(r"\{\{[A-Z_]+\}\}")


def natural_key(value: str) -> list[object]:
    """Sort identifier digit runs numerically while retaining stable text order."""
    return [int(part) if part.isdigit() else part.lower() for part in re.split(r"(\d+)", value)]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate an Aster five-slide Marp status deck.",
        epilog="Exit codes: 0 valid, 1 deck invalid, 2 review/receipt usage or I/O error.",
    )
    parser.add_argument("deck", type=Path, help="path to status-deck.md")
    parser.add_argument(
        "--receipt",
        type=Path,
        help="write deck-check.json here after all checks pass",
    )
    parser.add_argument(
        "--claim-boundary-reviewed",
        action="store_true",
        help="confirm a human/agent compared every claim and qualifier with the notes",
    )
    return parser.parse_args()


def inspect_deck(path: Path) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    evidence_ids: list[str] = []
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        return [f"cannot read deck: {exc}"], []

    lines = text.splitlines()
    if lines[: len(FRONTMATTER)] != FRONTMATTER:
        errors.append("frontmatter must match the private Marp template exactly")
        body_lines = lines
    else:
        body_lines = lines[len(FRONTMATTER) :]

    body = "\n".join(body_lines).strip()
    slides = re.split(r"\n---\n", body) if body else []
    if len(slides) != 5:
        errors.append(f"slide count is {len(slides)}; expected 5")

    found_headings: list[str] = []
    for index, slide in enumerate(slides, start=1):
        heading_lines = [line for line in slide.splitlines() if line.startswith("# ")]
        if len(heading_lines) != 1:
            errors.append(f"slide {index} must contain exactly one level-1 heading")
        elif heading_lines:
            found_headings.append(heading_lines[0][2:])
    if found_headings != HEADINGS:
        errors.append("slide headings or order do not match the required five sections")

    if slides and not DATE_RANGE.search(slides[0]):
        errors.append("title slide must include an ISO reporting range: YYYY-MM-DD to YYYY-MM-DD")

    for line_number, line in enumerate(lines, start=1):
        if PLACEHOLDER.search(line):
            errors.append(f"line {line_number}: unresolved template placeholder")
        if re.match(r"^\s*-\s+", line):
            match = SOURCE_AT_END.search(line)
            if not match:
                errors.append(
                    f"line {line_number}: factual bullet must end with a bracketed source identifier"
                )
            else:
                evidence_ids.append(match.group(1))
        if "[IDEA]" in line.upper():
            errors.append(f"line {line_number}: unsupported IDEA marker/content is not allowed")

    return errors, sorted(set(evidence_ids), key=natural_key)


def write_receipt(path: Path, evidence_ids: list[str]) -> None:
    receipt = {
        "schema_version": 1,
        "slide_count": 5,
        "required_sections": HEADINGS,
        "evidence_ids": evidence_ids,
        "unsupported_claims": 0,
        "checks": CHECKS,
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    if args.receipt and not args.claim_boundary_reviewed:
        print(
            "error: --receipt requires --claim-boundary-reviewed after comparison with source notes",
            file=sys.stderr,
        )
        return 2

    errors, evidence_ids = inspect_deck(args.deck)
    if not evidence_ids:
        errors.append("deck contains no cited factual bullets")
    if errors:
        for error in errors:
            print(f"error: {error}", file=sys.stderr)
        return 1

    if args.receipt:
        try:
            write_receipt(args.receipt, evidence_ids)
        except OSError as exc:
            print(f"error: cannot write receipt: {exc}", file=sys.stderr)
            return 2
        print(f"valid: wrote {args.receipt}")
    else:
        print("valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
