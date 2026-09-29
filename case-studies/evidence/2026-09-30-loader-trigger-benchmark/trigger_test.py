#!/usr/bin/env python3
"""Trigger benchmark for the building-agentskills loader Skill (Issue #17).

Evidence only, not a release gate. Adapted from the AgentsMD harness
(toolboxmd/agentsmd docs/work/164-trigger-audit/trigger_test.py at 4a8bd44),
following /docs/06-testing/trigger-benchmarks.

Each run starts one host CLI headless in a fresh throwaway git repository with
a temporary HOME. The arm's copy of this repository (`git archive <ref>`) sits in
that HOME. In a `loader` arm the copy is installed the way each host installs a
local plugin or Skill; in the `control` arm the copy is present and readable
but not installed. Nothing is installed into the live host configuration.

  claude    --plugin-dir <copy>, acceptEdits, Bash allowed inside Claude Code's
            sandbox (writes: the repository and the --add-dir directories;
            reads of the real home and the keychain link denied)
  codex     CODEX_HOME=HOME/codex, a local marketplace holding the copy,
            `codex plugin add`; -s workspace-write
  grok      GROK_HOME=HOME/grok, `grok plugin install <copy> --trust`;
            --always-approve inside --sandbox workspace
  opencode  OPENCODE_CONFIG_DIR=HOME/opencode with `skills.paths` set to the
            copy's skills/ directory; external directories denied except the copy

Logins are linked, never copied. After every run the guarded checkouts must show
the same `git status --porcelain --ignored --untracked-files=all` and HEAD, and
the live host configuration the same content, or the batch aborts. Temporary
directories and login links are removed in a `finally`.

A run's moment is its first file edit (a run without one gets `read-noedit` or
`skip-noedit`). A read counts only when its tool result succeeded (Claude Code
permission denials and error results for non-shell tools, OpenCode `error`
parts). Records keep the ordered tool calls up to the moment, with paths
anonymized, and no prompt text, file contents or raw stream.

  python3 trigger_test.py --self-check --host claude
  python3 trigger_test.py --host claude --model claude-opus-5-5 --effort medium \\
      --arms loader=HEAD,control=HEAD --plan claude-code --record /tmp/records.jsonl
  python3 trigger_test.py --summary records.jsonl > summary.md
  python3 trigger_test.py --scorer-test
"""
import argparse
import concurrent.futures
import glob
import hashlib
import json
import os
import pathlib
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time

HERE = pathlib.Path(__file__).resolve().parent
# The checkout every arm is archived from; BAS_REPO lets a copy of this script outside it run.
REPO = pathlib.Path(os.environ.get("BAS_REPO", HERE.parents[2])).resolve()
REAL_HOME = pathlib.Path.home()
# Checkouts a run must not touch: this checkout, the main building-agentskills
# checkout, and the live AgentsMD install.
GUARDED = sorted({REPO, REAL_HOME / "dev/toolboxmd/building-agentskills", REAL_HOME / "dev/toolboxmd/agentsmd"})
CLAUDE_JSON = REAL_HOME / ".claude.json"
KEYCHAINS = REAL_HOME / "Library/Keychains"
LOGIN = {
    "codex": REAL_HOME / ".codex/auth.json",
    "grok": REAL_HOME / ".grok/auth.json",
    "opencode": REAL_HOME / ".local/share/opencode/auth.json",
}
LIVE_CONFIG = [
    REAL_HOME / ".claude/settings.json", REAL_HOME / ".claude/CLAUDE.md", REAL_HOME / ".claude/skills",
    REAL_HOME / ".codex/config.toml", REAL_HOME / ".codex/AGENTS.md",
    REAL_HOME / ".grok/config.toml", REAL_HOME / ".grok/AGENTS.md",
    REAL_HOME / ".grok/installed-plugins/registry.json",
    REAL_HOME / ".config/opencode/opencode.json", REAL_HOME / ".config/opencode/opencode.jsonc",
    REAL_HOME / ".config/opencode/skills", REAL_HOME / ".agents/skills",
]
SILENCE = {"opencode": 180}  # seconds without output before a run is killed
TIMEOUT = 1200
PREFIX = f"bas17-{os.getpid()}-"
SOURCES = {}  # arm -> extracted archive; arm + "-sha" -> commit

LOADER = "skills/building-agentskills/SKILL.md"
# Every page the loader routes to, keyed by a short name.
PAGES = {
    "quickstart": "docs/01-quickstart.md", "mental-model": "docs/02-mental-model.md",
    "three-questions": "docs/03-three-questions.md", "token-economics": "docs/04-token-economics.md",
    "frontmatter": "docs/05-authoring/frontmatter.md", "triggers": "docs/05-authoring/triggers.md",
    "prose-discipline": "docs/05-authoring/prose-discipline.md", "iron-laws": "docs/05-authoring/iron-laws.md",
    "line-budget": "docs/05-authoring/line-budget.md",
    "provider-neutral-runtime": "docs/05-authoring/provider-neutral-runtime.md",
    "mechanism-vs-decoration": "docs/07-mechanism-vs-decoration.md",
    "red-green-for-prose": "docs/06-testing/red-green-for-prose.md", "unit-tests": "docs/06-testing/unit-tests.md",
    "tests-that-pass-immediately": "docs/06-testing/tests-that-pass-immediately.md",
    "trigger-benchmarks": "docs/06-testing/trigger-benchmarks.md",
    "benchmark-integrity": "docs/06-testing/benchmark-integrity.md",
    "packaging-as-plugin": "docs/08-packaging-as-plugin.md", "evolution": "docs/09-evolution.md",
    "anti-patterns": "docs/10-anti-patterns.md", "claude-code": "docs/11-cross-platform/claude-code.md",
    "codex": "docs/11-cross-platform/codex.md", "gemini-cli": "docs/11-cross-platform/gemini-cli.md",
    "others": "docs/11-cross-platform/others.md", "update-mechanism": "docs/12-update-mechanism.md",
}

APP = '''def greet(name):
    """Return a greeting."""
    return "Helo, " + name


def add(a, b):
    return a + b
'''

FILES = {
    "README.md": "# Greeter\n\nA tiny greeting library with an agent skill and an MCP server.\n",
    "src/__init__.py": "",
    "src/app.py": APP,
    "tests/test_app.py": "import unittest\nfrom src.app import add\n\n\nclass AppTests(unittest.TestCase):\n"
                         "    def test_add(self):\n        self.assertEqual(add(2, 3), 5)\n",
    "skills/greet/SKILL.md": "---\nname: greet\ndescription: Greeting stuff.\n---\n\n# Greet\n\n"
                             "Call `greet(name)` from `src/app.py` and show the result to the user.\n",
    "mcp/server.py": '''from mcp.server.fastmcp import FastMCP

mcp = FastMCP("orders")


@mcp.tool()
def search_orders(query: str) -> list[dict]:
    """Search."""
    return []
''',
}

# (case, kind, prompt). Prompts never name the loader, this repository or a page.
CASES = {
    "author": ("positive", "Create a new skill in {repo}/skills/ that helps agents write release notes from the "
                           "git log. It should get used whenever someone asks for release notes."),
    "audit": ("positive", "Agents never pick the greet skill at {repo}/skills/greet/SKILL.md, even when a user "
                          "asks for a greeting. Audit the skill and fix what is wrong."),
    "tool": ("positive", "Agents skip the search_orders tool in {repo}/mcp/server.py when they should use it, and "
                         "call it for questions it cannot answer. Its description is too vague. Rewrite the tool "
                         "description so agents call it at the right time."),
    "negative": ("negative", "greet() in {repo}/src/app.py returns 'Helo' instead of 'Hello'. Fix the typo."),
}
# Per-host plans: runs per (arm, case). The control arm takes the positive prompts in turn.
PLANS = {
    "full": {"loader": {"author": 5, "audit": 5, "tool": 5, "negative": 3}, "control": {"rotate": 5}},
    "short": {"loader": {"author": 3, "audit": 3, "tool": 3, "negative": 2}},
    # Re-measure after a description change: the missed prompt and the negative.
    "remeasure": {"loader": {"tool": 5, "negative": 3}},
}

READERS = re.compile(r"\b(cat|sed|head|tail|nl|less|awk|bat|grep|rg|python3?|curl|wget)\b")
SHELL_EDIT = re.compile(r"(sed -i|\bcat\s*>|\btee\b|>\s*[\w./-]+\.(py|md|json)\b|python3? -\s*<<|apply_patch)")
READ_TOOLS = {"Read", "read_file", "read", "view"}
EDIT_TOOLS = {"Edit", "Write", "MultiEdit", "search_replace", "write_file", "edit_file", "create_file",
              "write", "edit", "multiedit", "patch", "apply_patch"}
SHELL_TOOLS = {"Bash", "bash", "run_terminal_command", "shell"}
SKILL_TOOLS = {"Skill", "skill"}
FETCH_TOOLS = {"WebFetch", "webfetch", "web_fetch", "fetch"}


# ---------------------------------------------------------------- stream parsing

def _events(stream):
    for line in stream.splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if isinstance(event, dict):
            yield event


def _path(args):
    for key in ("file_path", "target_file", "filePath", "path", "url"):
        if args.get(key):
            return str(args[key])
    return ""


def canonical(name, args):
    if name in READ_TOOLS or name in FETCH_TOOLS:
        return "Read", _path(args), "", ""
    if name in EDIT_TOOLS:
        return "Edit", _path(args), "", ""
    if name in SHELL_TOOLS:
        return "Bash", "", str(args.get("command", "")), ""
    if name in SKILL_TOOLS:
        return "Skill", "", "", str(args.get("skill") or args.get("name") or "")
    return name, _path(args), "", ""


def tool_calls(stream, host):
    """Ordered (canonical name, path, command, skill) for each tool call in a host stream."""
    seen = set()
    for event in _events(stream):
        if host == "codex":
            item = event.get("item") or {}
            if event.get("type") not in ("item.started", "item.completed") or item.get("id") in seen:
                continue
            if item.get("type") == "command_execution":
                seen.add(item.get("id"))
                yield "Bash", "", str(item.get("command", "")), ""
            elif item.get("type") == "file_change":
                seen.add(item.get("id"))
                for change in item.get("changes") or [{}]:
                    yield "Edit", str(change.get("path", "")), "", ""
            continue
        if host == "opencode":
            part = event.get("part") or {}
            if event.get("type") != "tool_use" or part.get("callID") in seen:
                continue
            seen.add(part.get("callID"))
            yield canonical(part.get("tool", ""), (part.get("state") or {}).get("input") or {})
            continue
        if event.get("type") != "assistant":
            continue
        for block in event.get("message", {}).get("content", []) or []:
            if isinstance(block, dict) and block.get("type") == "tool_use" and block.get("id") not in seen:
                seen.add(block.get("id"))
                yield canonical(block.get("name", ""), block.get("input") or {})


def failed_calls(stream, host):
    """Indexes (in tool_calls order) of calls the host refused or that failed.

    Claude Code: tool uses in the result event's `permission_denials`, and non-shell
    tool uses answered by an error (a shell error only means some part exited
    non-zero). OpenCode: parts in state `error`. Other hosts report nothing reliable."""
    if host not in ("claude", "opencode"):
        return set()
    order, failed, shell = [], set(), set()
    for event in _events(stream):
        if host == "opencode":
            part = event.get("part") or {}
            if event.get("type") == "tool_use" and part.get("callID") not in order:
                order.append(part.get("callID"))
                if (part.get("state") or {}).get("status") == "error":
                    failed.add(part.get("callID"))
            continue
        if event.get("type") == "assistant":
            for block in event.get("message", {}).get("content", []) or []:
                if isinstance(block, dict) and block.get("type") == "tool_use" and block.get("id") not in order:
                    order.append(block.get("id"))
                    if block.get("name") in SHELL_TOOLS:
                        shell.add(block.get("id"))
        elif event.get("type") == "user":
            content = event.get("message", {}).get("content", [])
            for block in content if isinstance(content, list) else []:
                if (isinstance(block, dict) and block.get("type") == "tool_result" and block.get("is_error")
                        and block.get("tool_use_id") not in shell):
                    failed.add(block.get("tool_use_id"))
        elif event.get("type") == "result":
            failed.update(d.get("tool_use_id") for d in event.get("permission_denials") or [])
    return {i for i, call_id in enumerate(order) if call_id in failed}


BRACES = re.compile(r"([^\s{}'\"]*)\{([^{}\s]*,[^{}\s]*)\}([^\s{}'\"]*)")


def expand_braces(command):
    while True:
        match = BRACES.search(command)
        if not match:
            return command
        head, body, tail = match.groups()
        command = command[:match.start()] + " ".join(head + p + tail for p in body.split(",")) + command[match.end():]


def reads_file(call, f):
    """Whether a call reads f (a repository-relative path of the loader copy).

    A shell read may reach the file through `cd <dir> && cat <name>`, so every part
    of the path must appear, not necessarily joined."""
    name, path, command, _ = call
    command = expand_braces(command)
    return ((name == "Read" and path.endswith(f))
            or (name == "Bash" and READERS.search(command) is not None
                and (f in command or all(part in command for part in f.split("/")))))


def is_edit(call):
    name, path, command, _ = call
    return (name == "Edit" and "/.claude/" not in path) or (name == "Bash" and SHELL_EDIT.search(command) is not None)


def loads_loader(call):
    name, _, _, skill = call
    return (name == "Skill" and skill.split(":")[-1] == "building-agentskills") or reads_file(call, LOADER)


def score(stream, host):
    """(first edit index, loader index, {page: first successful read index}), all None when absent."""
    failed = failed_calls(stream, host)
    first_edit, loader, reads = None, None, {p: None for p in PAGES}
    for i, call in enumerate(tool_calls(stream, host)):
        ok = i not in failed
        if loader is None and ok and loads_loader(call):
            loader = i
        for page, f in PAGES.items():
            if reads[page] is None and ok and reads_file(call, f):
                reads[page] = i
        if first_edit is None and is_edit(call):
            first_edit = i
    return first_edit, loader, reads


def before(index, moment):
    return index is not None and (moment is None or index < moment)


def verdict(kind, first_edit, loader, reads):
    """Positive: `fired` when the loader loaded and a routed page was read before the first
    edit; `loaded-only` when only the loader was; `skip` otherwise; `read-noedit` or
    `skip-noedit` without an edit. Negative: `clean` or `opened`."""
    page_read = any(before(i, first_edit) for i in reads.values())
    loaded = before(loader, first_edit)
    if kind == "negative":
        return "opened" if (loader is not None or any(i is not None for i in reads.values())) else "clean"
    if first_edit is None:
        return "read-noedit" if (loaded or page_read) else "skip-noedit"
    if loaded and page_read:
        return "fired"
    return "loaded-only" if loaded else ("page-only" if page_read else "skip")


# ---------------------------------------------------------------- confinement

class Escaped(Exception):
    pass


def live_config():
    state = {}
    for path in LIVE_CONFIG:
        if path.is_dir():
            state[str(path)] = sorted((p.name, os.readlink(p) if p.is_symlink() else "") for p in path.iterdir())
        elif path.exists():
            state[str(path)] = hashlib.sha256(path.read_bytes()).hexdigest()
    return state


def snapshot(roots=None):
    state = {}
    for root in GUARDED if roots is None else roots:
        if (root / ".git").exists():
            git = ["git", "-C", str(root)]
            state[str(root)] = (
                subprocess.run(git + ["status", "--porcelain", "--ignored", "--untracked-files=all"],
                               capture_output=True, text=True, check=True).stdout,
                subprocess.run(git + ["rev-parse", "HEAD"], capture_output=True, text=True).stdout)
    if roots is None:
        state["live-config"] = live_config()
    return state


def guard_self_check():
    root = pathlib.Path(tempfile.mkdtemp(prefix=PREFIX + "guard-"))
    try:
        subprocess.run(["git", "init", "-q"], cwd=root, check=True)
        (root / ".gitignore").write_text("ignored/\n")
        first = snapshot([root])
        (root / "ignored").mkdir()
        (root / "ignored/escape.md").write_text("x")
        if snapshot([root]) == first:
            raise RuntimeError("guard self-check failed: a new ignored file was not detected")
    finally:
        shutil.rmtree(root, ignore_errors=True)


def remove(path):
    if path is None:
        return
    for link in (path / "Library/Keychains", path / "codex/auth.json", path / "grok/auth.json",
                 path / "data/opencode/auth.json"):
        if link.is_symlink():
            link.unlink()
    shutil.rmtree(path, ignore_errors=True)


def cleanup_self_check(host):
    """Prove that a setup failure leaves no temporary repository, HOME or login link: the
    host binary is a failing stub, and HOME setup fails after the login link exists."""
    global CLAUDE_JSON
    stub = pathlib.Path(tempfile.mkdtemp(prefix=PREFIX + "stub-"))
    saved = CLAUDE_JSON, os.environ["PATH"], dict(LOGIN)
    pattern = os.path.join(tempfile.gettempdir(), PREFIX + "*")
    try:
        (stub / host).write_text("#!/bin/sh\nexit 99\n")
        (stub / host).chmod(0o755)
        os.environ["PATH"] = f"{stub}{os.pathsep}{os.environ['PATH']}"
        existing = set(glob.glob(pattern))
        CLAUDE_JSON = stub / "missing.json"
        for key in LOGIN:
            LOGIN[key] = stub / "missing-auth.json"
        try:
            run(host, "stub", "", next(a for a in SOURCES if not a.endswith("-sha")), "author", CASES["author"], 0)
        except (OSError, ValueError, subprocess.CalledProcessError):
            pass
        else:
            raise RuntimeError("cleanup self-check: setup did not fail")
        left = set(glob.glob(pattern)) - existing - {str(stub)}
        if left:
            raise RuntimeError(f"cleanup self-check: setup failure left {sorted(left)}")
    finally:
        CLAUDE_JSON, os.environ["PATH"] = saved[:2]
        LOGIN.clear()
        LOGIN.update(saved[2])
        shutil.rmtree(stub, ignore_errors=True)


def link_login(link, source):
    link.parent.mkdir(parents=True, exist_ok=True)
    link.symlink_to(source)
    if not source.is_file():
        raise FileNotFoundError(f"login source missing: {source}")


# ---------------------------------------------------------------- setup

def parse_arms(spec):
    arms = {}
    for item in spec.split(","):
        name, _, ref = item.partition("=")
        arms[name] = ref or "HEAD"
    return arms


def extract_sources(arms):
    root = pathlib.Path(tempfile.mkdtemp(prefix=PREFIX + "src-"))
    try:
        for arm, ref in arms.items():
            (root / arm).mkdir()
            archive = subprocess.run(["git", "-C", str(REPO), "archive", ref], capture_output=True, check=True).stdout
            subprocess.run(["tar", "-x", "-C", str(root / arm)], input=archive, check=True)
            SOURCES[arm] = root / arm
            SOURCES[arm + "-sha"] = subprocess.run(["git", "-C", str(REPO), "rev-parse", ref],
                                                   capture_output=True, text=True, check=True).stdout.strip()
    except BaseException:
        remove(root)
        raise
    return root


def make_repo():
    root = pathlib.Path(tempfile.mkdtemp(prefix=PREFIX + "repo-"))
    try:
        for rel, text in FILES.items():
            path = root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        subprocess.run(["git", "init", "-q"], cwd=root, check=True)
        subprocess.run(["git", "add", "-A"], cwd=root, check=True)
        subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "init"],
                       cwd=root, check=True)
    except BaseException:
        remove(root)
        raise
    return root


def claude_settings(home):
    """Every Bash command runs in Claude Code's sandbox: writes only to the repository,
    the --add-dir directories and the per-user temp directory; no reads of the real
    home or the keychain link; no unsandboxed retry. https://code.claude.com/docs/en/sandboxing"""
    return {
        "permissions": {"defaultMode": "acceptEdits"},
        "sandbox": {
            "enabled": True, "allowUnsandboxedCommands": False, "failIfUnavailable": True,
            "filesystem": {"denyRead": [str(REAL_HOME), str(home / "Library/Keychains")],
                           "allowRead": [str(home)]},
        },
    }


def setup_claude(home, plugin, env, install, repo):
    (home / ".claude").mkdir()
    (home / ".claude/settings.json").write_text(json.dumps(claude_settings(home)))
    if KEYCHAINS.is_dir():
        (home / "Library").mkdir()
        (home / "Library/Keychains").symlink_to(KEYCHAINS)
    real = json.loads(CLAUDE_JSON.read_text())
    (home / ".claude.json").write_text(json.dumps({k: real[k] for k in ("oauthAccount", "userID") if k in real}))


def setup_codex(home, plugin, env, install, repo):
    codex = home / "codex"
    env["CODEX_HOME"] = str(codex)
    link_login(codex / "auth.json", LOGIN["codex"])
    # A permission profile in place of -s workspace-write: writes to the repository and
    # the temp directory, reads everywhere except the real home.
    (codex / "config.toml").write_text(
        'default_permissions = "bench"\n\n[permissions.bench.filesystem]\n'
        f'":root" = "read"\n":project_roots" = "write"\n":tmpdir" = "write"\n{json.dumps(str(REAL_HOME))} = "none"\n')
    if not install:
        return
    market = home / "market"
    (market / ".agents/plugins").mkdir(parents=True)
    (market / "plugins").mkdir()
    (market / "plugins/building-agentskills").symlink_to(plugin)
    (market / ".agents/plugins/marketplace.json").write_text(json.dumps({"name": "local", "plugins": [{
        "name": "building-agentskills", "source": {"source": "local", "path": "./plugins/building-agentskills"},
        "policy": {"installation": "AVAILABLE", "authentication": "ON_INSTALL"}, "category": "Developer Tools"}]}))
    for cmd in (["codex", "plugin", "marketplace", "add", str(market)],
                ["codex", "plugin", "add", "building-agentskills@local"]):
        subprocess.run(cmd, env=env, cwd=home, capture_output=True, check=True, timeout=120)


def setup_grok(home, plugin, env, install, repo):
    grok = home / "grok"
    env["GROK_HOME"] = str(grok)
    link_login(grok / "auth.json", LOGIN["grok"])
    # `workspace` reads everywhere; this profile adds a kernel-level deny of everything in
    # the real home except ~/.grok. The deny also binds Grok's own process, which reads its
    # login and binary from ~/.grok, so the home itself cannot be denied whole.
    denied = sorted(str(p) for p in REAL_HOME.iterdir() if p.name != ".grok")
    (grok / "sandbox.toml").write_text(
        f'[profiles.bench]\nextends = "workspace"\ndeny = {json.dumps(denied)}\n')
    if install:
        subprocess.run(["grok", "plugin", "install", str(plugin), "--trust"], env=env, cwd=home,
                       stdin=subprocess.DEVNULL, capture_output=True, check=True, timeout=120)


def setup_opencode(home, plugin, env, install, repo):
    config = home / "opencode"
    env.update(OPENCODE_CONFIG_DIR=str(config), XDG_DATA_HOME=str(home / "data"),
               XDG_CACHE_HOME=str(home / "cache"), XDG_CONFIG_HOME=str(home / "config"))
    link_login(home / "data/opencode/auth.json", LOGIN["opencode"])
    config.mkdir()
    # The run's repository and the copy, in both spellings (/var and /private/var):
    # OpenCode treated the repository's /var spelling as an external directory.
    allowed = {f"{p}/**": "allow" for d in (plugin, repo) for p in {str(d), str(d.resolve())}}
    settings = {"$schema": "https://opencode.ai/config.json",
                "permission": {"edit": "allow", "bash": "allow", "webfetch": "deny",
                               "external_directory": {"*": "deny", **allowed}}}
    if install:
        settings["skills"] = {"paths": [str(plugin / "skills")]}
    (config / "opencode.json").write_text(json.dumps(settings))


SETUP = {"claude": setup_claude, "codex": setup_codex, "grok": setup_grok, "opencode": setup_opencode}


def make_home(host, arm, repo):
    home = pathlib.Path(tempfile.mkdtemp(prefix=PREFIX + "home-"))
    try:
        plugin = home / "building-agentskills"
        shutil.copytree(SOURCES[arm], plugin, symlinks=True)
        env = {k: v for k, v in os.environ.items()
               if not k.startswith(("CLAUDE_CODE_", "CLAUDECODE", "CODEX_", "GROK_", "OPENCODE_", "XDG_"))}
        env.pop("CLAUDE_CONFIG_DIR", None)
        env["HOME"] = str(home)
        SETUP[host](home, plugin, env, arm != "control", repo)
        return home, plugin, env
    except BaseException:
        remove(home)
        raise


def command(host, model, effort, repo, plugin, prompt, install):
    if host == "claude":
        cmd = ["claude", "-p", "--model", model, "--output-format", "stream-json", "--verbose",
               "--permission-mode", "acceptEdits", "--add-dir", str(repo), "--add-dir", str(plugin),
               "--allowedTools", "Bash", "--no-session-persistence", "--max-turns", "40"]
        cmd += ["--plugin-dir", str(plugin)] if install else []
        return cmd + (["--effort", effort] if effort else []) + [prompt]
    if host == "codex":
        cmd = ["codex", "exec", "--json", "-m", model, "-C", str(repo),
               "--skip-git-repo-check", "--ephemeral"]
        return cmd + (["-c", f"model_reasoning_effort={effort}"] if effort else []) + [prompt]
    if host == "grok":
        cmd = ["grok", "-p", prompt, "-m", model, "--always-approve", "--sandbox", "bench",
               "--output-format", "streaming-messages-json", "--max-turns", "40", "--cwd", str(repo)]
        return cmd + (["--reasoning-effort", effort] if effort else [])
    cmd = ["opencode", "run", "--format", "json", "-m", model, "--dir", str(repo)]
    return cmd + (["--variant", effort] if effort else []) + [prompt]


def execute(host, cmd, cwd, env):
    """Run in its own process group with a total timeout and a silence watchdog; kill the group after."""
    proc = subprocess.Popen(cmd, cwd=cwd, env=env, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                            stderr=subprocess.DEVNULL, text=True, start_new_session=True)
    lines, last = [], [time.monotonic()]

    def reader():
        for line in proc.stdout:
            lines.append(line)
            last[0] = time.monotonic()

    thread = threading.Thread(target=reader, daemon=True)
    thread.start()
    start, silence = time.monotonic(), SILENCE.get(host, TIMEOUT)
    try:
        while proc.poll() is None:
            now = time.monotonic()
            if now - start > TIMEOUT or now - last[0] > silence:
                break
            time.sleep(1)
    finally:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        proc.wait()
        thread.join(5)
        proc.stdout.close()
    return "".join(lines)


def anonymize(text, repo, plugin):
    for real, label in ((repo, "<repo>"), (plugin, "<plugin>"), (plugin.parent, "<home>"),
                        (pathlib.Path(tempfile.gettempdir()), "<tmp>"), (REAL_HOME, "~")):
        for form in sorted({str(real), str(real.resolve()), "/private" + str(real)}, key=len, reverse=True):
            text = text.replace(form, label)
    text = re.sub(r"(/private)?/var/folders/[\w.-]+/[\w.-]+", "<tmp>", text)
    # Installed plugin caches under the temporary home hold the same copy.
    text = re.sub(r"<home>/\S*?/building-agentskills/(0\.\d+\.\d+|building-agentskills-[0-9a-f]+)/", "<plugin>/",
                  text)
    return scrub(text)


def scrub(text):
    """Rules that need no run context, so they can also be applied to kept records:
    Claude Code session directories (named after the temporary path) and any other
    user's home directory a model typed."""
    text = re.sub(r"<home>/\.claude/projects/[\w.-]+/[\w-]+/", "<home>/.claude/projects/<session>/", text)
    return re.sub(r"/(?:Users)/[\w.-]+", "<user-home>", text)


def usage(stream, host):
    total = {"input": 0, "output": 0}
    for event in _events(stream):
        if host == "opencode" and event.get("type") == "step_finish":
            tokens = (event.get("part") or {}).get("tokens") or {}
            cache = tokens.get("cache") or {}
            total["input"] += tokens.get("input", 0) + cache.get("read", 0) + cache.get("write", 0)
            total["output"] += tokens.get("output", 0) + tokens.get("reasoning", 0)
        elif host == "codex" and event.get("type") == "turn.completed":
            u = event.get("usage") or {}
            total["input"] += u.get("input_tokens", 0)
            total["output"] += u.get("output_tokens", 0)
        elif host in ("claude", "grok") and isinstance(event.get("usage"), dict) and event.get("type") in (
                "result", "stream_end", "end", "done", "completed"):
            u = event["usage"]
            total = {"input": sum(u.get(k) or 0 for k in ("input_tokens", "cache_creation_input_tokens",
                                                           "cache_read_input_tokens", "prompt_tokens")),
                     "output": sum(u.get(k) or 0 for k in ("output_tokens", "completion_tokens"))}
    return total


def other_skills(stream, host):
    """Names of other Skills invoked through a Skill tool (for example a competing skill-creator)."""
    return sorted({skill for name, _, _, skill in tool_calls(stream, host)
                   if name == "Skill" and skill.split(":")[-1] != "building-agentskills"})


HOST_LABEL = {"claude": "claude-code"}


def record(stream, host, model, effort, arm, case, kind, index, repo, plugin):
    first_edit, loader, reads = score(stream, host)
    calls = []
    for i, (name, path, command_text, skill) in enumerate(tool_calls(stream, host)):
        if first_edit is not None and i > first_edit:
            break
        if path:
            calls.append([name, anonymize(path, repo, plugin)])
        elif name == "Bash":
            calls.append([name, anonymize(" ".join(command_text.split()), repo, plugin)])
        elif skill:
            calls.append([name, skill])
        else:
            calls.append([name])
    item = {"host": HOST_LABEL.get(host, host), "model": model, "effort": effort, "arm": arm,
            "source": SOURCES[arm + "-sha"][:7], "case": case, "kind": kind, "run": index,
            "first_edit": first_edit, "loader_at": loader,
            "pages_read_at": {p: i for p, i in reads.items() if i is not None},
            "verdict": verdict(kind, first_edit, loader, reads),
            "other_skills": other_skills(stream, host),
            "tool_calls": sum(1 for _ in tool_calls(stream, host)),
            "failed_calls": sorted(failed_calls(stream, host)),
            "usage": usage(stream, host), "calls": calls}
    if next(tool_calls(stream, host), None) is None:
        item["verdict"] = "no-output"  # a provider error or rate limit, not a measurement
    return item


def run(host, model, effort, arm, case, spec, index, snap=None):
    repo = home = None
    try:
        repo = make_repo()
        home, plugin, env = make_home(host, arm, repo)
        kind, prompt = spec
        prompt = prompt.format(repo=repo.resolve())
        stream = execute(host, command(host, model, effort, repo, plugin, prompt, arm != "control"), repo, env)
        if snap is not None:
            after = snapshot()
            if after != snap:
                changed = sorted(k for k in set(snap) | set(after) if snap.get(k) != after.get(k))
                raise Escaped(f"{changed} changed during {host} {arm} {case} run {index}")
        return record(stream, host, model, effort, arm, case, kind, index, repo, plugin)
    finally:
        remove(repo)
        remove(home)


def jobs_for(plan, arms):
    """Interleaved (arm, case, spec, index) jobs: run i of every cell before run i + 1.

    The plan's `loader` cases run in every arm except `control`; its `control` cases
    run in the `control` arm when that arm is given."""
    cells = []
    for arm in arms:
        cases = PLANS[plan].get("control" if arm == "control" else "loader", {})
        for case, n in cases.items():
            if case == "rotate":
                positives = [c for c, (kind, _) in CASES.items() if kind == "positive"]
                cells.append([(arm, positives[i % len(positives)], i) for i in range(n)])
            else:
                cells.append([(arm, case, i) for i in range(n)])
    jobs = []
    for i in range(max((len(c) for c in cells), default=0)):
        jobs += [c[i] for c in cells if i < len(c)]
    return [(arm, case, CASES[case], i) for arm, case, i in jobs]


# ---------------------------------------------------------------- summary

POSITIVE_MEASURES = [
    ("Loader loaded before the first edit", lambda r: before(r["loader_at"], r["first_edit"])),
    ("Loader loaded and a routed page read before the first edit (fired)", lambda r: r["verdict"] == "fired"),
    ("Triggers page read before the first edit",
     lambda r: before(r["pages_read_at"].get("triggers"), r["first_edit"])),
    ("Anti-patterns page read before the first edit",
     lambda r: before(r["pages_read_at"].get("anti-patterns"), r["first_edit"])),
    ("No edit (read-noedit or skip-noedit)", lambda r: r["first_edit"] is None),
]


def summarize(path):
    """Markdown tables per host from records; every number in the case study comes from here."""
    records = [json.loads(line) for line in open(path) if line.strip()]
    hosts = list(dict.fromkeys((r["host"], r["model"], r["effort"]) for r in records))
    for host, model, effort in hosts:
        rs = [r for r in records if (r["host"], r["model"], r["effort"]) == (host, model, effort)
              and "discarded" not in r]
        valid = [r for r in rs if r["verdict"] != "no-output"]
        print(f"\n### {host}, `{model}`" + (f", effort {effort}" if effort else ""))
        print(f"\n{len(valid)} of {len(rs)} runs valid (a run with no tool call is excluded).\n")
        cells = list(dict.fromkeys((r["arm"], r["case"]) for r in valid))
        print("| Measure | " + " | ".join(f"{a}: {c}" for a, c in cells) + " |")
        print("| --- |" + " --- |" * len(cells))
        for label, pred in POSITIVE_MEASURES:
            row = []
            for arm, case in cells:
                group = [r for r in valid if (r["arm"], r["case"]) == (arm, case)]
                row.append("" if group[0]["kind"] == "negative" else f"{sum(map(pred, group))}/{len(group)}")
            print(f"| {label} | " + " | ".join(row) + " |")
        row = []
        for arm, case in cells:
            group = [r for r in valid if (r["arm"], r["case"]) == (arm, case)]
            clean = sum(r["verdict"] == "clean" for r in group)
            row.append(f"{clean}/{len(group)}" if group[0]["kind"] == "negative" else "")
        print("| Negative clean (loader and pages never opened) | " + " | ".join(row) + " |")
        row = []
        for arm, case in cells:
            used = [r["usage"]["input"] + r["usage"]["output"] for r in valid if (r["arm"], r["case"]) == (arm, case)]
            row.append(f"{sum(used) // len(used):,}" if used and any(used) else "n/a")
        print("| Mean tokens per run (input incl. cache, plus output) | " + " | ".join(row) + " |")
        others = sorted({s for r in valid for s in r["other_skills"]})
        if others:
            print("\nOther Skills invoked: " + ", ".join(
                f"`{s}` {sum(s in r['other_skills'] for r in valid)}" for s in others))


# ---------------------------------------------------------------- scorer self-test

def scorer_self_test():
    """Fixed streams with known answers; each rejects a plausible scorer defect."""
    def claude(*blocks, denials=(), errors=()):
        lines = []
        for i, (name, args) in enumerate(blocks):
            lines.append(json.dumps({"type": "assistant", "message": {"content": [
                {"type": "tool_use", "id": f"t{i}", "name": name, "input": args}]}}))
            if i in errors:
                lines.append(json.dumps({"type": "user", "message": {"content": [
                    {"type": "tool_result", "tool_use_id": f"t{i}", "is_error": True}]}}))
        lines.append(json.dumps({"type": "result", "permission_denials": [{"tool_use_id": f"t{i}"} for i in denials]}))
        return "\n".join(lines)

    skill = ("Skill", {"skill": "building-agentskills:building-agentskills"})
    page = ("Read", {"file_path": "/h/building-agentskills/docs/05-authoring/triggers.md"})
    edit = ("Write", {"file_path": "/r/skills/notes/SKILL.md"})
    checks = [
        # A refused read is an attempt, not a read (the AgentsMD #179 defect).
        (claude(skill, page, edit, denials=[1]), "positive", "loaded-only"),
        (claude(skill, page, edit), "positive", "fired"),
        # A read after the edit is too late.
        (claude(skill, edit, page), "positive", "loaded-only"),
        # No edit: its own verdict, not a pass (the #174 no-edit defect).
        (claude(skill, page), "positive", "read-noedit"),
        # A chained shell read that exits non-zero still read (the #181 rule).
        (claude(skill, ("Bash", {"command": "cd /h/building-agentskills/docs/05-authoring && cat triggers.md; ls x"}),
                edit, errors=[1]), "positive", "fired"),
        # A Read tool error is a failed read.
        (claude(skill, page, edit, errors=[1]), "positive", "loaded-only"),
        (claude(("Read", {"file_path": "/r/src/app.py"}), edit), "negative", "clean"),
        (claude(skill, edit), "negative", "opened"),
    ]
    for stream, kind, expected in checks:
        got = verdict(kind, *score(stream, "claude"))
        if got != expected:
            raise RuntimeError(f"scorer self-test: expected {expected}, got {got}")
    opencode = "\n".join(json.dumps({"type": "tool_use", "part": {"callID": f"c{i}", "tool": t, "state": s}}) for i, (t, s) in
                         enumerate([("skill", {"status": "completed", "input": {"name": "building-agentskills"}}),
                                    ("read", {"status": "error", "input": {"filePath": "/h/building-agentskills/docs/10-anti-patterns.md"}}),
                                    ("edit", {"status": "completed", "input": {"filePath": "/r/skills/greet/SKILL.md"}})]))
    if verdict("positive", *score(opencode, "opencode")) != "loaded-only":
        raise RuntimeError("scorer self-test: an OpenCode error part counted as a read")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", choices=sorted(SETUP), default="claude")
    parser.add_argument("--model", default="claude-opus-5-5")
    parser.add_argument("--effort", default="")
    parser.add_argument("--arms", default="loader=HEAD,control=HEAD", help="name=ref,...; `control` is not installed")
    parser.add_argument("--plan", choices=sorted(PLANS), default="full")
    parser.add_argument("--cases", help="comma-separated cases to keep (default: the whole plan)")
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--record", help="append one JSON line per run to this file (outside guarded checkouts)")
    parser.add_argument("--summary", help="print per-host tables from a records file")
    parser.add_argument("--self-check", action="store_true", help="only run the scorer, guard and cleanup self-checks")
    parser.add_argument("--scorer-test", action="store_true", help="only run the scorer self-test (no host needed)")
    args = parser.parse_args()
    if args.scorer_test:
        scorer_self_test()
        print("scorer self-test OK")
        return 0
    if args.summary:
        summarize(args.summary)
        return 0
    arms = parse_arms(args.arms)
    jobs = [j for j in jobs_for(args.plan, arms) if not args.cases or j[1] in args.cases.split(",")]
    if args.record and any(pathlib.Path(args.record).resolve().is_relative_to(g.resolve()) for g in GUARDED):
        parser.error("--record must be outside the guarded checkouts; copy the file in after the batch")
    sources = extract_sources(arms)
    try:
        scorer_self_test()
        guard_self_check()
        cleanup_self_check(args.host)
        if args.self_check:
            print(f"{args.host}: scorer, guard and cleanup self-checks OK")
            return 0
        snap = snapshot()
        with concurrent.futures.ThreadPoolExecutor(args.jobs) as pool:
            futures = [pool.submit(run, args.host, args.model, args.effort, *job, snap=snap) for job in jobs]
            try:
                for future in futures:
                    item = future.result()
                    print(f"{item['arm']}\t{item['case']}\t{item['run']}\t{item['verdict']}", flush=True)
                    if args.record:
                        with open(args.record, "a") as out:
                            out.write(json.dumps(item) + "\n")
            except Escaped as error:
                for pending in futures:
                    pending.cancel()
                print(f"ABORT: {error}", file=sys.stderr)
                return 2
    finally:
        remove(sources)
    return 0


if __name__ == "__main__":
    sys.exit(main())
