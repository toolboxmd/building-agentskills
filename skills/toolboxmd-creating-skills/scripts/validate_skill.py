#!/usr/bin/env python3
"""Read-only Agent Skill validator."""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit


PORTABLE_FIELDS = {"name", "description", "license", "compatibility", "metadata", "allowed-tools"}
NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
LINK_RE = re.compile(
    r'''!?\[[^\]]*\]\(\s*(<[^>\n]*>|[^\s)]+)(?:\s+(?:"(?:\\.|[^"])*"|'(?:\\.|[^'])*'|\((?:\\.|[^)])*\)))?\s*\)'''
)
OPENAI_FIELD_RE = re.compile(r'^([a-z_]+):\s*("(?:[^"\\]|\\.)*")$')
OPENAI_INTERFACE_FIELDS = {"display_name", "short_description", "icon_small", "icon_large", "brand_color", "default_prompt"}
OPENAI_TOOL_FIELDS = {"type", "value", "description", "transport", "url"}
FRAGILE_SCRIPT_RE = re.compile(
    r"\b(?:python(?:3(?:\.\d+)?)?|node|bash|sh|ruby)\b"
    r"(?:\s+-[A-Za-z0-9-]+(?:=[^\s]+)?)*\s+[\"']?scripts/"
)
LOCAL_PATH_RE = re.compile(
    rf"(?:{re.escape('/' + 'Users/')}|{re.escape('/' + 'home/')}|"
    rf"[A-Za-z]:\\{'Users'}\\)[^\s'\"`]+"
)
PROCESS_NAMES = {"README.md", "CHANGELOG.md", "STATUS.md", "DESIGN.md", "NOTES.md"}


class InspectionError(Exception):
    pass


def issue(severity: str, code: str, path: str, message: str) -> dict[str, str]:
    return {"severity": severity, "code": code, "path": path, "message": message}


def split_frontmatter(text: str) -> tuple[list[str], str]:
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        raise InspectionError("missing opening frontmatter delimiter")
    try:
        end = lines.index("---", 1)
    except ValueError as exc:
        raise InspectionError("missing closing frontmatter delimiter") from exc
    return lines[1:end], "\n".join(lines[end + 1 :])


def scalar(raw: str) -> str:
    value = raw.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        try:
            parsed = ast.literal_eval(value)
        except (SyntaxError, ValueError):
            return value[1:-1]
        return parsed if isinstance(parsed, str) else value
    return value


def parse_frontmatter(lines: list[str]) -> tuple[dict[str, object], list[dict[str, str]]]:
    data: dict[str, object] = {}
    problems: list[dict[str, str]] = []
    index = 0
    while index < len(lines):
        line = lines[index]
        if not line.strip() or line.lstrip().startswith("#"):
            index += 1
            continue
        if line.startswith((" ", "\t")):
            problems.append(issue("error", "FRONTMATTER_INDENT", "SKILL.md", f"unexpected indent at line {index + 2}"))
            index += 1
            continue
        match = re.match(r"^([A-Za-z0-9_-]+):(?:\s*(.*))?$", line)
        if not match:
            problems.append(issue("error", "FRONTMATTER_PARSE", "SKILL.md", f"unparsed frontmatter line {index + 2}"))
            index += 1
            continue
        key, raw_value = match.group(1), match.group(2) or ""
        if key in data:
            problems.append(issue("error", "FRONTMATTER_DUPLICATE", "SKILL.md", f"duplicate: {key}"))
        if raw_value in {"|", "|-", ">", ">-"}:
            block: list[str] = []
            index += 1
            while index < len(lines) and (not lines[index].strip() or lines[index].startswith((" ", "\t"))):
                block.append(lines[index].lstrip())
                index += 1
            separator = "\n" if raw_value.startswith("|") else " "
            data[key] = separator.join(block).strip()
            continue
        if raw_value == "" and key == "metadata":
            mapping: dict[str, str] = {}
            index += 1
            while index < len(lines) and (not lines[index].strip() or lines[index].startswith((" ", "\t"))):
                child = lines[index].strip()
                if child and not child.startswith("#"):
                    child_match = re.match(r"^([^:]+):\s*(.+)$", child)
                    if not child_match:
                        problems.append(issue("error", "METADATA_SHAPE", "SKILL.md", "metadata needs string keys and values"))
                    else:
                        mapping[child_match.group(1).strip()] = scalar(child_match.group(2))
                index += 1
            data[key] = mapping
            continue
        data[key] = scalar(raw_value)
        index += 1
    return data, problems


def collect_files(root: Path) -> tuple[list[dict[str, object]], list[dict[str, str]]]:
    files: list[dict[str, object]] = []
    problems: list[dict[str, str]] = []
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root).as_posix()
        if path.is_symlink():
            problems.append(issue("error", "SYMLINK", relative, "symlink not allowed"))
            continue
        if not path.is_file():
            continue
        contents = path.read_bytes()
        files.append(
            {
                "path": relative,
                "bytes": len(contents),
                "sha256": hashlib.sha256(contents).hexdigest(),
            }
        )
        if path.suffix in {".pyc", ".pyo"} or "__pycache__" in path.parts:
            problems.append(issue("error", "PYTHON_BYTECODE", relative, "bytecode not allowed"))
        if path.name in PROCESS_NAMES:
            problems.append(issue("warning", "PROCESS_ARTIFACT", relative, "needs distribution evidence"))
    files.sort(key=lambda record: str(record["path"]).encode("utf-8"))
    return files, problems


def validate_links_and_paths(root: Path, problems: list[dict[str, str]]) -> None:
    readable_suffixes = {".md", ".yaml", ".yml", ".json", ".py", ".sh", ".bash"}
    for path in sorted(item for item in root.rglob("*") if item.is_file() and not item.is_symlink()):
        if path.suffix.lower() not in readable_suffixes:
            continue
        relative = path.relative_to(root).as_posix()
        try:
            content = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            problems.append(issue("error", "UTF8", relative, "text file is not UTF-8"))
            continue
        searchable = "\n".join(line for line in content.splitlines() if not line.startswith("#!"))
        if LOCAL_PATH_RE.search(searchable):
            problems.append(issue("error", "LOCAL_PATH", relative, "workstation path"))
        if path.suffix.lower() != ".md":
            continue
        for match in LINK_RE.finditer(content):
            raw = match.group(1)
            if raw.startswith("<"):
                raw = raw[1:-1]
            parsed = urlsplit(raw)
            if parsed.scheme or raw.startswith(("#", "mailto:")):
                continue
            if raw.startswith("/"):
                problems.append(issue("error", "ROOT_LINK", relative, f"root-relative link: {raw}"))
                continue
            target_text = unquote(parsed.path)
            if not target_text:
                continue
            target = (path.parent / target_text).resolve()
            if not target.is_relative_to(root.resolve()):
                problems.append(issue("error", "LINK_ESCAPE", relative, f"link escapes package: {raw}"))
            elif not target.exists():
                problems.append(issue("error", "BROKEN_LINK", relative, f"missing link target: {raw}"))
        for line_number, line in enumerate(content.splitlines(), 1):
            if FRAGILE_SCRIPT_RE.search(line):
                problems.append(issue("warning", "FRAGILE_SCRIPT_PATH", relative, f"line {line_number} uses task-relative scripts/"))


def validate_sidecar(root: Path, name: str, problems: list[dict[str, str]]) -> None:
    sidecar = root / "agents" / "openai.yaml"
    if not sidecar.exists():
        return
    path = "agents/openai.yaml"

    def fail(code: str, message: str) -> None:
        problems.append(issue("error", code, path, message))

    section = ""
    values = {}
    tools = []
    tool = None
    tools_seen = False
    for line in sidecar.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        indent = len(line) - len(line.lstrip(" "))
        stripped = line.strip()
        if indent == 0:
            section = stripped[:-1] if stripped in {"interface:", "policy:", "dependencies:"} else ""
            tool = None
            if not section:
                fail("OPENAI_SHAPE", "unsupported section")
            continue
        target = None
        allowed = set()
        field = stripped
        if section == "interface" and indent == 2:
            target, allowed = values, OPENAI_INTERFACE_FIELDS
        elif section == "policy" and indent == 2:
            if not re.fullmatch(r"allow_implicit_invocation:\s*(true|false)", stripped):
                fail("OPENAI_SHAPE", "invalid policy")
            continue
        elif section == "dependencies":
            if indent == 2 and stripped == "tools:":
                tools_seen = True
                continue
            if tools_seen and indent == 4 and stripped.startswith("- "):
                tool = {}
                tools.append(tool)
                field = stripped[2:]
            elif indent != 6 or tool is None:
                fail("OPENAI_SHAPE", "invalid dependency")
                continue
            target, allowed = tool, OPENAI_TOOL_FIELDS
        else:
            fail("OPENAI_SHAPE", "unsupported shape")
            continue
        match = OPENAI_FIELD_RE.fullmatch(field)
        if not match or match.group(1) not in allowed:
            fail("OPENAI_SHAPE", "unsupported field")
            continue
        key, raw = match.groups()
        assert target is not None
        if key in target:
            fail("OPENAI_DUPLICATE", f"duplicate field: {key}")
            continue
        target[key] = scalar(raw)
    for key in {"display_name", "short_description", "default_prompt"} - values.keys():
        fail("OPENAI_MISSING", f"missing {key}")
    short = values.get("short_description", "")
    if short and not 25 <= len(short) <= 64:
        fail("OPENAI_SHORT_DESCRIPTION", "short_description length must be 25-64")
    prompt = values.get("default_prompt", "")
    if prompt and f"${name}" not in prompt:
        fail("OPENAI_DEFAULT_PROMPT", f"default_prompt must name ${name}")
    if prompt and len(re.findall(r"[.!?](?:\s|$)", prompt)) != 1:
        fail("OPENAI_DEFAULT_PROMPT", "default_prompt needs one sentence")
    color = values.get("brand_color", "")
    if color and not re.fullmatch(r"#[0-9A-Fa-f]{6}", color):
        fail("OPENAI_BRAND_COLOR", "brand_color needs six hex digits")
    for key in ("icon_small", "icon_large"):
        value = values.get(key, "")
        target = (root / value).resolve()
        if value and (value.startswith("/") or not target.is_relative_to(root.resolve()) or not target.is_file()):
            fail("OPENAI_ICON", f"invalid {key}")
    if any(tool.get("type") != "mcp" or not tool.get("value") for tool in tools):
        fail("OPENAI_DEPENDENCY", "each tool needs type mcp and value")


def validate_scripts(root: Path, problems: list[dict[str, str]]) -> None:
    for path in sorted((root / "scripts").rglob("*.py")) if (root / "scripts").is_dir() else []:
        relative = path.relative_to(root).as_posix()
        try:
            ast.parse(path.read_text(encoding="utf-8"), filename=relative)
        except SyntaxError as exc:
            problems.append(issue("error", "PYTHON_SYNTAX", relative, f"{exc.msg} at line {exc.lineno}"))


def budget_problem(value: int, maximum: int | None, code: str, label: str, problems: list[dict[str, str]]) -> None:
    if maximum is not None and value > maximum:
        problems.append(issue("error", code, "SKILL.md" if label.startswith("SKILL.md") or label.startswith("description") else ".", f"{label} is {value}; maximum is {maximum}"))


def validate(root: Path, args: argparse.Namespace) -> dict[str, object]:
    if not root.is_dir():
        raise InspectionError(f"not a directory: {root}")
    skill_path = root / "SKILL.md"
    if not skill_path.is_file():
        raise InspectionError(f"missing required file: {skill_path}")
    text = skill_path.read_text(encoding="utf-8")
    frontmatter_lines, body = split_frontmatter(text)
    metadata, problems = parse_frontmatter(frontmatter_lines)
    files, file_problems = collect_files(root)
    problems.extend(file_problems)

    unknown = sorted(set(metadata) - PORTABLE_FIELDS)
    if unknown:
        problems.append(issue("error", "FRONTMATTER_PORTABILITY", "SKILL.md", f"non-portable: {', '.join(unknown)}"))
    name = metadata.get("name")
    if not isinstance(name, str) or not name:
        problems.append(issue("error", "NAME_REQUIRED", "SKILL.md", "name is required"))
        name = ""
    elif len(name) > 64 or not NAME_RE.fullmatch(name):
        problems.append(issue("error", "NAME_FORMAT", "SKILL.md", "name must match lowercase kebab-case and be at most 64 characters"))
    elif any(reserved in name for reserved in ("anthropic", "claude")):
        problems.append(issue("error", "NAME_RESERVED", "SKILL.md", "name contains reserved provider text: anthropic or claude"))
    if name and name != root.name:
        problems.append(issue("error", "NAME_DIRECTORY", "SKILL.md", f"name {name!r} differs from directory {root.name!r}"))
    description = metadata.get("description")
    if not isinstance(description, str) or not description.strip():
        problems.append(issue("error", "DESCRIPTION_REQUIRED", "SKILL.md", "description is required"))
        description = ""
    compatibility = metadata.get("compatibility")
    if isinstance(compatibility, str) and len(compatibility) > 500:
        problems.append(issue("error", "COMPATIBILITY_BUDGET", "SKILL.md", "compatibility exceeds 500 chars"))
    if not body.strip():
        problems.append(issue("error", "BODY_EMPTY", "SKILL.md", "empty body"))

    validate_links_and_paths(root, problems)
    validate_sidecar(root, name, problems)
    validate_scripts(root, problems)

    skill_bytes = len(text.encode("utf-8"))
    skill_lines = len(text.splitlines())
    package_bytes = sum(int(record["bytes"]) for record in files)
    reference_files = sum(str(record["path"]).startswith("references/") for record in files)
    eval_files = sum(str(record["path"]).startswith("evals/") for record in files)
    script_files = sum(str(record["path"]).startswith("scripts/") for record in files)
    metrics = {
        "descriptionCharacters": len(description),
        "skillMdLines": skill_lines,
        "skillMdBytes": skill_bytes,
        "fileCount": len(files),
        "packageBytes": package_bytes,
        "referenceFileCount": reference_files,
        "evalFileCount": eval_files,
        "scriptFileCount": script_files,
    }
    budget_problem(len(description), args.max_description_chars, "DESCRIPTION_BUDGET", "description characters", problems)
    budget_problem(skill_lines, args.max_skill_lines, "SKILL_LINES_BUDGET", "SKILL.md lines", problems)
    budget_problem(skill_bytes, args.max_skill_bytes, "SKILL_BYTES_BUDGET", "SKILL.md bytes", problems)
    budget_problem(len(files), args.max_files, "FILE_COUNT_BUDGET", "package files", problems)
    budget_problem(package_bytes, args.max_package_bytes, "PACKAGE_BYTES_BUDGET", "package bytes", problems)
    budget_problem(reference_files, args.max_reference_files, "REFERENCE_COUNT_BUDGET", "reference files", problems)
    budget_problem(eval_files, args.max_eval_files, "EVAL_COUNT_BUDGET", "eval files", problems)
    budget_problem(script_files, args.max_script_files, "SCRIPT_COUNT_BUDGET", "script files", problems)

    aggregate = hashlib.sha256(
        "".join(f"{record['sha256']}  {record['path']}\n" for record in files).encode("utf-8")
    ).hexdigest()
    problems.sort(key=lambda item: (item["severity"], item["code"], item["path"], item["message"]))
    error_count = sum(item["severity"] == "error" for item in problems)
    warning_count = sum(item["severity"] == "warning" for item in problems)
    failed = error_count > 0 or (args.warnings_as_errors and warning_count > 0)
    return {
        "schemaVersion": 1,
        "status": "fail" if failed else "pass",
        "aggregateSha256": aggregate,
        "metrics": metrics,
        "errorCount": error_count,
        "warningCount": warning_count,
        "issues": problems,
        "files": files,
    }


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(
        description="Validate an Agent Skill package read-only.",
        epilog="Exit: 0 valid, 1 invalid, 2 inspection error.",
    )
    result.add_argument("skill_root", nargs="?", default=".", help="skill root")
    result.add_argument("--json", action="store_true", help="JSON")
    result.add_argument("--warnings-as-errors", action="store_true", help="fail warnings")
    limits = (("description-chars", 1024), ("skill-lines", 499), ("skill-bytes", None), ("files", None),
              ("package-bytes", None), ("reference-files", None), ("eval-files", None), ("script-files", None))
    for name, default in limits:
        result.add_argument(f"--max-{name}", type=int, default=default)
    return result


def main() -> int:
    args = parser().parse_args()
    for key, value in vars(args).items():
        if key.startswith("max_") and value is not None and value < 0:
            parser().error(f"--{key.replace('_', '-')} must be zero or greater")
    try:
        result = validate(Path(args.skill_root).resolve(), args)
    except (OSError, UnicodeError, InspectionError) as exc:
        if args.json:
            print(json.dumps({"schemaVersion": 1, "status": "error", "message": str(exc)}, sort_keys=True))
        else:
            print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        metrics = result["metrics"]
        labels = (("description_chars", "descriptionCharacters"), ("skill_lines", "skillMdLines"),
                  ("skill_bytes", "skillMdBytes"), ("files", "fileCount"), ("package_bytes", "packageBytes"),
                  ("references", "referenceFileCount"), ("evals", "evalFileCount"), ("scripts", "scriptFileCount"))
        print("METRICS: " + " ".join(f"{label}={metrics[key]}" for label, key in labels))
        for item in result["issues"]:
            print(f"{item['severity'].upper()}: {item['code']} {item['path']}: {item['message']}")
        if result["status"] == "pass":
            print("PASS: portable skill package validation succeeded")
        else:
            print("FAIL: portable skill package validation failed", file=sys.stderr)
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
