#!/usr/bin/env python3
"""Run one frozen Creator treatment for an initial or repair phase."""

from __future__ import annotations

import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import http.client
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import threading
import time
import uuid


MODEL = "gpt-5.6-sol"
REASONING_EFFORT = "medium"
WALL_TIME_LIMIT_SECONDS = 900
EXCLUDED_OUTPUT_DIRS = {".home", ".tmp", ".pycache"}
NETWORK_PROBE_BODY = b"toolboxmd-live-loopback-control\n"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def tree_manifest(root: Path) -> dict:
    files = []
    symlinks = []
    for path in sorted(root.rglob("*"), key=lambda item: item.relative_to(root).as_posix().encode()):
        relative = path.relative_to(root).as_posix()
        if path.is_symlink():
            symlinks.append({"path": relative, "target": os.readlink(path)})
        elif path.is_file():
            files.append(
                {
                    "path": relative,
                    "bytes": path.stat().st_size,
                    "mode": oct(path.stat().st_mode & 0o777),
                    "sha256": sha256(path),
                }
            )
    aggregate_lines = "".join(f"{entry['sha256']}  {entry['path']}\n" for entry in files)
    return {
        "algorithm": "SHA-256 of lines '<file-sha256>  <relative-path>\\n' sorted by path",
        "aggregateSha256": hashlib.sha256(aggregate_lines.encode()).hexdigest(),
        "bytes": sum(entry["bytes"] for entry in files),
        "fileCount": len(files),
        "files": files,
        "symlinks": symlinks,
    }


def toml_string(value: str) -> str:
    return json.dumps(value)


def inline_table(entries: dict[str, str]) -> str:
    return "{" + ",".join(f"{toml_string(key)}={toml_string(value)}" for key, value in entries.items()) + "}"


def start_network_probe() -> tuple[ThreadingHTTPServer, threading.Thread, str, dict]:
    token = uuid.uuid4().hex
    probe_path = f"/{token}"

    class ProbeHandler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            if self.path != probe_path:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header("Content-Length", str(len(NETWORK_PROBE_BODY)))
            self.end_headers()
            self.wfile.write(NETWORK_PROBE_BODY)

        def log_message(self, _format: str, *_args: object) -> None:
            return

    server = ThreadingHTTPServer(("127.0.0.1", 0), ProbeHandler)
    server.daemon_threads = True
    thread = threading.Thread(target=server.serve_forever, name="benchmark-network-probe", daemon=True)
    thread.start()
    connection = http.client.HTTPConnection("127.0.0.1", server.server_port, timeout=2)
    try:
        connection.request("GET", probe_path)
        response = connection.getresponse()
        body = response.read()
    except OSError as exc:
        stop_network_probe(server, thread)
        raise SystemExit(f"unsandboxed loopback network control failed: {exc}") from exc
    finally:
        connection.close()
    if response.status != 200 or body != NETWORK_PROBE_BODY:
        stop_network_probe(server, thread)
        raise SystemExit("unsandboxed loopback network control returned unexpected content")
    url = f"http://127.0.0.1:{server.server_port}{probe_path}"
    control = {
        "kind": "live-loopback-http",
        "succeeded": True,
        "httpStatus": response.status,
        "bodySha256": hashlib.sha256(body).hexdigest(),
        "url": url,
    }
    return server, thread, url, control


def stop_network_probe(server: ThreadingHTTPServer, thread: threading.Thread) -> None:
    server.shutdown()
    server.server_close()
    thread.join(timeout=2)


def common_config(
    sandbox: Path,
    skill_path: Path,
    python_runtime_root: Path,
    network_probe_url: str,
) -> list[str]:
    denied_read_probe = Path(__file__).resolve().parents[4] / "README.md"
    filesystem = inline_table(
        {
            ":minimal": "read",
            str(python_runtime_root): "read",
            str(sandbox): "read",
            str(sandbox / "home"): "deny",
            str(skill_path.parent): "read",
            str(sandbox / "output"): "write",
        }
    )
    shell_environment = inline_table(
        {
            "PATH": f"{sandbox / 'runtime/bin'}:/usr/bin:/bin:/usr/sbin:/sbin",
            "HOME": str(sandbox / "output/.home"),
            "TMPDIR": str(sandbox / "output/.tmp"),
            "PYTHONDONTWRITEBYTECODE": "1",
            "PYTHONPYCACHEPREFIX": str(sandbox / "output/.pycache"),
            "LANG": "C",
            "LC_ALL": "C",
            "TERM": "dumb",
            "NO_COLOR": "1",
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": "/dev/null",
            "BENCHMARK_DENIED_READ": str(denied_read_probe),
            "BENCHMARK_NETWORK_CONTROL_SUCCEEDED": "1",
            "BENCHMARK_NETWORK_PROBE_URL": network_probe_url,
        }
    )
    skill_config = f"[{{path={toml_string(str(skill_path))},enabled=true}}]"
    values = [
        ("default_permissions", toml_string("benchmark")),
        ("permissions.benchmark.filesystem", filesystem),
        ("permissions.benchmark.network.enabled", "false"),
        ("approval_policy", toml_string("never")),
        ("allow_login_shell", "false"),
        ("shell_environment_policy.inherit", toml_string("none")),
        ("shell_environment_policy.set", shell_environment),
        ("model_reasoning_effort", toml_string(REASONING_EFFORT)),
        ("project_doc_max_bytes", "0"),
        ("skills.config", skill_config),
        ("skills.bundled.enabled", "false"),
        ("skills.include_instructions", "true"),
        ("web_search", toml_string("disabled")),
        ("mcp_servers", "{}"),
        ("plugins", "{}"),
        ("apps._default.enabled", "false"),
    ]
    disabled_features = (
        "apps",
        "auth_elicitation",
        "browser_use",
        "browser_use_external",
        "browser_use_full_cdp_access",
        "chronicle",
        "computer_use",
        "goals",
        "hooks",
        "image_generation",
        "in_app_browser",
        "memories",
        "multi_agent",
        "multi_agent_v2",
        "plugins",
        "recommended_plugins",
        "remote_plugin",
        "shell_snapshot",
        "skill_mcp_dependency_install",
        "skill_search",
        "tool_suggest",
        "view_image",
        "web_search_cached",
        "web_search_request",
        "workspace_dependencies",
    )
    values.extend((f"features.{feature}", "false") for feature in disabled_features)
    args = []
    for key, value in values:
        args.extend(["--config", f"{key}={value}"])
    return args


def sanitized_process_environment(home: Path, codex_bin: Path) -> dict[str, str]:
    return {
        "HOME": str(home),
        "CODEX_HOME": str(home / ".codex"),
        "PATH": f"{codex_bin.parent}:/usr/bin:/bin:/usr/sbin:/sbin",
        "TMPDIR": str(home / "tmp"),
        "LANG": "C",
        "LC_ALL": "C",
        "TERM": "dumb",
        "NO_COLOR": "1",
        "CODEX_CI": "1",
    }


def run_process(
    argv: list[str],
    *,
    cwd: Path,
    env: dict[str, str],
    stdout_path: Path,
    stderr_path: Path,
    timeout: int | None = None,
    stdin_path: Path | None = None,
) -> tuple[int, bool, float]:
    started = time.monotonic()
    with stdout_path.open("wb") as stdout, stderr_path.open("wb") as stderr:
        stdin_handle = stdin_path.open("rb") if stdin_path else subprocess.DEVNULL
        try:
            process = subprocess.Popen(
                argv,
                cwd=cwd,
                env=env,
                stdin=stdin_handle,
                stdout=stdout,
                stderr=stderr,
                start_new_session=True,
            )
            timed_out = False
            try:
                exit_status = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                timed_out = True
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    exit_status = process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    exit_status = process.wait(timeout=5)
        finally:
            if stdin_path and stdin_handle is not subprocess.DEVNULL:
                stdin_handle.close()
    return exit_status, timed_out, time.monotonic() - started


def parse_usage(events_path: Path) -> dict[str, int | None]:
    usage = None
    if events_path.exists():
        for line in events_path.read_text(encoding="utf-8", errors="replace").splitlines():
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            if event.get("type") == "turn.completed" and isinstance(event.get("usage"), dict):
                usage = event["usage"]
    if usage is None:
        return {
            "input_tokens": None,
            "cached_input_tokens": None,
            "output_tokens": None,
            "reasoning_output_tokens": None,
        }
    return {
        key: usage.get(key)
        for key in (
            "input_tokens",
            "cached_input_tokens",
            "output_tokens",
            "reasoning_output_tokens",
        )
    }


def snapshot_output(source: Path, destination: Path) -> dict:
    destination.mkdir(parents=True)
    omitted_symlinks = []
    for current, dirnames, filenames in os.walk(source, followlinks=False):
        current_path = Path(current)
        relative_dir = current_path.relative_to(source)
        dirnames[:] = [name for name in dirnames if name not in EXCLUDED_OUTPUT_DIRS]
        for dirname in list(dirnames):
            path = current_path / dirname
            if path.is_symlink():
                omitted_symlinks.append(
                    {"path": (relative_dir / dirname).as_posix(), "target": os.readlink(path)}
                )
                dirnames.remove(dirname)
        target_dir = destination / relative_dir
        target_dir.mkdir(parents=True, exist_ok=True)
        for filename in filenames:
            source_path = current_path / filename
            relative = relative_dir / filename
            if source_path.is_symlink():
                omitted_symlinks.append({"path": relative.as_posix(), "target": os.readlink(source_path)})
                continue
            if source_path.is_file():
                shutil.copy2(source_path, destination / relative)
    return {"excludedDirectories": sorted(EXCLUDED_OUTPUT_DIRS), "omittedSymlinks": omitted_symlinks}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--arm", required=True, choices=("R0", "R1"))
    parser.add_argument("--phase", required=True, choices=("initial", "repair-1", "repair-2"))
    parser.add_argument("--treatment", required=True, type=Path)
    parser.add_argument("--brief", required=True, type=Path)
    parser.add_argument("--contract", required=True, type=Path)
    parser.add_argument("--prompt", required=True, type=Path)
    parser.add_argument("--candidate", type=Path)
    parser.add_argument("--feedback", type=Path)
    parser.add_argument("--support-file", action="append", default=[], type=Path)
    parser.add_argument("--result-dir", required=True, type=Path)
    parser.add_argument("--codex-bin", required=True, type=Path)
    parser.add_argument("--auth-file", required=True, type=Path)
    parser.add_argument("--python-bin", required=True, type=Path)
    parser.add_argument("--preflight-only", action="store_true")
    args = parser.parse_args()

    harness_dir = Path(__file__).resolve().parent
    prompt = args.prompt.resolve()
    base_brief = args.brief.resolve()
    contract = args.contract.resolve()
    treatment = args.treatment.resolve()
    candidate = args.candidate.resolve() if args.candidate else None
    feedback = args.feedback.resolve() if args.feedback else None
    support_files = [path.resolve() for path in args.support_file]
    result_dir = args.result_dir.resolve()
    codex_bin = args.codex_bin.expanduser().absolute()
    auth_file = args.auth_file.resolve()
    python_bin = args.python_bin.expanduser().resolve()
    python_runtime_root = next(
        (parent for parent in python_bin.parents if parent.parent.name.startswith("python@")),
        None,
    )
    if python_runtime_root is None:
        raise SystemExit(f"cannot derive frozen Homebrew Python runtime root from: {python_bin}")

    if args.phase == "initial" and (candidate is not None or feedback is not None):
        raise SystemExit("initial phase must not receive --candidate or --feedback")
    if args.phase != "initial" and (candidate is None or feedback is None):
        raise SystemExit("repair phases require --candidate and --feedback")

    for required in (
        prompt,
        base_brief,
        contract,
        treatment / "SKILL.md",
        codex_bin,
        auth_file,
        python_bin,
        *support_files,
    ):
        if not required.exists():
            raise SystemExit(f"missing required input: {required}")
    for required in (candidate, feedback):
        if required is not None and not required.exists():
            raise SystemExit(f"missing required input: {required}")
    if result_dir.exists():
        raise SystemExit(f"result directory already exists: {result_dir}")

    opaque_id = str(uuid.uuid4())
    run_parent = Path("/private/tmp") / f"creator-refinement-{opaque_id}"
    sandbox = run_parent / "sandbox"
    home = sandbox / "home"
    codex_home = home / ".codex"
    skill_dir = codex_home / "skills/creator-under-test"
    input_dir = sandbox / "input"
    isolated_harness = sandbox / "harness"
    output_dir = sandbox / "output"
    evidence_dir = run_parent / "evidence"
    runtime_bin = sandbox / "runtime/bin"
    for directory in (input_dir, isolated_harness, output_dir, evidence_dir, home / "tmp", runtime_bin):
        directory.mkdir(parents=True, exist_ok=False)
    (runtime_bin / "python3").symlink_to(python_bin)
    (runtime_bin / "python").symlink_to(python_bin)
    shutil.copy2(base_brief, input_dir / "base-brief.md")
    shutil.copy2(contract, input_dir / "contract.json")
    if feedback is not None:
        shutil.copy2(feedback, input_dir / "feedback.json")
    shutil.copy2(harness_dir / "isolation_preflight.py", isolated_harness / "isolation_preflight.py")
    shutil.copy2(harness_dir / "final-message.schema.json", isolated_harness / "final-message.schema.json")
    for support_file in support_files:
        destination = isolated_harness / support_file.name
        if destination.exists():
            raise SystemExit(f"duplicate support filename: {support_file.name}")
        shutil.copy2(support_file, destination)
    shutil.copytree(treatment, skill_dir, symlinks=True)
    if candidate is not None:
        shutil.copytree(candidate, output_dir / "skills" / candidate.name, symlinks=True)
    codex_home.mkdir(parents=True, exist_ok=True)
    (codex_home / "auth.json").symlink_to(auth_file)

    network_server, network_thread, network_probe_url, network_probe_control = start_network_probe()
    environment = sanitized_process_environment(home, codex_bin)
    config = common_config(
        sandbox,
        skill_dir / "SKILL.md",
        python_runtime_root,
        network_probe_url,
    )

    version = subprocess.run(
        [str(codex_bin), "--version"],
        env=environment,
        text=True,
        capture_output=True,
        check=True,
    ).stdout.strip()

    debug_argv = [
        str(codex_bin),
        "debug",
        "prompt-input",
        *config,
        prompt.read_text(encoding="utf-8"),
    ]
    debug_status, debug_timed_out, debug_duration = run_process(
        debug_argv,
        cwd=sandbox,
        env=environment,
        stdout_path=evidence_dir / "model-visible-prompt.json",
        stderr_path=evidence_dir / "model-visible-prompt.stderr.txt",
        timeout=60,
    )

    sandbox_argv = [
        str(codex_bin),
        "sandbox",
        "--log-denials",
        "--permission-profile",
        "benchmark",
        "--cd",
        str(sandbox),
        *config,
        str(runtime_bin / "python3"),
        "harness/isolation_preflight.py",
        "control",
    ]
    preflight_status, preflight_timed_out, preflight_duration = run_process(
        sandbox_argv,
        cwd=sandbox,
        env=environment,
        stdout_path=evidence_dir / "control-preflight.stdout.txt",
        stderr_path=evidence_dir / "control-preflight.stderr.txt",
        timeout=30,
    )
    control_report = output_dir / "isolation-preflight-control.json"
    control_passed = False
    if control_report.exists():
        try:
            control_passed = bool(json.loads(control_report.read_text(encoding="utf-8"))["passed"])
        except (json.JSONDecodeError, KeyError, TypeError):
            control_passed = False

    authoring_started = None
    authoring_status = None
    authoring_timed_out = False
    authoring_duration = 0.0
    if (
        not args.preflight_only
        and debug_status == 0
        and not debug_timed_out
        and preflight_status == 0
        and control_passed
    ):
        authoring_argv = [
            str(codex_bin),
            "exec",
            "--ephemeral",
            "--ignore-user-config",
            "--ignore-rules",
            "--strict-config",
            "--skip-git-repo-check",
            "--model",
            MODEL,
            *config,
            "--output-schema",
            str(isolated_harness / "final-message.schema.json"),
            "--json",
            "--color",
            "never",
            "--output-last-message",
            str(evidence_dir / "final-message.json"),
            "--cd",
            str(sandbox),
            "-",
        ]
        authoring_started = time.time()
        authoring_status, authoring_timed_out, authoring_duration = run_process(
            authoring_argv,
            cwd=sandbox,
            env=environment,
            stdout_path=evidence_dir / "events.jsonl",
            stderr_path=evidence_dir / "stderr.txt",
            timeout=WALL_TIME_LIMIT_SECONDS,
            stdin_path=prompt,
        )

    usage = parse_usage(evidence_dir / "events.jsonl")
    token_usage_recorded = (
        isinstance(usage["input_tokens"], int)
        and isinstance(usage["output_tokens"], int)
    )
    model_report = output_dir / "isolation-preflight-model.json"
    model_preflight_passed = False
    if model_report.exists():
        try:
            model_preflight_passed = bool(json.loads(model_report.read_text(encoding="utf-8"))["passed"])
        except (json.JSONDecodeError, KeyError, TypeError):
            model_preflight_passed = False

    result_dir.mkdir(parents=True)
    shutil.copytree(evidence_dir, result_dir / "evidence")
    snapshot_notes = snapshot_output(output_dir, result_dir / "output-snapshot")
    output_manifest = tree_manifest(output_dir)
    (result_dir / "output-manifest.json").write_text(
        json.dumps({**output_manifest, **snapshot_notes}, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    metadata = {
        "schemaVersion": 1,
        "arm": args.arm,
        "phase": args.phase,
        "opaqueRunId": opaque_id,
        "actualCommandCwd": str(sandbox),
        "codexVersion": version,
        "model": MODEL,
        "modelReasoningEffort": REASONING_EFFORT,
        "freshEphemeralContext": True,
        "preflightOnly": args.preflight_only,
        "ignoreUserConfig": True,
        "ignoreRules": True,
        "projectDocMaxBytes": 0,
        "realExternalCalls": 0,
        "limits": {
            "wallTimeSeconds": WALL_TIME_LIMIT_SECONDS,
            "tokenEligibilityCap": None,
            "tokenUsageRequired": True,
        },
        "inputs": {
            "treatment": tree_manifest(treatment),
            "copiedTreatment": tree_manifest(skill_dir),
            "baseBrief": {"bytes": base_brief.stat().st_size, "sha256": sha256(base_brief)},
            "contract": {"bytes": contract.stat().st_size, "sha256": sha256(contract)},
            "prompt": {"bytes": prompt.stat().st_size, "sha256": sha256(prompt)},
            "candidate": tree_manifest(candidate) if candidate is not None else None,
            "feedback": (
                {"bytes": feedback.stat().st_size, "sha256": sha256(feedback)}
                if feedback is not None
                else None
            ),
            "supportFiles": [
                {"name": path.name, "bytes": path.stat().st_size, "sha256": sha256(path)}
                for path in support_files
            ],
        },
        "processEnvironmentKeys": sorted(environment),
        "networkProbeControl": network_probe_control,
        "pythonRuntime": {
            "executable": str(python_bin),
            "root": str(python_runtime_root),
            "version": subprocess.run(
                [str(python_bin), "--version"], text=True, capture_output=True, check=True
            ).stdout.strip(),
        },
        "shellEnvironmentInherit": "none",
        "filesystemProfile": {
            "default": "deny",
            "minimalRuntimeRead": True,
            "pythonRuntimeRead": str(python_runtime_root),
            "sandboxRootRead": str(sandbox),
            "homeDenied": str(home),
            "treatmentRead": str(skill_dir),
            "outputWrite": str(output_dir),
            "networkEnabled": False,
        },
        "debugPromptInput": {
            "exitStatus": debug_status,
            "timedOut": debug_timed_out,
            "durationSeconds": round(debug_duration, 3),
        },
        "controlPreflight": {
            "exitStatus": preflight_status,
            "timedOut": preflight_timed_out,
            "durationSeconds": round(preflight_duration, 3),
            "passed": control_passed,
        },
        "authoring": {
            "startedEpoch": authoring_started,
            "exitStatus": authoring_status,
            "timedOut": authoring_timed_out,
            "durationSeconds": round(authoring_duration, 3),
            "usage": usage,
            "tokenUsageRecorded": token_usage_recorded,
            "modelPreflightPassed": model_preflight_passed,
        },
        "isolationEligible": (
            not args.preflight_only
            and debug_status == 0
            and not debug_timed_out
            and preflight_status == 0
            and control_passed
            and authoring_status == 0
            and not authoring_timed_out
            and model_preflight_passed
            and token_usage_recorded
        ),
        "preflightEligible": (
            debug_status == 0
            and not debug_timed_out
            and preflight_status == 0
            and control_passed
        ),
    }
    (result_dir / "run-metadata.json").write_text(
        json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )

    stop_network_probe(network_server, network_thread)
    print(
        json.dumps(
            {
                "arm": args.arm,
                "phase": args.phase,
                "resultDir": str(result_dir),
                "isolationEligible": metadata["isolationEligible"],
                "authoringExitStatus": authoring_status,
                "durationSeconds": round(authoring_duration, 3),
                "usage": usage,
            },
            sort_keys=True,
        )
    )
    if args.preflight_only:
        return 0 if metadata["preflightEligible"] else 1
    return 0 if metadata["isolationEligible"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
