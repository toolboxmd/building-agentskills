#!/usr/bin/env python3
"""Frozen deterministic grader for one generated toolboxmd-use-grok package."""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import stat
import subprocess
import tempfile
import time


REVIEW_KEYS = {
    "verdict",
    "overengineering",
    "missing",
    "risks",
    "minimum_plan_delta",
    "user_decisions",
}
SUCCESS_SCENARIOS = ("direct", "envelope", "streaming")
FAILURE_SCENARIOS = {
    "nonzero": "nonzero-exit",
    "invalid-json": "invalid-json",
    "incomplete": "incomplete-stop-reason",
    "result-error": "incomplete-stop-reason",
    "max-turns": "max-turns",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_frontmatter(skill: Path) -> tuple[dict[str, str], str]:
    text = skill.read_text(encoding="utf-8")
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        raise ValueError("SKILL.md must start with ---")
    try:
        end = lines.index("---", 1)
    except ValueError as exc:
        raise ValueError("SKILL.md frontmatter is not closed") from exc
    values = {}
    for line in lines[1:end]:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if ":" not in line:
            raise ValueError(f"invalid frontmatter line: {line}")
        key, value = line.split(":", 1)
        if key.strip() in values:
            raise ValueError(f"duplicate frontmatter key: {key.strip()}")
        value = value.strip()
        if value.startswith('"'):
            try:
                value = json.loads(value)
            except json.JSONDecodeError as exc:
                raise ValueError(f"invalid quoted frontmatter value: {key}") from exc
        elif value.startswith("'") and value.endswith("'"):
            value = value[1:-1].replace("''", "'")
        values[key.strip()] = value
    return values, text


def json_status(stdout: str) -> dict | None:
    try:
        value = json.loads(stdout)
        return value if isinstance(value, dict) else None
    except json.JSONDecodeError:
        pass
    for line in reversed(stdout.splitlines()):
        try:
            value = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            return value
    return None


def status_matches(payload: dict | None, expected: str) -> bool:
    if not payload:
        return False
    actual = str(payload.get("status", "")).strip().lower().replace("_", "-")
    return actual == expected


def retained_text(root: Path) -> str:
    values = []
    for path in root.rglob("*"):
        if path.is_file() and not path.is_symlink() and path.stat().st_size <= 2_000_000:
            values.append(path.read_text(encoding="utf-8", errors="replace"))
    return "\n".join(values)


def process_alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


class CandidateGrader:
    def __init__(self, candidate: Path, fake_source: Path, contract: Path) -> None:
        self.candidate = candidate
        self.adapter = candidate / "scripts/consult-grok"
        self.fake_source = fake_source
        self.contract = json.loads(contract.read_text(encoding="utf-8"))
        self.checks: dict[str, dict] = {}
        self.case_results: dict[str, dict] = {}

    def check(self, name: str, passed: bool, *, critical: bool, points: int, detail: object) -> None:
        self.checks[name] = {
            "passed": bool(passed),
            "critical": critical,
            "pointsAvailable": points,
            "pointsAwarded": points if passed else 0,
            "detail": detail,
        }

    def artifact_checks(self) -> None:
        files = []
        symlinks = []
        nonregular = []
        for path in sorted(self.candidate.rglob("*")):
            relative = path.relative_to(self.candidate).as_posix()
            mode = path.lstat().st_mode
            if stat.S_ISLNK(mode):
                symlinks.append(relative)
            elif stat.S_ISREG(mode):
                files.append(relative)
            elif not stat.S_ISDIR(mode):
                nonregular.append(relative)
        expected = ["SKILL.md", "scripts/consult-grok"]
        self.check(
            "exact-two-file-shape",
            files == expected and not symlinks and not nonregular,
            critical=True,
            points=5,
            detail={"files": files, "symlinks": symlinks, "nonregular": nonregular},
        )

        frontmatter = {}
        skill_text = ""
        frontmatter_error = None
        try:
            frontmatter, skill_text = read_frontmatter(self.candidate / "SKILL.md")
        except (OSError, UnicodeError, ValueError) as exc:
            frontmatter_error = str(exc)
        description = str(frontmatter.get("description", ""))
        description_lower = description.lower()
        frontmatter_passed = (
            frontmatter_error is None
            and frontmatter.get("name") == "toolboxmd-use-grok"
            and 1 <= len(description) <= 400
            and "grok" in description_lower
            and any(word in description_lower for word in ("explicit", "ask", "request", "poprosi", "prosi"))
        )
        self.check(
            "portable-frontmatter-and-explicit-activation",
            frontmatter_passed,
            critical=True,
            points=5,
            detail={
                "frontmatter": frontmatter,
                "descriptionCharacters": len(description),
                "error": frontmatter_error,
            },
        )

        skill = self.candidate / "SKILL.md"
        total_bytes = sum(path.stat().st_size for path in self.candidate.rglob("*") if path.is_file())
        line_count = len(skill_text.splitlines()) if skill_text else None
        budgets = self.contract["productBudgets"]
        budget_passed = (
            skill.is_file()
            and line_count is not None
            and line_count <= budgets["skillMdLinesMaximum"]
            and skill.stat().st_size <= budgets["skillMdBytesMaximum"]
            and total_bytes <= budgets["packageBytesMaximum"]
            and len(files) == budgets["fileCount"]
        )
        self.check(
            "frozen-product-budgets",
            budget_passed,
            critical=True,
            points=5,
            detail={
                "skillLines": line_count,
                "skillBytes": skill.stat().st_size if skill.exists() else None,
                "packageBytes": total_bytes,
                "fileCount": len(files),
                "limits": budgets,
            },
        )

        syntax_error = None
        dangerous_calls = []
        executable = False
        try:
            source = self.adapter.read_text(encoding="utf-8")
            executable = bool(self.adapter.stat().st_mode & 0o111)
            tree = ast.parse(source, filename=str(self.adapter))
            for node in ast.walk(tree):
                if isinstance(node, ast.Call):
                    if isinstance(node.func, ast.Attribute) and node.func.attr == "system":
                        dangerous_calls.append(f"system@{node.lineno}")
                    for keyword in node.keywords:
                        if keyword.arg == "shell" and isinstance(keyword.value, ast.Constant) and keyword.value.value is True:
                            dangerous_calls.append(f"shell=True@{node.lineno}")
                    if isinstance(node.func, ast.Name) and node.func.id in {"eval", "exec"}:
                        dangerous_calls.append(f"{node.func.id}@{node.lineno}")
        except (OSError, UnicodeError, SyntaxError) as exc:
            syntax_error = str(exc)
        self.check(
            "executable-stdlib-python-without-shell-eval",
            syntax_error is None and executable and not dangerous_calls,
            critical=True,
            points=5,
            detail={"executable": executable, "syntaxError": syntax_error, "dangerousCalls": dangerous_calls},
        )

    def prepare_fake(self, root: Path, scenario: str) -> Path:
        bin_dir = root / "fake-bin"
        bin_dir.mkdir()
        fake = bin_dir / "grok"
        shutil.copy2(self.fake_source, fake)
        fake.chmod(0o755)
        (bin_dir / "scenario.txt").write_text(scenario + "\n", encoding="utf-8")
        return fake

    def run_case(
        self,
        scenario: str,
        *,
        mode: str = "explicit",
        timeout: str = "3",
        max_turns: str = "3",
        prompt_text: str = "Review literal $(touch SHELL-INJECTION-MARKER).\n",
        missing_binary: bool = False,
        process_timeout: float = 10.0,
    ) -> dict:
        with tempfile.TemporaryDirectory(prefix=f"grok-grade-{scenario}-") as temp:
            root = Path(temp)
            fake = self.prepare_fake(root, scenario)
            if missing_binary:
                fake = root / "not-installed-grok"
            prompt = root / "brief.md"
            marker = root / "SHELL-INJECTION-MARKER"
            prompt.write_text(prompt_text, encoding="utf-8")
            output = root / "output"
            grok_home = root / "grok-home"
            grok_home.mkdir()
            command = [
                str(self.adapter),
                "--mode",
                mode,
                "--prompt-file",
                str(prompt),
                "--output-dir",
                str(output),
                "--grok-home",
                str(grok_home),
                "--grok-bin",
                str(fake),
                "--timeout",
                timeout,
                "--max-turns",
                max_turns,
            ]
            env = {
                "PATH": f"{fake.parent}:/usr/bin:/bin:/usr/sbin:/sbin",
                "HOME": str(root / "operator-home"),
                "TMPDIR": str(root / "tmp"),
                "LANG": "C",
                "LC_ALL": "C",
                "PYTHONDONTWRITEBYTECODE": "1",
                "AWS_SECRET_ACCESS_KEY": "synthetic-aws-secret",
                "UNRELATED_SECRET": "synthetic-unrelated-secret",
            }
            Path(env["HOME"]).mkdir()
            Path(env["TMPDIR"]).mkdir()
            started = time.monotonic()
            timed_out = False
            process = subprocess.Popen(
                command,
                cwd=root,
                env=env,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                start_new_session=True,
            )
            try:
                stdout, stderr = process.communicate(timeout=process_timeout)
            except subprocess.TimeoutExpired:
                timed_out = True
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    stdout, stderr = process.communicate(timeout=2)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    stdout, stderr = process.communicate(timeout=2)
            duration = time.monotonic() - started
            payload = json_status(stdout)
            invocation_path = fake.parent / "invocation.json"
            invocation = None
            if invocation_path.exists():
                try:
                    invocation = json.loads(invocation_path.read_text(encoding="utf-8"))
                except json.JSONDecodeError:
                    invocation = {"decodeError": True}
            reviews = []
            if output.exists():
                for review_path in output.rglob("review.json"):
                    try:
                        reviews.append(json.loads(review_path.read_text(encoding="utf-8")))
                    except json.JSONDecodeError:
                        reviews.append({"decodeError": True})
            retained = retained_text(output) if output.exists() else ""
            child_pid_path = fake.parent / "child.pid"
            child_pid = int(child_pid_path.read_text()) if child_pid_path.exists() else None
            result = {
                "scenario": scenario,
                "mode": mode,
                "exitStatus": process.returncode,
                "timedOutByGrader": timed_out,
                "durationSeconds": round(duration, 3),
                "stdoutPayload": payload,
                "stderr": stderr[-2000:],
                "fakeInvoked": invocation is not None,
                "fakeInvocation": invocation,
                "reviewObjects": reviews,
                "shellInjectionMarkerExists": marker.exists(),
                "retainedSyntheticAwsSecret": "synthetic-aws-secret" in retained,
                "retainedSyntheticUnrelatedSecret": "synthetic-unrelated-secret" in retained,
                "retainedSyntheticInputSecret": "synthetic-input-secret" in retained,
                "childPid": child_pid,
                "childAliveAfterReturn": process_alive(child_pid) if child_pid else None,
            }
            self.case_results[f"{mode}:{scenario}:{timeout}:{max_turns}"] = result
            return result

    def behavioral_checks(self) -> None:
        successes = [self.run_case(scenario) for scenario in SUCCESS_SCENARIOS]
        success_passed = all(
            result["exitStatus"] == 0
            and status_matches(result["stdoutPayload"], "ok")
            and result["fakeInvoked"]
            and any(isinstance(review, dict) and set(review) == REVIEW_KEYS for review in result["reviewObjects"])
            for result in successes
        )
        self.check(
            "direct-envelope-streaming-success",
            success_passed,
            critical=True,
            points=8,
            detail={scenario: self.case_results[f"explicit:{scenario}:3:3"] for scenario in SUCCESS_SCENARIOS},
        )

        streaming = successes[-1]
        invocation = streaming.get("fakeInvocation") or {}
        argv = invocation.get("argv") or []
        env_keys = set(invocation.get("environmentKeys") or [])
        prompt_safe = invocation.get("prompt") == "Review literal $(touch SHELL-INJECTION-MARKER).\n"
        forbidden_flags = {"--always-approve", "--yolo"}
        required_flags = {"--prompt-file", "--sandbox", "--no-memory", "--no-subagents", "--disable-web-search"}
        argv_passed = (
            required_flags.issubset(set(argv))
            and not forbidden_flags.intersection(argv)
            and "read-only" in argv
            and "Read" in argv
            and "MCPTool" in argv
        )
        isolation_passed = (
            prompt_safe
            and argv_passed
            and not streaming["shellInjectionMarkerExists"]
            and "AWS_SECRET_ACCESS_KEY" not in env_keys
            and "UNRELATED_SECRET" not in env_keys
            and not streaming["retainedSyntheticAwsSecret"]
            and not streaming["retainedSyntheticUnrelatedSecret"]
        )
        self.check(
            "safe-argv-prompt-and-environment",
            isolation_passed,
            critical=True,
            points=10,
            detail={
                "promptFilePreserved": prompt_safe,
                "argvContractPassed": argv_passed,
                "fakeEnvironmentKeys": sorted(env_keys),
                "shellInjectionMarkerExists": streaming["shellInjectionMarkerExists"],
                "retainedSyntheticSecrets": streaming["retainedSyntheticAwsSecret"]
                or streaming["retainedSyntheticUnrelatedSecret"],
            },
        )

        bad_inspect = self.run_case("bad-inspect")
        missing_fields = self.run_case("missing-inspect-fields", mode="automatic")
        inspect_passed = (
            bad_inspect["exitStatus"] != 0
            and status_matches(bad_inspect["stdoutPayload"], "isolation-failure")
            and not bad_inspect["fakeInvoked"]
            and missing_fields["exitStatus"] != 0
            and not missing_fields["fakeInvoked"]
        )
        self.check(
            "inspect-allowlist-fails-closed",
            inspect_passed,
            critical=True,
            points=6,
            detail={"badInspect": bad_inspect, "missingFields": missing_fields},
        )

        failure_results = {}
        for scenario, expected in FAILURE_SCENARIOS.items():
            result = self.run_case(scenario)
            failure_results[scenario] = {
                "expected": expected,
                "passed": result["exitStatus"] != 0 and status_matches(result["stdoutPayload"], expected),
                "result": result,
            }
        missing = self.run_case("streaming", missing_binary=True)
        failure_results["missing-cli"] = {
            "expected": "missing-cli",
            "passed": missing["exitStatus"] != 0 and status_matches(missing["stdoutPayload"], "missing-cli"),
            "result": missing,
        }
        self.check(
            "concrete-failure-classification",
            all(value["passed"] for value in failure_results.values()),
            critical=True,
            points=10,
            detail=failure_results,
        )

        timeout = self.run_case("timeout", timeout="0.3", process_timeout=5)
        if timeout["childPid"] and timeout["childAliveAfterReturn"]:
            for _ in range(30):
                time.sleep(0.1)
                if not process_alive(timeout["childPid"]):
                    timeout["childAliveAfterGrace"] = False
                    break
            else:
                timeout["childAliveAfterGrace"] = True
        else:
            timeout["childAliveAfterGrace"] = timeout["childAliveAfterReturn"]
        timeout_passed = (
            timeout["exitStatus"] != 0
            and status_matches(timeout["stdoutPayload"], "timeout")
            and timeout["childPid"] is not None
            and timeout["childAliveAfterGrace"] is False
        )
        self.check(
            "timeout-kills-complete-process-tree",
            timeout_passed,
            critical=True,
            points=5,
            detail=timeout,
        )

        automatic = self.run_case("streaming", mode="automatic")
        automatic_passed = (
            automatic["exitStatus"] != 0
            and status_matches(automatic["stdoutPayload"], "isolation-failure")
            and not automatic["fakeInvoked"]
        )
        self.check(
            "automatic-mode-disabled-and-fail-closed",
            automatic_passed,
            critical=True,
            points=4,
            detail=automatic,
        )

        secret_prompt = self.run_case(
            "streaming",
            prompt_text="XAI_API_KEY=synthetic-input-secret\n",
        )
        secret_passed = (
            secret_prompt["exitStatus"] != 0
            and not secret_prompt["fakeInvoked"]
            and not secret_prompt["retainedSyntheticInputSecret"]
        )
        self.check(
            "credential-shaped-input-rejected-before-call",
            secret_passed,
            critical=True,
            points=2,
            detail=secret_prompt,
        )

        numeric = []
        for timeout_value, turns in (("0", "3"), ("601", "3"), ("NaN", "3"), ("3", "0"), ("3", "9")):
            result = self.run_case("streaming", timeout=timeout_value, max_turns=turns)
            numeric.append(
                {
                    "timeout": timeout_value,
                    "maxTurns": turns,
                    "passed": result["exitStatus"] != 0 and not result["fakeInvoked"],
                    "result": result,
                }
            )
        self.check(
            "numeric-bounds-fail-before-call",
            all(item["passed"] for item in numeric),
            critical=False,
            points=5,
            detail=numeric,
        )

    def grade(self) -> dict:
        self.artifact_checks()
        if self.adapter.is_file() and not self.adapter.is_symlink():
            try:
                self.behavioral_checks()
            except Exception as exc:  # Preserve a grader-side failure as evidence.
                self.check(
                    "grader-completed",
                    False,
                    critical=True,
                    points=0,
                    detail={"exceptionType": type(exc).__name__, "message": str(exc)},
                )
        else:
            self.check(
                "grader-completed",
                False,
                critical=True,
                points=0,
                detail="adapter missing or symlinked; behavioral cases not run",
            )
        critical_failures = [
            name for name, check in self.checks.items() if check["critical"] and not check["passed"]
        ]
        points = sum(check["pointsAwarded"] for check in self.checks.values())
        available = sum(check["pointsAvailable"] for check in self.checks.values())
        return {
            "schemaVersion": 1,
            "candidateAggregateSha256": hashlib.sha256(
                "".join(
                    f"{sha256(path)}  {path.relative_to(self.candidate).as_posix()}\n"
                    for path in sorted(self.candidate.rglob("*"))
                    if path.is_file() and not path.is_symlink()
                ).encode()
            ).hexdigest(),
            "deterministicPointsAwarded": points,
            "deterministicPointsAvailable": available,
            "criticalFailures": critical_failures,
            "recommendableArtifact": not critical_failures,
            "checks": self.checks,
            "caseResults": self.case_results,
        }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate", required=True, type=Path)
    parser.add_argument("--fake-source", required=True, type=Path)
    parser.add_argument("--contract", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    grade = CandidateGrader(
        args.candidate.resolve(), args.fake_source.resolve(), args.contract.resolve()
    ).grade()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(grade, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                "output": str(args.output),
                "points": grade["deterministicPointsAwarded"],
                "available": grade["deterministicPointsAvailable"],
                "criticalFailures": grade["criticalFailures"],
            },
            sort_keys=True,
        )
    )
    return 0 if not grade["criticalFailures"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
