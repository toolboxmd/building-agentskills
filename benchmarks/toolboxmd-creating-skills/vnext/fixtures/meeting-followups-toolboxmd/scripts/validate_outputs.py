#!/usr/bin/env python3
"""Validate meeting follow-up deliverables without modifying any files."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import OrderedDict
from datetime import date
from pathlib import Path


CSV_HEADER = ["action_id", "owner", "due_date", "status", "action", "source"]
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
QA_CHECKS = ["source-citations", "tracker-schema", "no-idea-promotion"]
HEADINGS = [
    "# Meeting follow-up",
    "## Decisions",
    "## Action items",
    "## Open questions",
    "## Deferred ideas",
]
SECTION_TAGS = OrderedDict(
    [
        ("## Decisions", "DECISION"),
        ("## Action items", "ACTION"),
        ("## Open questions", "QUESTION"),
        ("## Deferred ideas", "IDEA"),
    ]
)
OWNERS = {
    "Maya Chen": "@maya",
    "Leo Park": "@leo",
    "Nina Gomez": "@nina",
    "Oliver Smith": "@oliver",
}
TAG_RE = re.compile(
    r"^\s*(?:[-*]\s+)?(?P<source>[A-Za-z][A-Za-z0-9_-]*)\s+"
    r"\[(?P<tag>DECISION|ACTION|IDEA|QUESTION|CHATTER)\]\s*"
    r"(?P<text>.*?)\s*$",
    re.MULTILINE,
)
ISO_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
ACTION_BULLET_RE = re.compile(
    r"^- (?P<owner>@[a-z]+|TBD) \| due (?P<due>\d{4}-\d{2}-\d{2}|TBD) "
    r"\| (?P<action>.+) \[(?P<source>[A-Za-z][A-Za-z0-9_-]*)\]$"
)
SOURCE_END_RE = re.compile(r"\[([A-Za-z][A-Za-z0-9_-]*)\]$")


class InputError(Exception):
    """An input cannot be opened or parsed, so validation cannot run."""


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        raise InputError(f"cannot read {path}: {exc}") from exc


def validate_iso_date(value: str) -> None:
    try:
        parsed = date.fromisoformat(value)
    except ValueError as exc:
        raise InputError(f"invalid meeting date {value!r}; expected YYYY-MM-DD") from exc
    if parsed.isoformat() != value:
        raise InputError(f"meeting date must use zero-padded ISO form: {value!r}")


def parse_notes(path: Path) -> list[dict[str, str]]:
    entries = [match.groupdict() for match in TAG_RE.finditer(read_text(path))]
    if not entries:
        raise InputError(f"no explicitly tagged note lines found in {path}")
    sources = [entry["source"] for entry in entries]
    duplicates = sorted({source for source in sources if sources.count(source) > 1})
    if duplicates:
        raise InputError(f"duplicate note source markers: {', '.join(duplicates)}")
    return entries


def expected_action(entry: dict[str, str]) -> tuple[str, str, str]:
    parts = [part.strip() for part in entry["text"].split("|")]
    owner = OWNERS.get(parts[0], "TBD") if len(parts) > 1 else "TBD"
    due = next((part for part in parts[:-1] if ISO_DATE_RE.fullmatch(part)), "TBD")
    action = parts[-1] if len(parts) > 1 else parts[0]
    return owner, due, action


def read_csv(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    try:
        with path.open(newline="", encoding="utf-8") as handle:
            reader = csv.DictReader(handle)
            header = reader.fieldnames or []
            rows = list(reader)
    except (OSError, UnicodeError, csv.Error) as exc:
        raise InputError(f"cannot parse CSV {path}: {exc}") from exc
    return header, rows


def sections_from_markdown(text: str, errors: list[str]) -> dict[str, list[str]]:
    headings = [line for line in text.splitlines() if line.startswith("#")]
    if headings != HEADINGS:
        errors.append("follow-up headings must exactly match the required headings and order")
    sections = {heading: [] for heading in SECTION_TAGS}
    active: str | None = None
    for line in text.splitlines():
        if line in SECTION_TAGS:
            active = line
        elif line.startswith("#"):
            active = None
        elif line.startswith("- ") and active:
            sections[active].append(line)
    return sections


def validate_follow_up(
    path: Path, entries: list[dict[str, str]], errors: list[str]
) -> dict[str, tuple[str, str, str]]:
    sections = sections_from_markdown(read_text(path), errors)
    action_values: dict[str, tuple[str, str, str]] = {}
    for heading, tag in SECTION_TAGS.items():
        expected_sources = [entry["source"] for entry in entries if entry["tag"] == tag]
        actual_sources: list[str] = []
        for bullet in sections[heading]:
            source_match = SOURCE_END_RE.search(bullet)
            if not source_match:
                errors.append(f"follow-up bullet lacks a final source citation: {bullet}")
                continue
            source = source_match.group(1)
            actual_sources.append(source)
            if tag == "ACTION":
                action_match = ACTION_BULLET_RE.fullmatch(bullet)
                if not action_match:
                    errors.append(f"action bullet has invalid format: {bullet}")
                    continue
                action_values[source] = (
                    action_match.group("owner"),
                    action_match.group("due"),
                    action_match.group("action"),
                )
        if actual_sources != expected_sources:
            errors.append(
                f"{heading} sources are {actual_sources!r}; expected {expected_sources!r}"
            )
    chatter = {entry["source"] for entry in entries if entry["tag"] == "CHATTER"}
    delivered = {
        match.group(1)
        for lines in sections.values()
        for line in lines
        if (match := SOURCE_END_RE.search(line))
    }
    leaked = sorted(chatter & delivered)
    if leaked:
        errors.append(f"chatter appears in follow-up: {', '.join(leaked)}")
    return action_values


def validate_tracker(
    output_path: Path,
    original_path: Path,
    entries: list[dict[str, str]],
    meeting_date: str,
    follow_up_actions: dict[str, tuple[str, str, str]],
    errors: list[str],
) -> tuple[list[str], int]:
    original_header, original_rows = read_csv(original_path)
    output_header, output_rows = read_csv(output_path)
    if original_header != CSV_HEADER:
        errors.append(f"input tracker header is {original_header!r}; expected {CSV_HEADER!r}")
    if output_header != CSV_HEADER:
        errors.append(f"output tracker header is {output_header!r}; expected {CSV_HEADER!r}")
    if output_rows[: len(original_rows)] != original_rows:
        errors.append("existing tracker rows were changed or reordered")

    new_rows = output_rows[len(original_rows) :]
    actions = [entry for entry in entries if entry["tag"] == "ACTION"]
    if len(new_rows) != len(actions):
        errors.append(f"tracker added {len(new_rows)} rows; expected {len(actions)}")
    expected_ids = [
        f"M-{meeting_date[2:4]}{meeting_date[5:7]}{meeting_date[8:10]}-{number:02d}"
        for number in range(1, len(actions) + 1)
    ]
    actual_ids = [row.get("action_id", "") for row in new_rows]
    if actual_ids != expected_ids:
        errors.append(f"new tracker identifiers are {actual_ids!r}; expected {expected_ids!r}")
    all_ids = [row.get("action_id", "") for row in output_rows]
    if len(all_ids) != len(set(all_ids)):
        errors.append("tracker action identifiers are not unique")

    expected_sources = [entry["source"] for entry in actions]
    actual_sources = [row.get("source", "") for row in new_rows]
    if actual_sources != expected_sources:
        errors.append(f"new tracker sources are {actual_sources!r}; expected {expected_sources!r}")
    idea_sources = {entry["source"] for entry in entries if entry["tag"] == "IDEA"}
    promoted = sorted(idea_sources & set(actual_sources))
    if promoted:
        errors.append(f"idea sources were promoted to tracker rows: {', '.join(promoted)}")

    missing_due_ids: list[str] = []
    for index, (row, entry) in enumerate(zip(new_rows, actions)):
        expected_owner, expected_due, _ = expected_action(entry)
        expected_id = expected_ids[index]
        if row.get("owner") != expected_owner:
            errors.append(f"{expected_id} owner is {row.get('owner')!r}; expected {expected_owner!r}")
        if row.get("due_date") != expected_due:
            errors.append(
                f"{expected_id} due_date is {row.get('due_date')!r}; expected {expected_due!r}"
            )
        if row.get("status") != "open":
            errors.append(f"{expected_id} status must be 'open'")
        if not row.get("action"):
            errors.append(f"{expected_id} action text is empty")
        if expected_due == "TBD":
            missing_due_ids.append(expected_id)
        follow_up = follow_up_actions.get(entry["source"])
        if follow_up and (
            row.get("owner"), row.get("due_date"), row.get("action")
        ) != follow_up:
            errors.append(f"{expected_id} does not match its follow-up action bullet")
    return missing_due_ids, len(new_rows)


def validate_qa(
    path: Path,
    entries: list[dict[str, str]],
    meeting_date: str,
    missing_due_ids: list[str],
    rows_added: int,
    errors: list[str],
) -> None:
    try:
        qa = json.loads(read_text(path), object_pairs_hook=OrderedDict)
    except json.JSONDecodeError as exc:
        raise InputError(f"cannot parse JSON {path}: {exc}") from exc
    if not isinstance(qa, dict):
        errors.append("qa.json must contain one JSON object")
        return
    if list(qa) != QA_KEYS:
        errors.append(f"qa.json keys/order are {list(qa)!r}; expected {QA_KEYS!r}")
    counts = {
        "DECISION": sum(entry["tag"] == "DECISION" for entry in entries),
        "ACTION": sum(entry["tag"] == "ACTION" for entry in entries),
        "QUESTION": sum(entry["tag"] == "QUESTION" for entry in entries),
        "IDEA": sum(entry["tag"] == "IDEA" for entry in entries),
    }
    expected = OrderedDict(
        [
            ("schema_version", 1),
            ("meeting_date", meeting_date),
            ("decision_count", counts["DECISION"]),
            ("action_count", counts["ACTION"]),
            ("open_question_count", counts["QUESTION"]),
            ("deferred_idea_count", counts["IDEA"]),
            ("tracker_rows_added", rows_added),
            ("missing_due_dates", missing_due_ids),
            ("checks", QA_CHECKS),
        ]
    )
    for key, value in expected.items():
        if qa.get(key) != value:
            errors.append(f"qa.json {key} is {qa.get(key)!r}; expected {value!r}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate follow-up.md, actions.csv, and qa.json without modifying them.",
        epilog="Exit codes: 0 valid, 1 contract violations, 2 input or usage error.",
    )
    parser.add_argument("--notes", required=True, type=Path, help="tagged meeting notes")
    parser.add_argument("--meeting-date", required=True, help="meeting date in YYYY-MM-DD form")
    parser.add_argument("--tracker", required=True, type=Path, help="original actions.csv")
    parser.add_argument("--output-dir", required=True, type=Path, help="directory containing outputs")
    args = parser.parse_args()
    try:
        validate_iso_date(args.meeting_date)
        entries = parse_notes(args.notes)
        errors: list[str] = []
        actions = validate_follow_up(args.output_dir / "follow-up.md", entries, errors)
        missing_due, rows_added = validate_tracker(
            args.output_dir / "actions.csv",
            args.tracker,
            entries,
            args.meeting_date,
            actions,
            errors,
        )
        validate_qa(
            args.output_dir / "qa.json",
            entries,
            args.meeting_date,
            missing_due,
            rows_added,
            errors,
        )
    except InputError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print("PASS: meeting follow-up outputs satisfy the contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
