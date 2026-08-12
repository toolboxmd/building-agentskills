#!/usr/bin/env python3
"""Validate a portable Agent Skill package using only the standard library."""

from __future__ import annotations

import argparse
import ast
import json
import re
import subprocess
import sys
from pathlib import Path


PORTABLE_FIELDS = {
    "name",
    "description",
    "license",
    "compatibility",
    "metadata",
    "allowed-tools",
}
NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
LINK_RE = re.compile(r"(?<!!)\[[^\]]+\]\(([^)]+)\)")
LOCAL_UNIX_ROOTS = ("/" + "Users/", "/" + "home/")
LOCAL_PATH_RE = re.compile(
    rf"(?:{'|'.join(re.escape(root) for root in LOCAL_UNIX_ROOTS)}|"
    rf"[A-Za-z]:\\{'Users'}\\)[^\s'\"`]+"
)


class ValidationError(Exception):
    """Raised when the validator cannot inspect the requested package."""


def split_frontmatter(text: str) -> tuple[list[str], str]:
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        raise ValidationError("SKILL.md must begin with a YAML frontmatter delimiter")
    try:
        end = lines.index("---", 1)
    except ValueError as exc:
        raise ValidationError("SKILL.md frontmatter has no closing delimiter") from exc
    return lines[1:end], "\n".join(lines[end + 1 :])


def unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        try:
            parsed = ast.literal_eval(value)
        except (SyntaxError, ValueError):
            return value[1:-1]
        return parsed if isinstance(parsed, str) else value
    return value


def parse_frontmatter(lines: list[str]) -> tuple[dict[str, object], list[str]]:
    """Parse the simple top-level YAML shape used by portable frontmatter."""
    data: dict[str, object] = {}
    errors: list[str] = []
    index = 0
    while index < len(lines):
        line = lines[index]
        if not line.strip() or line.lstrip().startswith("#"):
            index += 1
            continue
        if line.startswith((" ", "\t")):
            errors.append(f"unexpected top-level indentation on frontmatter line {index + 2}")
            index += 1
            continue
        match = re.match(r"^([A-Za-z0-9_-]+):(?:\s*(.*))?$", line)
        if not match:
            errors.append(f"cannot parse frontmatter line {index + 2}: {line!r}")
            index += 1
            continue
        key, raw_value = match.group(1), (match.group(2) or "")
        if key in data:
            errors.append(f"duplicate frontmatter field: {key}")
        if raw_value in {"|", ">"}:
            block: list[str] = []
            index += 1
            while index < len(lines) and (not lines[index].strip() or lines[index].startswith((" ", "\t"))):
                block.append(lines[index].lstrip())
                index += 1
            separator = "\n" if raw_value == "|" else " "
            data[key] = separator.join(block).strip()
            continue
        if raw_value == "" and key == "metadata":
            mapping: dict[str, str] = {}
            index += 1
            while index < len(lines) and (not lines[index].strip() or lines[index].startswith((" ", "\t"))):
                child = lines[index].strip()
                if child and not child.startswith("#"):
                    child_match = re.match(r"^([^:]+):\s*(.*)$", child)
                    if not child_match or not child_match.group(2):
                        errors.append("metadata must be a flat string-to-string mapping")
                    else:
                        mapping[child_match.group(1).strip()] = unquote(child_match.group(2))
                index += 1
            data[key] = mapping
            continue
        data[key] = unquote(raw_value)
        index += 1
    return data, errors


def local_link_target(raw_target: str) -> str | None:
    target = raw_target.strip().strip("<>").split("#", 1)[0]
    if not target or "://" in target or target.startswith(("#", "mailto:")):
        return None
    return target


def validate_openai_sidecar(root: Path, errors: list[str]) -> None:
    sidecar = root / "agents" / "openai.yaml"
    if not sidecar.exists():
        return
    text = sidecar.read_text(encoding="utf-8")
    values: dict[str, str] = {}
    for key in ("display_name", "short_description", "default_prompt"):
        match = re.search(rf"^\s{{2}}{key}:\s*(.+)$", text, re.MULTILINE)
        if not match:
            errors.append(f"agents/openai.yaml is missing interface.{key}")
            continue
        raw = match.group(1).strip()
        if len(raw) < 2 or raw[0] != '"' or raw[-1] != '"':
            errors.append(f"agents/openai.yaml interface.{key} must be double-quoted")
            continue
        values[key] = unquote(raw)
    short = values.get("short_description", "")
    if short and not 25 <= len(short) <= 64:
        errors.append("agents/openai.yaml short_description must be 25-64 characters")
    prompt = values.get("default_prompt", "")
    if prompt and f"${root.name}" not in prompt:
        errors.append(f"agents/openai.yaml default_prompt must mention ${root.name}")
    if prompt and len(re.findall(r"[.!?](?:\s|$)", prompt)) != 1:
        errors.append("agents/openai.yaml default_prompt must be one sentence")


def validate_scripts(root: Path, errors: list[str]) -> None:
    scripts = root / "scripts"
    if not scripts.is_dir():
        return
    for path in sorted(item for item in scripts.rglob("*") if item.is_file()):
        relative = path.relative_to(root)
        if path.suffix == ".py":
            try:
                ast.parse(path.read_text(encoding="utf-8"), filename=str(relative))
            except SyntaxError as exc:
                errors.append(f"{relative} Python syntax error: {exc.msg} at line {exc.lineno}")
        elif path.suffix in {".sh", ".bash"}:
            result = subprocess.run(
                ["bash", "-n", str(path)], capture_output=True, text=True, check=False
            )
            if result.returncode:
                errors.append(f"{relative} shell syntax error: {result.stderr.strip()}")


def validate_evals(root: Path, expected_name: str, errors: list[str]) -> None:
    evals_path = root / "evals" / "evals.json"
    if not evals_path.exists():
        return
    try:
        data = json.loads(evals_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        errors.append(f"evals/evals.json is invalid JSON: {exc}")
        return
    if data.get("skill_name") != expected_name:
        errors.append("evals/evals.json skill_name must match frontmatter name")
    evals = data.get("evals")
    if not isinstance(evals, list) or not evals:
        errors.append("evals/evals.json must contain a nonempty evals array")
        return
    for index, case in enumerate(evals, 1):
        if not isinstance(case, dict):
            errors.append(f"eval {index} must be an object")
            continue
        for field in ("id", "prompt", "expected_output", "files"):
            if field not in case:
                errors.append(f"eval {index} is missing {field}")


def validate(root: Path) -> list[str]:
    errors: list[str] = []
    if not root.is_dir():
        raise ValidationError(f"not a directory: {root}")
    skill_path = root / "SKILL.md"
    if not skill_path.is_file():
        raise ValidationError(f"missing required file: {skill_path}")
    text = skill_path.read_text(encoding="utf-8")
    frontmatter_lines, body = split_frontmatter(text)
    metadata, parse_errors = parse_frontmatter(frontmatter_lines)
    errors.extend(parse_errors)

    unknown = sorted(set(metadata) - PORTABLE_FIELDS)
    if unknown:
        errors.append(f"non-portable frontmatter field(s): {', '.join(unknown)}")
    name = metadata.get("name")
    description = metadata.get("description")
    if not isinstance(name, str) or not name:
        errors.append("frontmatter name is required and must be a string")
        name = ""
    elif len(name) > 64 or not NAME_RE.fullmatch(name):
        errors.append("name must be 1-64 lowercase letters/digits with single hyphen separators")
    if name and name != root.name:
        errors.append(f"frontmatter name {name!r} does not match directory {root.name!r}")
    if not isinstance(description, str) or not description.strip():
        errors.append("frontmatter description is required and must be nonempty")
    elif len(description) > 1024:
        errors.append(f"description is {len(description)} characters; maximum is 1024")
    compatibility = metadata.get("compatibility")
    if isinstance(compatibility, str) and len(compatibility) > 500:
        errors.append("compatibility exceeds 500 characters")
    if isinstance(metadata.get("metadata"), dict):
        for key, value in metadata["metadata"].items():
            if not isinstance(key, str) or not isinstance(value, str):
                errors.append("metadata must map strings to strings")

    line_count = len(text.splitlines())
    if line_count >= 500:
        errors.append(f"SKILL.md has {line_count} lines; it must remain below 500")
    if not body.strip():
        errors.append("SKILL.md body is empty")

    for path in sorted(item for item in root.rglob("*") if item.is_file()):
        if path.suffix.lower() in {".md", ".yaml", ".yml", ".json", ".py", ".sh"}:
            content = path.read_text(encoding="utf-8")
            if path.suffix.lower() == ".md":
                for match in LINK_RE.finditer(content):
                    target = local_link_target(match.group(1))
                    if target and not (path.parent / target).exists():
                        errors.append(
                            f"broken relative link in {path.relative_to(root)}: {target}"
                        )
            searchable = "\n".join(
                line for line in content.splitlines() if not line.startswith("#!")
            )
            if LOCAL_PATH_RE.search(searchable):
                errors.append(f"possible hardcoded absolute path in {path.relative_to(root)}")

    validate_openai_sidecar(root, errors)
    validate_scripts(root, errors)
    validate_evals(root, name, errors)
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate a portable Agent Skill package without modifying it.",
        epilog="Exit codes: 0 valid, 1 validation failures, 2 inspection or usage error.",
    )
    parser.add_argument("skill_root", nargs="?", default=".", help="skill directory (default: .)")
    args = parser.parse_args()
    try:
        errors = validate(Path(args.skill_root).resolve())
    except (OSError, UnicodeError, ValidationError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    if errors:
        for error in errors:
            print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print("PASS: portable skill package validation succeeded")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
