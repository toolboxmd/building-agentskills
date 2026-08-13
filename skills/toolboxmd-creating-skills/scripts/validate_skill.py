#!/usr/bin/env python3
"""Read-only canonical ToolboxMD skill package checker."""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit


PORTABLE_FIELDS = {"name", "description", "license", "compatibility", "metadata", "allowed-tools"}
STRING_FIELDS = PORTABLE_FIELDS - {"metadata"}
NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
NON_STRING_RE = re.compile(r"(?i)(?:\[.*\]|\{.*\}|true|false|null|~|[-+]?\.(?:inf|nan)|[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:e[-+]?\d+)?)")
BLOCK_SCALAR_RE = re.compile(r"[|>](?:[1-9][+-]?|[+-][1-9]?|[+-]?)")
LINK_RE = re.compile(
    r'''!?\[[^\]]*\]\(\s*(<[^>\n]*>|[^\s)]+)(?:\s+(?:"(?:\\.|[^"])*"|'(?:\\.|[^'])*'|\((?:\\.|[^)])*\)))?\s*\)'''
)
REFERENCE_DEFINITION_RE = re.compile(
    r'''(?m)^ {0,3}\[[^\]\n]+\]:[ \t]*(<[^>\n]*>|[^\s<>]+)(?:[ \t]+(?:"(?:\\.|[^"\n])*"|'(?:\\.|[^'\n])*'|\((?:\\.|[^)\n])*\)))?[ \t]*$'''
)
OPENAI_FIELD_RE = re.compile(r'^([a-z_]+):\s*("(?:[^"\\]|\\.)*")$')
OPENAI_INTERFACE_FIELDS = {"display_name", "short_description", "icon_small", "icon_large", "brand_color", "default_prompt"}
OPENAI_TOOL_FIELDS = {"type", "value", "description", "transport", "url"}
CODE_SPAN_RE = re.compile(r"(?s)(?<!`)(`+)(?!`).*?(?<!`)\1(?!`)")
FRAGILE_SCRIPT_RE = re.compile(
    r"\b(?:python(?:3(?:\.\d+)?)?|node|bash|sh|ruby)\b"
    r"(?:\s+-[A-Za-z0-9-]+(?:=[^\s]+)?)*\s+[\"']?(?:\./)?scripts/"
)
ROOT_NAMES = ("Users", "home", "workspace", "root")
POSIX_ROOTS = "|".join(re.escape(f"/{name}/") for name in ROOT_NAMES)
LOCAL_PATH_RE = re.compile(
    rf"(?:file:///(?:{'|'.join(ROOT_NAMES)})/|(?<![A-Za-z0-9:/])(?:{POSIX_ROOTS}|"
    rf"[A-Za-z]:(?:{re.escape('/' + 'Users/')}|(?:\\)+{'Users'}(?:\\)+)))[^\s'\"`]+"
)
PROCESS_NAMES = {"README.md", "CHANGELOG.md", "STATUS.md", "DESIGN.md", "NOTES.md"}
TEXT_SUFFIXES = {
    ".md", ".yaml", ".yml", ".json", ".py", ".sh", ".bash",
    ".js", ".mjs", ".cjs", ".ts", ".tsx", ".jsx", ".rb", ".ps1",
    ".svg", ".xml", ".txt", ".toml", ".html", ".css",
}
OFFICIAL_TIMEOUT_SECONDS = 2


class InspectionError(Exception):
    pass


def issue(code: str, path: str, message: str, severity: str = "error") -> dict[str, str]:
    return {"severity": severity, "code": code, "path": path, "message": message}


def split_frontmatter(text: str) -> tuple[list[str], str]:
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        raise InspectionError("missing opening ---")
    try:
        end = lines.index("---", 1)
    except ValueError as exc:
        raise InspectionError("missing closing ---") from exc
    return lines[1:end], "\n".join(lines[end + 1 :])


def canonical_scalar(raw: str) -> str:
    value = raw.strip()
    if not value:
        return ""
    if value.startswith('"'):
        if not value.endswith('"'):
            raise ValueError("unterminated double-quoted string")
        try:
            parsed = json.loads(value)
        except (json.JSONDecodeError, TypeError) as exc:
            raise ValueError("invalid double-quoted string") from exc
        if not isinstance(parsed, str):
            raise ValueError("value is not a string")
        return parsed
    if value.startswith("'"):
        if not value.endswith("'"):
            raise ValueError("unterminated single-quoted string")
        inner = value[1:-1]
        if "'" in inner.replace("''", ""):
            raise ValueError("invalid single-quoted string")
        return inner.replace("''", "'")
    if value.endswith(("'", '"')):
        raise ValueError("mismatched quote")
    if NON_STRING_RE.fullmatch(value):
        raise TypeError("value is not a string")
    if value[0] in "-?:,[]{}&*!|>%@`" or re.search(r":(?:\s|$)", value):
        raise ValueError("noncanonical plain string")
    return value


def without_comment(raw: str) -> str:
    quote = ""
    escaped = False
    index = 0
    while index < len(raw):
        char = raw[index]
        if quote:
            if quote == "'" and char == "'" and index + 1 < len(raw) and raw[index + 1] == "'":
                index += 2
                continue
            if char == quote and not escaped:
                quote = ""
            escaped = quote == '"' and char == "\\" and not escaped
        elif char in "\"'":
            quote = char
        elif char == "#" and (index == 0 or raw[index - 1].isspace()):
            return raw[:index].rstrip()
        index += 1
    return raw.strip()


def parse_string(raw: str, field: str, problems: list[dict[str, str]]) -> str:
    try:
        return canonical_scalar(raw)
    except TypeError:
        problems.append(issue("FRONTMATTER_TYPE", "SKILL.md", f"{field} must be a string"))
    except ValueError:
        problems.append(issue("FRONTMATTER_STRING", "SKILL.md", f"{field} is not a canonical one-line string"))
    return ""


def parse_metadata(
    lines: list[str], index: int, problems: list[dict[str, str]], allow_hermes: bool
) -> tuple[dict[str, object], int]:
    mapping: dict[str, object] = {}
    hermes = config = False
    required: set[str] = set()
    entry_keys: set[str] = set()
    while index < len(lines) and (not lines[index].strip() or lines[index].lstrip().startswith("#") or lines[index].startswith((" ", "\t"))):
        line = lines[index]
        index += 1
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if "\t" in line[: len(line) - len(line.lstrip())]:
            problems.append(issue("FRONTMATTER_INDENT", "SKILL.md", "metadata uses tab indentation"))
            continue
        indent = len(line) - len(line.lstrip(" "))
        field = without_comment(line.strip())
        match = re.fullmatch(r"(?:- )?([^:]+):\s*(.*)", field)
        key, raw = match.groups() if match else ("", "")
        value = without_comment(raw)
        if indent == 2 and key == "hermes" and not value and "hermes" not in mapping and allow_hermes:
            hermes, config = True, False
            mapping[key] = {}
        elif indent == 2 and match and value and key not in mapping:
            mapping[key] = parse_string(value, f"metadata.{key}", problems)
        elif indent == 2 and key in mapping:
            problems.append(issue("FRONTMATTER_DUPLICATE", "SKILL.md", f"duplicate metadata key: {key}"))
        elif indent == 4 and hermes and key == "config" and not value and not config:
            config = True
        elif config and match and key in {"key", "description", "default", "prompt"} and value and ((indent == 6 and field.startswith("- ")) or (indent == 8 and key not in required)):
            if indent == 6:
                if required and not {"key", "description"} <= required:
                    problems.append(issue("METADATA_SHAPE", "SKILL.md", "invalid Hermes entry"))
                required = set()
                entry_keys = set()
            if key in entry_keys:
                problems.append(issue("FRONTMATTER_DUPLICATE", "SKILL.md", f"duplicate Hermes field: {key}"))
            entry_keys.add(key)
            required.add(key)
            parse_string(value, f"metadata.hermes.config.{key}", problems)
        else:
            message = "Hermes metadata requires --allow-hermes-metadata" if key == "hermes" and not allow_hermes else "unsupported nesting"
            problems.append(issue("METADATA_SHAPE", "SKILL.md", message))
    if hermes and (not config or not {"key", "description"} <= required):
        problems.append(issue("METADATA_SHAPE", "SKILL.md", "Hermes config needs key + description"))
    return mapping, index


def parse_frontmatter(lines: list[str], allow_hermes: bool) -> tuple[dict[str, object], list[dict[str, str]]]:
    data: dict[str, object] = {}
    problems: list[dict[str, str]] = []
    index = 0
    while index < len(lines):
        line = lines[index]
        if not line.strip() or line.lstrip().startswith("#"):
            index += 1
            continue
        if line.startswith((" ", "\t")):
            problems.append(issue("FRONTMATTER_INDENT", "SKILL.md", f"indent at line {index + 2}"))
            index += 1
            continue
        match = re.match(r"^([A-Za-z0-9_-]+):(?:\s*(.*))?$", line)
        if not match:
            problems.append(issue("FRONTMATTER_PARSE", "SKILL.md", f"unparsed line {index + 2}"))
            index += 1
            continue
        key, raw_value = match.group(1), without_comment(match.group(2) or "")
        if key in data:
            problems.append(issue("FRONTMATTER_DUPLICATE", "SKILL.md", f"duplicate: {key}"))
        if BLOCK_SCALAR_RE.fullmatch(raw_value):
            problems.append(issue("FRONTMATTER_STYLE", "SKILL.md", f"{key} must use a canonical one-line scalar"))
            data[key] = "" if key != "metadata" else {}
            index += 1
            continue
        if key == "metadata":
            if raw_value:
                problems.append(issue("METADATA_SHAPE", "SKILL.md", "metadata needs a mapping"))
                data[key] = {}
                index += 1
                continue
            data[key], index = parse_metadata(lines, index + 1, problems, allow_hermes)
            continue
        data[key] = parse_string(raw_value, key, problems) if key in STRING_FIELDS else raw_value
        index += 1
    return data, problems


def collect_files(root: Path) -> tuple[list[dict[str, object]], list[dict[str, str]]]:
    files: list[dict[str, object]] = []
    problems: list[dict[str, str]] = []
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root).as_posix()
        if path.is_symlink():
            problems.append(issue("SYMLINK", relative, "symlink not allowed"))
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
            problems.append(issue("PYTHON_BYTECODE", relative, "bytecode not allowed"))
        if path.name in PROCESS_NAMES:
            problems.append(issue("PROCESS_ARTIFACT", relative, "needs distribution evidence", "warning"))
    files.sort(key=lambda record: str(record["path"]).encode("utf-8"))
    return files, problems


def markdown_without_code(text: str) -> str:
    output: list[str] = []
    fence = ""
    for line in text.splitlines(keepends=True):
        marker = re.match(r"^ {0,3}(`{3,}|~{3,})", line)
        if fence:
            if marker and marker.group(1)[0] == fence[0] and len(marker.group(1)) >= len(fence) and not line[marker.end(1) :].strip():
                fence = ""
        elif marker and (marker.group(1)[0] == "~" or "`" not in line[marker.end(1) :]):
            fence = marker.group(1)
        elif not line.startswith(("    ", "\t")):
            output.append(line)
    result = CODE_SPAN_RE.sub("", "".join(output))
    return re.sub(r"\\\[[^]\n]*\](?:\([^\n)]*\)|\[[^]\n]*\])", "", result)


def validate_links_and_paths(root: Path, problems: list[dict[str, str]]) -> None:
    resolved_root = root.resolve()

    def validate_destination(raw: str, relative: str, parent: Path) -> None:
        if raw.startswith("<"):
            raw = raw[1:-1]
        parsed = urlsplit(raw)
        if parsed.scheme or raw.startswith(("#", "mailto:", "//")):
            return
        if raw.startswith("/"):
            problems.append(issue("ROOT_LINK", relative, f"root-relative link: {raw}"))
            return
        target_text = unquote(parsed.path)
        if not target_text:
            return
        target = (parent / target_text).resolve()
        if not target.is_relative_to(resolved_root):
            problems.append(issue("LINK_ESCAPE", relative, f"link escapes package: {raw}"))
        elif not target.exists():
            problems.append(issue("BROKEN_LINK", relative, f"missing link target: {raw}"))

    for path in sorted(item for item in root.rglob("*") if item.is_file() and not item.is_symlink()):
        relative = path.relative_to(root).as_posix()
        try:
            content = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            if path.suffix.lower() in TEXT_SUFFIXES or os.access(path, os.X_OK):
                problems.append(issue("UTF8", relative, "text file is not UTF-8"))
            continue
        path_searchable = content
        if path.suffix.lower() == ".md":
            for pattern in (LINK_RE, REFERENCE_DEFINITION_RE):
                path_searchable = pattern.sub(
                    lambda match: match.group(0).replace(match.group(1), "") if match.group(1).lstrip("<").startswith("/") else match.group(0),
                    path_searchable,
                )
        if LOCAL_PATH_RE.search(path_searchable):
            problems.append(issue("LOCAL_PATH", relative, "workstation path"))
        if path.suffix.lower() != ".md":
            continue
        markdown = markdown_without_code(content)
        complex_link = re.compile(r"!?\[[^]\n]*\]\([^\n)]*\([^\n]*\)[^\n]*\)")
        unsupported_markdown = bool(re.search(r"(?m)^ {0,3}\[[^]\n]+\]:\s*$", markdown) or complex_link.search(markdown))
        if unsupported_markdown:
            problems.append(issue("OFFICIAL_VALIDATOR_REQUIRED", relative, "complex Markdown link shape needs an official validator", "warning"))
        canonical_markdown = complex_link.sub("", markdown)
        for pattern in (LINK_RE, REFERENCE_DEFINITION_RE):
            for match in pattern.finditer(canonical_markdown):
                validate_destination(match.group(1), relative, path.parent)
        definitions = {match.group(0).split("]:", 1)[0][1:].casefold() for match in REFERENCE_DEFINITION_RE.finditer(canonical_markdown)}
        for match in re.finditer(r"(?<!!)\[([^]\n]+)\]\[([^]\n]+)\]", canonical_markdown):
            if match.group(2).casefold() not in definitions:
                problems.append(issue("OFFICIAL_VALIDATOR_REQUIRED", relative, "undefined reference label needs an official validator", "warning"))
        residual = LINK_RE.sub("", REFERENCE_DEFINITION_RE.sub("", canonical_markdown))
        residual = re.sub(r"(?<!!)\[[^]\n]+\]\[[^]\n]+\]", "", residual)
        if not unsupported_markdown and ("](" in residual or "][" in residual):
            problems.append(issue("OFFICIAL_VALIDATOR_REQUIRED", relative, "nested Markdown link shape needs an official validator", "warning"))
        for line_number, line in enumerate(content.splitlines(), 1):
            if FRAGILE_SCRIPT_RE.search(line):
                problems.append(issue("FRAGILE_SCRIPT_PATH", relative, f"line {line_number} uses task-relative scripts/", "warning"))


def validate_sidecar(root: Path, name: str, problems: list[dict[str, str]]) -> None:
    sidecar = root / "agents" / "openai.yaml"
    if not sidecar.exists():
        return
    path = "agents/openai.yaml"

    def fail(code: str, message: str) -> None:
        problems.append(issue(code, path, message))

    section = ""
    sections: set[str] = set()
    values: dict[str, str] = {}
    tools: list[dict[str, str]] = []
    tool = None
    tools_seen = False
    policy_seen = False
    for line in sidecar.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if "\t" in line[: len(line) - len(line.lstrip())]:
            fail("OPENAI_SHAPE", "tab indentation is not canonical")
            continue
        indent = len(line) - len(line.lstrip(" "))
        stripped = without_comment(line[indent:])
        if not stripped:
            continue
        if indent == 0:
            section = stripped[:-1] if stripped in {"interface:", "policy:", "dependencies:"} else ""
            tool = None
            if not section:
                fail("OPENAI_SHAPE", "unsupported section")
            elif section in sections:
                fail("OPENAI_DUPLICATE", f"duplicate section: {section}")
            else:
                sections.add(section)
            continue
        target = None
        allowed = set()
        field = stripped
        if section == "interface" and indent == 2:
            target, allowed = values, OPENAI_INTERFACE_FIELDS
        elif section == "policy" and indent == 2:
            if not re.fullmatch(r"allow_implicit_invocation:\s*(true|false)", stripped):
                fail("OPENAI_SHAPE", "invalid policy")
            elif policy_seen:
                fail("OPENAI_DUPLICATE", "duplicate field: allow_implicit_invocation")
            policy_seen = True
            continue
        elif section == "dependencies":
            if indent == 2 and stripped == "tools:":
                if tools_seen:
                    fail("OPENAI_DUPLICATE", "duplicate field: dependencies.tools")
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
        try:
            target[key] = canonical_scalar(raw)
        except (TypeError, ValueError):
            fail("OPENAI_SHAPE", f"invalid quoted string: {key}")
    for key in {"display_name", "short_description"}:
        if not values.get(key):
            fail("OPENAI_MISSING", f"missing or empty {key}")
    display = values.get("display_name", "")
    if len(display) > 64:
        fail("OPENAI_DISPLAY_NAME", "display_name length must be at most 64")
    short = values.get("short_description", "")
    if short and not 25 <= len(short) <= 64:
        fail("TOOLBOXMD_SHORT_DESCRIPTION", "ToolboxMD policy requires short_description length 25-64")
    prompt = values.get("default_prompt", "")
    if len(prompt) > 1024:
        fail("OPENAI_DEFAULT_PROMPT", "default_prompt length must be at most 1024")
    if prompt and not re.search(rf"(?<![A-Za-z0-9_-])\${re.escape(name)}(?![A-Za-z0-9_-])", prompt):
        fail("OPENAI_DEFAULT_PROMPT", f"default_prompt must name ${name}")
    color = values.get("brand_color", "")
    if color and not re.fullmatch(r"#[0-9A-Fa-f]{6}", color):
        fail("OPENAI_BRAND_COLOR", "brand_color needs six hex digits")
    for key in ("icon_small", "icon_large"):
        value = values.get(key, "")
        target = (root / value).resolve()
        assets = (root / "assets").resolve()
        if value and (value.startswith("/") or not target.is_relative_to(assets) or not target.is_file()):
            fail("OPENAI_ICON", f"invalid {key}")
    if any(tool.get("type") != "mcp" or not tool.get("value") for tool in tools):
        fail("OPENAI_DEPENDENCY", "each tool needs type mcp and value")


def validate_scripts(root: Path, problems: list[dict[str, str]]) -> None:
    scripts = root / "scripts"
    for path in sorted(scripts.rglob("*")) if scripts.is_dir() else []:
        if not path.is_file() or path.is_symlink():
            continue
        relative = path.relative_to(root).as_posix()
        if path.suffix.lower() != ".py":
            try:
                path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            problems.append(issue("SCRIPT_SYNTAX_UNCHECKED", relative, "non-Python helper needs its own syntax test", "warning"))
            continue
        try:
            ast.parse(path.read_text(encoding="utf-8"), filename=relative)
        except SyntaxError as exc:
            problems.append(issue("PYTHON_SYNTAX", relative, f"{exc.msg} at line {exc.lineno}"))


def budget_problem(value: int, maximum: int | None, code: str, label: str, problems: list[dict[str, str]]) -> None:
    if maximum is not None and value > maximum:
        problems.append(issue(code, "SKILL.md" if label.startswith(("SKILL.md", "description")) else ".", f"{label}: {value} > {maximum}"))


def run_official_validator(root: Path, problems: list[dict[str, str]]) -> dict[str, object]:
    command = shutil.which("skills-ref")
    coverage: dict[str, object] = {
        "attempted": False,
        "status": "not_available",
        "exitCode": None,
        "externalBehaviorAttested": False,
    }
    if not command:
        return coverage
    coverage["attempted"] = True
    try:
        completed = subprocess.run(
            [command, "validate", str(root)],
            capture_output=True,
            check=False,
            shell=False,
            text=True,
            timeout=OFFICIAL_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        coverage["status"] = "timeout"
        problems.append(issue("OFFICIAL_VALIDATOR_TIMEOUT", ".", f"skills-ref exceeded {OFFICIAL_TIMEOUT_SECONDS}s"))
        return coverage
    except OSError:
        coverage["status"] = "error"
        problems.append(issue("OFFICIAL_VALIDATOR_ERROR", ".", "skills-ref could not be executed"))
        return coverage
    coverage["exitCode"] = completed.returncode
    if completed.returncode == 0:
        coverage["status"] = "pass"
    elif completed.returncode == 1:
        coverage["status"] = "fail"
        problems.append(issue("OFFICIAL_VALIDATOR", ".", "skills-ref validate reported invalid"))
    else:
        coverage["status"] = "error"
        problems.append(issue("OFFICIAL_VALIDATOR_ERROR", ".", f"skills-ref returned unexpected exit {completed.returncode}"))
    return coverage


def validate(root: Path, args: argparse.Namespace) -> dict[str, object]:
    if not root.is_dir():
        raise InspectionError(f"not a directory: {root}")
    skill_path = root / "SKILL.md"
    if not skill_path.is_file():
        raise InspectionError(f"missing required file: {skill_path}")
    text = skill_path.read_text(encoding="utf-8")
    frontmatter_lines, body = split_frontmatter(text)
    metadata, problems = parse_frontmatter(frontmatter_lines, args.allow_hermes_metadata)
    files, file_problems = collect_files(root)
    problems.extend(file_problems)

    unknown = sorted(set(metadata) - PORTABLE_FIELDS)
    if unknown:
        problems.append(issue("FRONTMATTER_PORTABILITY", "SKILL.md", f"non-portable: {', '.join(unknown)}"))
    name = metadata.get("name")
    if not isinstance(name, str) or not name:
        problems.append(issue("NAME_REQUIRED", "SKILL.md", "name is required"))
        name = ""
    elif len(name) > 64 or not NAME_RE.fullmatch(name):
        problems.append(issue("NAME_FORMAT", "SKILL.md", "lowercase kebab-case, max 64 chars"))
    elif any(reserved in name for reserved in ("anthropic", "claude")):
        problems.append(issue("NAME_RESERVED", "SKILL.md", "reserved anthropic/claude text"))
    if name and name != root.name:
        problems.append(issue("NAME_DIRECTORY", "SKILL.md", f"name {name!r} differs from directory {root.name!r}"))
    description = metadata.get("description")
    if not isinstance(description, str) or not description.strip():
        problems.append(issue("DESCRIPTION_REQUIRED", "SKILL.md", "description is required"))
        description = ""
    compatibility = metadata.get("compatibility")
    if isinstance(compatibility, str) and len(compatibility) > 500:
        problems.append(issue("COMPATIBILITY_BUDGET", "SKILL.md", "compatibility > 500 chars"))
    if not body.strip():
        problems.append(issue("BODY_EMPTY", "SKILL.md", "empty body"))

    validate_links_and_paths(root, problems)
    validate_sidecar(root, name, problems)
    validate_scripts(root, problems)
    official = run_official_validator(root, problems)

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
        "coverage": {
            "canonicalSubset": "toolboxmd-portable-core-v1",
            "enabledExtensions": ["hermes-metadata"] if args.allow_hermes_metadata else [],
            "markdown": "canonical inline links and single-line reference definitions",
            "scriptSyntax": "Python .py files via AST; other helper syntax unchecked",
            "officialSkillsRef": official,
        },
        "aggregateSha256": aggregate,
        "metrics": metrics,
        "errorCount": error_count,
        "warningCount": warning_count,
        "issues": problems,
        "files": files,
    }


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(
        description="Check a canonical ToolboxMD Agent Skill package read-only.",
        epilog="Exit: 0 valid, 1 invalid, 2 inspection error.",
    )
    result.add_argument("skill_root", nargs="?", default=".", help="skill root")
    result.add_argument("--json", action="store_true", help="JSON")
    result.add_argument("--warnings-as-errors", action="store_true", help="fail warnings")
    result.add_argument("--allow-hermes-metadata", action="store_true", help="allow canonical metadata.hermes.config extension")
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
        coverage = result["coverage"]
        official = coverage["officialSkillsRef"]
        extensions = ",".join(coverage["enabledExtensions"]) or "none"
        print(f"COVERAGE: canonical={coverage['canonicalSubset']} extensions={extensions} script_syntax=python-ast-only official_skills_ref={official['status']} official_external_attested=false")
        labels = (("description_chars", "descriptionCharacters"), ("skill_lines", "skillMdLines"),
                  ("skill_bytes", "skillMdBytes"), ("files", "fileCount"), ("package_bytes", "packageBytes"),
                  ("references", "referenceFileCount"), ("evals", "evalFileCount"), ("scripts", "scriptFileCount"))
        print("METRICS: " + " ".join(f"{label}={metrics[key]}" for label, key in labels))
        for item in result["issues"]:
            print(f"{item['severity'].upper()}: {item['code']} {item['path']}: {item['message']}")
        if result["status"] == "pass":
            print("PASS: canonical ToolboxMD package checks succeeded")
        else:
            print("FAIL: canonical ToolboxMD package checks failed", file=sys.stderr)
    return 0 if result["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
