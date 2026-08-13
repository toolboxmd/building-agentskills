#!/usr/bin/env python3
"""Validate meeting follow-up artifacts against marked meeting notes."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from datetime import date
from pathlib import Path


HEADER = ["action_id", "owner", "due_date", "status", "action", "source"]
QA_KEYS = [
    "schema_version",
    "meeting_date",
    "decision_count",
    "action_count",
    "open_question_count",
    "deferred_idea_count",
    "tracker_rows_added",
    "missing_due_dates",
    "checks",
]
CHECKS = ["source-citations", "tracker-schema", "no-idea-promotion"]
OWNER_MAP = {
    "Maya Chen": "@maya",
    "Leo Park": "@leo",
    "Nina Gomez": "@nina",
    "Oliver Smith": "@oliver",
}
HEADINGS = [
    "# Meeting follow-up",
    "## Decisions",
    "## Action items",
    "## Open questions",
    "## Deferred ideas",
]
TYPES = ("DECISION", "ACTION", "QUESTION", "IDEA", "CHATTER")
ENTRY_RE = re.compile(
    rf"^\s*(?P<source>[A-Za-z0-9_-]+)\s+\[(?P<kind>{'|'.join(TYPES)})\]\s*(?P<body>.*)$"
)
CITATION_RE = re.compile(r"\[([A-Za-z0-9_-]+)\]\s*$")
ACTION_BULLET_RE = re.compile(
    r"^- (?P<owner>@[A-Za-z0-9_-]+|TBD) \| due (?P<due>\d{4}-\d{2}-\d{2}|TBD) \| .+ \[(?P<source>[A-Za-z0-9_-]+)\]$"
)


def fail(errors: list[str], message: str) -> None:
    errors.append(message)


def read_csv(path: Path, errors: list[str]) -> tuple[list[str], list[list[str]]]:
    try:
        with path.open(newline="", encoding="utf-8") as handle:
            rows = list(csv.reader(handle))
    except (OSError, csv.Error) as exc:
        fail(errors, f"cannot read CSV {path}: {exc}")
        return [], []
    if not rows:
        fail(errors, f"CSV is empty: {path}")
        return [], []
    if rows[0] != HEADER:
        fail(errors, f"wrong CSV header in {path}: {rows[0]!r}")
    for number, row in enumerate(rows[1:], 2):
        if len(row) != len(HEADER):
            fail(errors, f"CSV row {number} has {len(row)} columns, expected 6")
    return rows[0], rows[1:]


def parse_sections(text: str, errors: list[str]) -> dict[str, list[str]]:
    headings = [line for line in text.splitlines() if line.startswith("#")]
    if headings != HEADINGS:
        fail(errors, f"headings must be exactly {HEADINGS!r}, got {headings!r}")
    sections = {heading: [] for heading in HEADINGS[1:]}
    current: str | None = None
    for line in text.splitlines():
        if line in sections:
            current = line
        elif line.startswith("- ") and current:
            sections[current].append(line)
    return sections


def expected_action_fields(body: str) -> tuple[str, str]:
    """Return owner and due date when the marked action uses contract fields."""
    parts = [part.strip() for part in body.split("|")]
    owner = "TBD"
    due = "TBD"
    if len(parts) >= 3:
        owner = OWNER_MAP.get(parts[0], "TBD")
        if re.fullmatch(r"\d{4}-\d{2}-\d{2}", parts[1]):
            due = parts[1]
    elif len(parts) == 2:
        if parts[0] in OWNER_MAP:
            owner = OWNER_MAP[parts[0]]
        elif re.fullmatch(r"\d{4}-\d{2}-\d{2}", parts[0]):
            due = parts[0]
    return owner, due


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--notes", type=Path, required=True)
    parser.add_argument("--tracker-before", type=Path)
    parser.add_argument("--meeting-date", required=True)
    parser.add_argument("--output-dir", type=Path, default=Path("output"))
    args = parser.parse_args()
    errors: list[str] = []

    try:
        meeting_date = date.fromisoformat(args.meeting_date)
    except ValueError:
        print("ERROR: --meeting-date must be an ISO date", file=sys.stderr)
        return 1

    try:
        note_lines = args.notes.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        print(f"ERROR: cannot read notes: {exc}", file=sys.stderr)
        return 1
    entries = []
    for line in note_lines:
        match = ENTRY_RE.match(line)
        if match:
            entries.append(match.groupdict())
    by_kind = {kind: [e for e in entries if e["kind"] == kind] for kind in TYPES}
    all_sources = [e["source"] for e in entries]
    if len(all_sources) != len(set(all_sources)):
        fail(errors, "meeting-note source markers are not unique")

    follow_path = args.output_dir / "follow-up.md"
    actions_path = args.output_dir / "actions.csv"
    qa_path = args.output_dir / "qa.json"
    for path in (follow_path, actions_path, qa_path):
        if not path.is_file():
            fail(errors, f"missing required file: {path}")
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1

    sections = parse_sections(follow_path.read_text(encoding="utf-8"), errors)
    section_kinds = {
        "## Decisions": "DECISION",
        "## Action items": "ACTION",
        "## Open questions": "QUESTION",
        "## Deferred ideas": "IDEA",
    }
    for heading, kind in section_kinds.items():
        bullets = sections[heading]
        citations = []
        for bullet_index, bullet in enumerate(bullets):
            match = CITATION_RE.search(bullet)
            if not match:
                fail(errors, f"bullet lacks a terminal citation in {heading}: {bullet}")
            else:
                citations.append(match.group(1))
            if kind == "ACTION":
                action_match = ACTION_BULLET_RE.match(bullet)
                if not action_match:
                    fail(errors, f"invalid action bullet format: {bullet}")
                elif bullet_index < len(by_kind["ACTION"]):
                    expected_owner, expected_due = expected_action_fields(
                        by_kind["ACTION"][bullet_index]["body"]
                    )
                    if action_match.group("owner") != expected_owner:
                        fail(errors, f"action bullet owner must be {expected_owner!r}: {bullet}")
                    if action_match.group("due") != expected_due:
                        fail(errors, f"action bullet due date must be {expected_due!r}: {bullet}")
        expected = [e["source"] for e in by_kind[kind]]
        if citations != expected:
            fail(errors, f"{heading} citations {citations!r} do not match {expected!r}")

    _, output_rows = read_csv(actions_path, errors)
    prior_rows: list[list[str]] = []
    if args.tracker_before:
        _, prior_rows = read_csv(args.tracker_before, errors)
        if output_rows[: len(prior_rows)] != prior_rows:
            fail(errors, "existing tracker rows were not preserved exactly")
    added = output_rows[len(prior_rows) :]
    action_entries = by_kind["ACTION"]
    if len(added) != len(action_entries):
        fail(errors, f"tracker appended {len(added)} rows, expected {len(action_entries)}")

    expected_prefix = f"M-{meeting_date.strftime('%y%m%d')}-"
    expected_ids = [f"{expected_prefix}{index:02d}" for index in range(1, len(action_entries) + 1)]
    for index, (row, entry) in enumerate(zip(added, action_entries)):
        if len(row) != 6:
            continue
        expected_id = expected_ids[index]
        if row[0] != expected_id:
            fail(errors, f"new row {index + 1} ID is {row[0]!r}, expected {expected_id!r}")
        if row[3] != "open":
            fail(errors, f"new row {index + 1} status must be 'open'")
        if row[5] != entry["source"]:
            fail(errors, f"new row {index + 1} source is {row[5]!r}, expected {entry['source']!r}")
        expected_owner, expected_due = expected_action_fields(entry["body"])
        if row[1] != expected_owner:
            fail(errors, f"new row {index + 1} owner is {row[1]!r}, expected {expected_owner!r}")
        if row[2] != expected_due:
            fail(errors, f"new row {index + 1} due date is {row[2]!r}, expected {expected_due!r}")
    ids = [row[0] for row in output_rows if len(row) == 6]
    if len(ids) != len(set(ids)):
        fail(errors, "tracker action IDs are not unique")
    idea_sources = {entry["source"] for entry in by_kind["IDEA"]}
    promoted = [row[5] for row in added if len(row) == 6 and row[5] in idea_sources]
    if promoted:
        fail(errors, f"idea sources were promoted to tracker rows: {promoted!r}")

    try:
        qa = json.loads(qa_path.read_text(encoding="utf-8"), object_pairs_hook=dict)
    except (OSError, json.JSONDecodeError) as exc:
        fail(errors, f"cannot parse qa.json: {exc}")
        qa = {}
    if list(qa.keys()) != QA_KEYS:
        fail(errors, f"qa.json keys/order must be exactly {QA_KEYS!r}")
    missing_due = [row[0] for row in added if len(row) == 6 and row[2] == "TBD"]
    expected_qa = {
        "schema_version": 1,
        "meeting_date": meeting_date.isoformat(),
        "decision_count": len(by_kind["DECISION"]),
        "action_count": len(action_entries),
        "open_question_count": len(by_kind["QUESTION"]),
        "deferred_idea_count": len(by_kind["IDEA"]),
        "tracker_rows_added": len(added),
        "missing_due_dates": missing_due,
        "checks": CHECKS,
    }
    if qa != expected_qa:
        fail(errors, f"qa.json values do not match expected values: {expected_qa!r}")

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print(f"Validated {len(entries)} classified entries and {len(added)} appended tracker rows.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
