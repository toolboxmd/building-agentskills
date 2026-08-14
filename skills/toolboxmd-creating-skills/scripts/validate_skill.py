#!/usr/bin/env python3
import argparse
import ast
import hashlib
import json
import os
import posixpath
import re
import shutil
import subprocess
import sys
from pathlib import Path, PurePosixPath
from urllib.parse import unquote, urlsplit


PORTABLE_FIELDS = {"name", "description", "license", "compatibility", "metadata", "allowed-tools"}
NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
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
FENCE_RE = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
SHELL_FENCE_LANGUAGES = {"sh", "bash", "shell"}
BARE_SCRIPT_PREFIX_RE = re.compile(r"(?<![A-Za-z0-9_$./\\~-])(?!~[/\\])(?:[^/\\\s'\"`;&|(){}\[\]<>:,]+[/\\]+)*scripts[/\\]+")
SCRIPT_ROOT_HINT = "use <skill-dir>/scripts/<helper>"
SCRIPT_CONTEXT_HINT = f"{SCRIPT_ROOT_HINT} in a closed sh/bash/shell fence"
LOCAL_ROOTS = "(?:Users|home|workspace|root)"
LOCAL_PATH_RE = re.compile(
    rf"(?<![A-Za-z0-9:/])(?:/{LOCAL_ROOTS}/|(?i:[A-Za-z]:(?:/Users/|(?:\\)+Users(?:\\)+)))[^\s'\"`]+"
)
URI_RE = re.compile(r'''(?i:file:)[^\s'"`<>()]+''')
LOCAL_FILE_URI_RE = re.compile(r'''(?<![A-Za-z0-9+./:#?=&_-])(?i:file:(?:/(?!/)|//(?:localhost)?/))[^\s'"`<>()]+''')
REMOTE_RE = re.compile(r'''(?i:(?<![a-z0-9+./:-])(?:(?!file:|[a-z]:[/\\])[a-z][a-z0-9+.-]*:|//)[^\s'"`]+|#[^\s'"`]*file:[^\s'"`]*)''')
LOCAL_FILE_PATH_RE = re.compile(rf"^/(?:{LOCAL_ROOTS}/|(?i:[A-Za-z]:[/\\]+Users[/\\]+))")
PROCESS_NAMES = {"README.md", "CHANGELOG.md", "STATUS.md", "DESIGN.md", "NOTES.md"}
TEXT_SUFFIXES = {
    ".md", ".yaml", ".yml", ".json", ".py", ".sh", ".bash",
    ".js", ".mjs", ".cjs", ".ts", ".tsx", ".jsx", ".rb", ".ps1",
    ".svg", ".xml", ".txt", ".toml", ".html", ".css",
}
OFFICIAL_TIMEOUT_SECONDS = 2
PORTABLE_DESCRIPTION_MAX = 1024


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
    if value[:1] != '"' or value[-1:] != '"':
        raise ValueError
    if re.search(r"(?<!\\)(?:\\\\)*\\u(?i:d[89a-f][0-9a-f]{2})", value):
        raise ValueError
    return json.loads(value)


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
    except ValueError:
        problems.append(issue("FRONTMATTER_STRING", "SKILL.md", f"{field} needs a one-line JSON string"))
    return ""


def parse_metadata(
    lines: list[str], index: int, problems: list[dict[str, str]], allow_hermes: bool
) -> tuple[dict[str, object], int, bool]:
    def fail(code: str, message: str) -> None:
        problems.append(issue(code, "SKILL.md", message))

    mapping: dict[str, object] = {}
    seen = False
    hermes = config = False
    entry_open = False
    entry_fields: set[str] = set()
    while index < len(lines) and (not lines[index].strip() or lines[index].lstrip().startswith("#") or lines[index].startswith((" ", "\t"))):
        line = lines[index]
        index += 1
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        seen = True
        if "\t" in line[: len(line) - len(line.lstrip())]:
            fail("FRONTMATTER_INDENT", "metadata uses tab indentation")
            continue
        indent = len(line) - len(line.lstrip(" "))
        field = without_comment(line.strip())
        mapping_match = re.fullmatch(r'("(?:\\.|[^"\\])*"|[a-z]+):\s*(.*)', field)
        sequence_match = re.fullmatch(r"- (key):\s*(.*)", field)
        match = sequence_match or mapping_match
        key, raw = match.groups() if match else ("", "")
        value = without_comment(raw)
        if indent == 2 and mapping_match and key == "hermes":
            if value or not allow_hermes:
                fail("METADATA_SHAPE", "Hermes needs --allow-hermes-metadata" if not allow_hermes else "Hermes needs a nested config")
            elif key in mapping:
                fail("FRONTMATTER_DUPLICATE", f"duplicate metadata key: {key}")
            else:
                hermes, config = True, False
                mapping[key] = {}
        elif indent == 2 and field.startswith("- "):
            fail("METADATA_SHAPE", "portable metadata needs a mapping")
        elif indent == 2:
            try:
                portable_key = canonical_scalar(key) if mapping_match else None
            except ValueError:
                portable_key = None
            if portable_key is None:
                fail("METADATA_KEY", "portable keys need JSON double quotes")
            elif portable_key in mapping:
                fail("FRONTMATTER_DUPLICATE", f"duplicate metadata key: {portable_key}")
            elif not value:
                fail("METADATA_SHAPE", "portable metadata needs a string value")
            else:
                mapping[portable_key] = parse_string(value, f"metadata.{portable_key}", problems)
        elif indent == 4 and hermes and mapping_match and key == "config" and not value and not config:
            config = True
        elif config and sequence_match and indent == 6:
            if entry_open and "description" not in entry_fields:
                fail("METADATA_SHAPE", "Hermes entry needs description")
            entry_fields = set()
            entry_open = bool(value)
            if not entry_open:
                fail("METADATA_SHAPE", "Hermes entry must start with - key")
            else:
                before = len(problems)
                decoded = parse_string(value, f"metadata.hermes.config.{key}", problems)
                if len(problems) == before and decoded.strip():
                    entry_fields.add(key)
                elif len(problems) == before:
                    fail("METADATA_SHAPE", "Hermes key must not be blank")
        elif config and entry_open and mapping_match and indent == 8 and key in {"description", "default", "prompt"} and value:
            if key in entry_fields:
                fail("FRONTMATTER_DUPLICATE", f"duplicate Hermes field: {key}")
            entry_fields.add(key)
            parse_string(value, f"metadata.hermes.config.{key}", problems)
        else:
            fail("METADATA_SHAPE", "unsupported nesting")
    if hermes and (not config or not entry_open or "description" not in entry_fields):
        fail("METADATA_SHAPE", "Hermes config needs key + description")
    return mapping, index, seen


def parse_frontmatter(lines: list[str], allow_hermes: bool) -> tuple[dict[str, object], list[dict[str, str]]]:
    data: dict[str, object] = {}
    problems: list[dict[str, str]] = []

    def fail(code: str, message: str) -> None:
        problems.append(issue(code, "SKILL.md", message))

    index = 0
    while index < len(lines):
        line = lines[index]
        if not line.strip() or line.lstrip().startswith("#"):
            index += 1
            continue
        if line.startswith((" ", "\t")):
            fail("FRONTMATTER_INDENT", f"indent at line {index + 2}")
            index += 1
            continue
        match = re.match(r"^([A-Za-z0-9_-]+):(?:\s*(.*))?$", line)
        if not match:
            fail("FRONTMATTER_PARSE", f"unparsed line {index + 2}")
            index += 1
            continue
        key, raw_value = match.group(1), without_comment(match.group(2) or "")
        if key in data:
            fail("FRONTMATTER_DUPLICATE", f"duplicate: {key}")
        if BLOCK_SCALAR_RE.fullmatch(raw_value):
            fail("FRONTMATTER_STYLE", f"{key} must use a canonical one-line scalar")
            data[key] = "" if key != "metadata" else {}
            index += 1
            continue
        if key == "metadata":
            if raw_value:
                fail("METADATA_SHAPE", "metadata needs a mapping")
                data[key] = {}
                index += 1
                continue
            data[key], index, seen = parse_metadata(lines, index + 1, problems, allow_hermes)
            if not seen:
                fail("METADATA_EMPTY", "omit empty metadata")
            continue
        data[key] = parse_string(raw_value, key, problems)
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
        if not relative.startswith("scripts/") and (path.stat().st_mode & 0o111 or contents.startswith(b"#!")):
            problems.append(issue("SCRIPT_LOCATION", relative, "executable/shebang helper must be below scripts/"))
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
    containers: list[int] = []
    for line in text.splitlines(keepends=True):
        view = fenced_line_view(line, containers) if fence else line
        if fence and view is None:
            fence = ""
            containers = []
            view = line
        marker = FENCE_RE.match(view)
        if fence:
            if marker and marker.group(1)[0] == fence[0] and len(marker.group(1)) >= len(fence) and not marker.group(2).strip():
                fence = ""
            continue
        view, candidate_containers = fence_candidate(line)
        marker = FENCE_RE.match(view)
        if marker and (marker.group(1)[0] == "~" or "`" not in marker.group(2)):
            fence = marker.group(1)
            containers = candidate_containers
        elif not view.startswith(("    ", "\t")):
            output.append(line)
    result = CODE_SPAN_RE.sub("", "".join(output))
    return re.sub(r"\\\[[^]\n]*\](?:\([^\n)]*\)|\[[^]\n]*\])", "", result)


def has_bare_script_path(text: str) -> bool:
    text = URI_RE.sub("", REMOTE_RE.sub("", text))

    def active_quote(stop: int) -> str:
        quote = ""
        escaped = False
        for char in text[:stop]:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif quote and char == quote:
                quote = ""
            elif not quote and char in "\"'`":
                quote = char
        return quote

    for match in BARE_SCRIPT_PREFIX_RE.finditer(text):
        index = match.end()
        quote = active_quote(match.start())
        while index < len(text) and text[index] in "\"'`":
            marker = text[index]
            if quote and marker != quote:
                return True
            quote = "" if marker == quote else marker
            index += 1
        if index >= len(text):
            continue
        if text[index].isspace():
            continue
        if quote:
            return True
        if text[index] == "<" and re.match(r"<[^>\s;&|]+>", text[index:]):
            return True
        if text[index] not in ";&|)<>]},:":
            return True
    return False


def fence_candidate(line: str) -> tuple[str, list[int]]:
    view = line
    containers: list[int] = []
    while True:
        if match := re.match(r"^ {0,3}>[ \t]?", view):
            containers.append(0)
        elif match := re.match(r"^ {0,3}(?:[-+*]|[0-9]{1,9}[.)])[ \t]+", view):
            containers.append(match.end())
        else:
            break
        view = view[match.end() :]
    return view, containers


def fenced_line_view(line: str, containers: list[int]):
    view = line
    for index, width in enumerate(containers):
        if not view.strip() and all(remaining > 0 for remaining in containers[index:]):
            return ""
        if not width:
            match = re.match(r"^ {0,3}>[ \t]?", view)
            if not match:
                return None
            view = view[match.end() :]
        elif view.startswith(" " * width):
            view = view[width:]
        else:
            return None
    return view


def validate_markdown_script_paths(content: str, relative: str, problems: list[dict[str, str]]) -> None:
    fence = ""
    shell_fence = False
    opener_line = 0
    containers: list[int] = []

    def add(code: str, line_number: int, message: str = SCRIPT_CONTEXT_HINT) -> None:
        problems.append(issue(code, relative, f"line {line_number} {message}"))

    for line_number, line in enumerate(content.splitlines(), 1):
        container_view = fenced_line_view(line, containers) if fence else line
        if fence and container_view is None:
            if shell_fence:
                add("MARKDOWN_FENCE", opener_line, "leaves its Markdown container without a closing fence")
            fence = ""
            shell_fence = False
            containers = []
            container_view = line
        view = container_view if container_view is not None else line
        marker = FENCE_RE.match(view) if container_view is not None else None
        if fence:
            if (
                marker
                and marker.group(1)[0] == fence[0]
                and len(marker.group(1)) >= len(fence)
                and not marker.group(2).strip()
            ):
                fence = ""
                shell_fence = False
                continue
            if has_bare_script_path(view):
                code = "FRAGILE_SCRIPT_PATH" if shell_fence else "UNFENCED_SCRIPT_EXAMPLE"
                add(code, line_number, SCRIPT_ROOT_HINT if shell_fence else SCRIPT_CONTEXT_HINT)
            continue
        view, candidate_containers = fence_candidate(line)
        marker = FENCE_RE.match(view)
        if marker and (marker.group(1)[0] == "~" or "`" not in marker.group(2)):
            fence = marker.group(1)
            language = marker.group(2).strip().split(maxsplit=1)[0].casefold() if marker.group(2).strip() else ""
            shell_fence = language in SHELL_FENCE_LANGUAGES
            opener_line = line_number
            containers = candidate_containers
            continue
        if view.startswith(("    ", "\t")):
            if has_bare_script_path(view):
                add("UNFENCED_SCRIPT_EXAMPLE", line_number)
            continue
        for match in CODE_SPAN_RE.finditer(view):
            marker = match.group(1)
            literal = match.group(0)[len(marker) : -len(marker)]
            prefix = view[: match.start()]
            escaped = (len(prefix) - len(prefix.rstrip("\\"))) % 2
            if not escaped and has_bare_script_path(literal):
                add("UNFENCED_SCRIPT_EXAMPLE", line_number)
    if fence and shell_fence:
        add("MARKDOWN_FENCE", opener_line, "opens a recognized shell fence without a closing fence")


def safe_urlsplit(raw: str, relative: str, problems: list[dict[str, str]]):
    try:
        return urlsplit(raw)
    except ValueError:
        malformed = issue("URI_SYNTAX", relative, f"malformed URI: {raw}")
        if malformed not in problems:
            problems.append(malformed)


def exact_path(parent, target):
    for part in PurePosixPath(target).parts:
        try:
            parent = next(entry for entry in parent.iterdir() if entry.name == part)
        except (OSError, StopIteration):
            return False
        if parent.is_symlink():
            return None
    return True


def validate_links_and_paths(root: Path, problems: list[dict[str, str]]) -> None:
    def validate_destination(raw: str, relative: str, parent: Path) -> None:
        if raw.startswith("<"):
            raw = raw[1:-1]
        parsed = safe_urlsplit(raw, relative, problems)
        if parsed is None:
            return
        if parsed.scheme or raw.startswith(("#", "mailto:", "//")):
            return
        if raw.startswith("/"):
            problems.append(issue("ROOT_LINK", relative, f"root-relative link: {raw}"))
            return
        target_text = unquote(parsed.path)
        if not target_text:
            return
        target_text = posixpath.normpath(posixpath.join(parent.relative_to(root).as_posix(), target_text))
        if target_text.partition("/")[0] in {"", ".."}:
            problems.append(issue("LINK_ESCAPE", relative, f"link escapes package: {raw}"))
        elif not exact_path(root, target_text):
            problems.append(issue("BROKEN_LINK", relative, f"missing link target: {raw}"))

    for path in sorted(item for item in root.rglob("*") if item.is_file() and not item.is_symlink()):
        relative = path.relative_to(root).as_posix()
        try:
            content = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            if path.suffix.lower() in TEXT_SUFFIXES or os.access(path, os.X_OK) or path.read_bytes().startswith(b"#!"):
                problems.append(issue("UTF8", relative, "text file is not UTF-8"))
            continue
        searchable = content
        if path.suffix.lower() == ".md":
            def mask_destination(match):
                raw = match.group(1).strip("<>")
                if re.match(r"(?i)^[a-z]:[/\\]", raw):
                    return match.group(0)
                parsed = safe_urlsplit(raw, relative, problems)
                if parsed is None:
                    return match.group(0).replace(match.group(1), "")
                scheme = parsed.scheme
                if raw.startswith(("/", "#")) or (scheme and scheme != "file"):
                    return match.group(0).replace(match.group(1), "")
                return match.group(0)

            for pattern in (LINK_RE, REFERENCE_DEFINITION_RE):
                searchable = pattern.sub(mask_destination, searchable)
        searchable = REMOTE_RE.sub("", searchable)
        parsed_uris = (safe_urlsplit(raw, relative, problems) for raw in LOCAL_FILE_URI_RE.findall(searchable))
        local_uri = any(parsed is not None and LOCAL_FILE_PATH_RE.match(unquote(parsed.path)) for parsed in parsed_uris)
        searchable = URI_RE.sub("", searchable)
        if LOCAL_PATH_RE.search(searchable) or local_uri:
            problems.append(issue("LOCAL_PATH", relative, "workstation path"))
        source_file = relative.startswith("scripts/") or os.access(path, os.X_OK) or content.startswith("#!")
        scan = content
        if source_file and path.suffix.lower() == ".md":
            scan = REFERENCE_DEFINITION_RE.sub("", LINK_RE.sub("", markdown_without_code(content)))
        if source_file:
            for number, line in enumerate(scan.splitlines(), 1):
                if has_bare_script_path(line):
                    problems.append(issue("FRAGILE_SCRIPT_PATH", relative, f"line {number} {SCRIPT_ROOT_HINT}"))
        if path.suffix.lower() != ".md":
            continue
        validate_markdown_script_paths(content, relative, problems)
        markdown = markdown_without_code(content)
        complex_link = re.compile(r"!?\[[^]\n]*\]\([^\n)]*\([^\n]*\)[^\n]*\)")
        unsupported_markdown = bool(re.search(r"(?m)^ {0,3}\[[^]\n]+\]:\s*$", markdown) or complex_link.search(markdown))
        if unsupported_markdown:
            problems.append(issue("OFFICIAL_VALIDATOR_REQUIRED", relative, "complex Markdown link shape needs an official validator", "warning"))
        canonical_markdown = complex_link.sub("", markdown)
        for pattern in (LINK_RE, REFERENCE_DEFINITION_RE):
            for match in pattern.finditer(canonical_markdown):
                validate_destination(match.group(1), relative, path.parent)
        definitions = {match.group(0).lstrip().split("]:", 1)[0][1:].casefold() for match in REFERENCE_DEFINITION_RE.finditer(canonical_markdown)}
        for match in re.finditer(r"(?<!!)\[([^]\n]+)\]\[([^]\n]+)\]", canonical_markdown):
            if match.group(2).casefold() not in definitions:
                problems.append(issue("OFFICIAL_VALIDATOR_REQUIRED", relative, "undefined reference label needs an official validator", "warning"))
        residual = LINK_RE.sub("", REFERENCE_DEFINITION_RE.sub("", canonical_markdown))
        residual = re.sub(r"(?<!!)\[[^]\n]+\]\[[^]\n]+\]", "", residual)
        if not unsupported_markdown and ("](" in residual or "][" in residual):
            problems.append(issue("OFFICIAL_VALIDATOR_REQUIRED", relative, "nested Markdown link shape needs an official validator", "warning"))


def validate_sidecar(root: Path, name: str, creation_mode: bool, problems: list[dict[str, str]]) -> None:
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
    try:
        lines = sidecar.read_bytes().decode().splitlines()
    except UnicodeDecodeError:
        return
    for line in lines:
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
                continue
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
        else:
            if (target is values or key == "value") and not target[key].strip():
                fail("OPENAI_SHAPE", f"{key} must be nonempty")
    if not sections:
        fail("OPENAI_SHAPE", "no recognized semantic section")
    if "interface" in sections and not values:
        fail("OPENAI_SHAPE", "interface needs a supported field")
    if "policy" in sections and not policy_seen:
        fail("OPENAI_SHAPE", "policy needs allow_implicit_invocation")
    if "dependencies" in sections and not tools:
        fail("OPENAI_SHAPE", "dependencies needs a nonempty tools sequence")
    display = values.get("display_name", "")
    if len(display) > 64:
        fail("OPENAI_DISPLAY_NAME", "display_name length must be at most 64")
    short = values.get("short_description", "")
    if short and not 25 <= len(short) <= 64:
        fail("TOOLBOXMD_SHORT_DESCRIPTION", "ToolboxMD policy requires short_description length 25-64")
    if creation_mode and not all(values.get(key, "").strip() for key in ("display_name", "short_description")):
        fail("TOOLBOXMD_GENERATED_SIDECAR", "creation needs nonempty display_name and short_description")
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
        target = posixpath.normpath(value)
        exact = exact_path(root, target)
        if exact is None:
            continue
        if value and (value.startswith("/") or not target.startswith("assets/") or not exact or not (root / target).is_file()):
            fail("OPENAI_ICON", f"invalid {key}")
    if any(tool.get("type") != "mcp" or not tool.get("value") for tool in tools):
        fail("OPENAI_DEPENDENCY", "each tool needs type mcp and value")


def validate_scripts(
    root: Path, declared: list[str], problems: list[dict[str, str]]
) -> list[str]:
    accepted: set[str] = set()
    seen: set[str] = set()
    for value in declared:
        relative, separator, digest = value.rpartition("=")
        if not separator or not relative or not re.fullmatch(r"[0-9a-f]{64}", digest):
            problems.append(issue("SCRIPT_SYNTAX_CHECK", ".", "expected <helper-path>=<lowercase-sha256>"))
            continue
        if relative in seen:
            problems.append(issue("SCRIPT_SYNTAX_CHECK", relative, "duplicate syntax-check attestation"))
            continue
        seen.add(relative)
        parsed = PurePosixPath(relative)
        if (
            parsed.is_absolute()
            or parsed.as_posix() != relative
            or not parsed.parts
            or parsed.parts[0] != "scripts"
            or len(parsed.parts) < 2
            or any(part in {".", ".."} for part in parsed.parts)
            or "\\" in relative
        ):
            problems.append(issue("SCRIPT_SYNTAX_CHECK", relative, "path must be normalized and relative below scripts/"))
            continue
        path = root.joinpath(*parsed.parts)
        if path.is_symlink() or not path.is_file() or not path.resolve().is_relative_to(root):
            problems.append(issue("SCRIPT_SYNTAX_CHECK", relative, "path must be a regular non-symlink package file"))
            continue
        if path.suffix.lower() == ".py":
            problems.append(issue("SCRIPT_SYNTAX_CHECK", relative, "Python helpers are checked through AST"))
            continue
        if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            problems.append(issue("SCRIPT_SYNTAX_CHECK_STALE", relative, "sha256 does not match current file bytes"))
            continue
        accepted.add(relative)

    scripts = root / "scripts"
    for path in sorted(scripts.rglob("*")):
        if not path.is_file() or path.is_symlink():
            continue
        relative = path.relative_to(root).as_posix()
        if path.suffix.lower() != ".py":
            try:
                path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            if relative not in accepted:
                problems.append(issue("SCRIPT_SYNTAX_UNCHECKED", relative, "non-Python helper needs its own syntax test", "warning"))
            continue
        try:
            ast.parse(path.read_bytes().decode(), filename=relative)
        except UnicodeDecodeError:
            continue
        except SyntaxError as exc:
            problems.append(issue("PYTHON_SYNTAX", relative, f"{exc.msg} at line {exc.lineno}"))
    return sorted(accepted)


def budget_problem(value: int, maximum, code: str, label: str, problems: list[dict[str, str]]) -> None:
    if maximum is not None and value > maximum:
        problems.append(issue(code, "SKILL.md" if label.startswith(("SKILL.md", "description")) else ".", f"{label}: {value} > {maximum}"))


def run_official_validator(root: Path, hermes: bool, problems: list[dict[str, str]]) -> dict[str, object]:
    coverage: dict[str, object] = {
        "attempted": False,
        "status": "skipped_extension" if hermes else "not_available",
        "exitCode": None,
        "externalBehaviorAttested": False,
    }
    if hermes:
        return coverage
    command = shutil.which("skills-ref")
    if not command:
        return coverage
    coverage["attempted"] = True
    try:
        completed = subprocess.run(
            [command, "validate", str(root)],
            capture_output=True,
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

    def fail(code: str, message: str) -> None:
        problems.append(issue(code, "SKILL.md", message))

    unknown = sorted(set(metadata) - PORTABLE_FIELDS)
    if unknown:
        fail("FRONTMATTER_PORTABILITY", f"non-portable: {', '.join(unknown)}")
    name = metadata.get("name")
    if not isinstance(name, str) or not name:
        fail("NAME_REQUIRED", "name is required")
        name = ""
    elif len(name) > 64 or not NAME_RE.fullmatch(name):
        fail("NAME_FORMAT", "lowercase kebab-case, max 64 chars")
    elif any(reserved in name for reserved in ("anthropic", "claude")):
        fail("NAME_RESERVED", "reserved anthropic/claude text")
    if name and name != root.name:
        fail("NAME_DIRECTORY", f"name {name!r} differs from directory {root.name!r}")
    description = metadata.get("description")
    if not isinstance(description, str) or not description.strip():
        fail("DESCRIPTION_REQUIRED", "description is required")
        description = ""
    elif "<" in description or ">" in description:
        fail("DESCRIPTION_ANGLE_BRACKET", "description must not contain < or >")
    compatibility = metadata.get("compatibility")
    if isinstance(compatibility, str) and len(compatibility) > 500:
        fail("COMPATIBILITY_BUDGET", "compatibility > 500 chars")
    if not body.strip():
        fail("BODY_EMPTY", "empty body")

    validate_links_and_paths(root, problems)
    validate_sidecar(root, name, args.creation_mode, problems)
    syntax_checks = validate_scripts(root, args.script_syntax_checked, problems)
    official = run_official_validator(root, args.allow_hermes_metadata, problems)

    skill_bytes = len(text.encode("utf-8"))
    skill_lines = len(text.splitlines())
    package_bytes = sum(int(record["bytes"]) for record in files)
    reference_files = sum(str(record["path"]).startswith("references/") for record in files)
    eval_files = sum(str(record["path"]).startswith("evals/") for record in files)
    script_files = sum(str(record["path"]).startswith("scripts/") for record in files)
    metric_rows = (
        ("descriptionCharacters", len(description), min(args.max_description_chars, PORTABLE_DESCRIPTION_MAX), "DESCRIPTION_BUDGET", "description characters"),
        ("skillMdLines", skill_lines, args.max_skill_lines, "SKILL_LINES_BUDGET", "SKILL.md lines"),
        ("skillMdBytes", skill_bytes, args.max_skill_bytes, "SKILL_BYTES_BUDGET", "SKILL.md bytes"),
        ("fileCount", len(files), args.max_files, "FILE_COUNT_BUDGET", "package files"),
        ("packageBytes", package_bytes, args.max_package_bytes, "PACKAGE_BYTES_BUDGET", "package bytes"),
        ("referenceFileCount", reference_files, args.max_reference_files, "REFERENCE_COUNT_BUDGET", "reference files"),
        ("evalFileCount", eval_files, args.max_eval_files, "EVAL_COUNT_BUDGET", "eval files"),
        ("scriptFileCount", script_files, args.max_script_files, "SCRIPT_COUNT_BUDGET", "script files"),
    )
    metrics = {key: value for key, value, *_ in metric_rows}
    for _, value, maximum, code, label in metric_rows:
        budget_problem(value, maximum, code, label, problems)

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
            "canonicalSubset": "toolboxmd-portable-core-v2",
            "enabledExtensions": ["hermes-metadata"] if args.allow_hermes_metadata else [],
            "creationMode": args.creation_mode,
            "markdown": "inline links and one-line reference definitions",
            "scriptPaths": {
                "markdown": "closed fences, single-line inline, and other code; no shell parse",
                "sources": "UTF-8 helpers, executables, and shebang files",
                "shellParsed": False,
            },
            "scriptSyntax": "Python .py AST; other helpers need exact-digest attestation",
            "scriptSyntaxChecks": {
                "acceptedPaths": syntax_checks,
                "executionVerifiedByToolboxMD": False,
            },
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
        description="Read-only canonical ToolboxMD package checker.",
        epilog="Exit: 0 valid, 1 invalid, 2 inspection error.",
    )
    result.add_argument("skill_root", nargs="?", default=".", help="skill root")
    result.add_argument("--json", action="store_true", help="JSON")
    result.add_argument("--warnings-as-errors", action="store_true", help="fail warnings")
    result.add_argument("--creation-mode", action="store_true", help="require generated UI pair")
    result.add_argument("--script-syntax-checked", action="append", default=[], metavar="PATH=SHA256",
                        help="attest checked non-Python helper bytes")
    result.add_argument("--allow-hermes-metadata", action="store_true", help="allow canonical Hermes config")
    result.add_argument("--max-description-chars", type=int, default=PORTABLE_DESCRIPTION_MAX,
                        help="tighten portable 1024-character ceiling")
    limits = (("skill-lines", 499), ("skill-bytes", None), ("files", None),
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
        print(f"COVERAGE: canonical={coverage['canonicalSubset']} extensions={extensions} creation_mode={json.dumps(coverage['creationMode'])} script_paths=closed-surfaces shell_parsed=false script_syntax=python-ast+exact-digest-attestation official_skills_ref={official['status']} official_external_attested=false")
        checks = coverage["scriptSyntaxChecks"]
        print(f"SCRIPT_SYNTAX_CHECKS: accepted_paths={json.dumps(checks['acceptedPaths'])} execution_verified_by_toolboxmd=false")
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
