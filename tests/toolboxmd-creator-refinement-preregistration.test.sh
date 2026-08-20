#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
benchmark="$root/benchmarks/toolboxmd-creating-skills/refinement-v1"
manifest="$benchmark/preregistration.json"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

jq empty "$manifest"
for json_file in "$benchmark"/held-out/safe-archive-inspector/*.json "$benchmark"/harness/*.json; do
  jq empty "$json_file"
done

PYTHONDONTWRITEBYTECODE=1 python3 -B - "$root" "$temporary" <<'PY'
from hashlib import sha256
import ast
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

root = Path(sys.argv[1])
temporary = Path(sys.argv[2])
benchmark = root / "benchmarks/toolboxmd-creating-skills/refinement-v1"
manifest = json.loads((benchmark / "preregistration.json").read_text(encoding="utf-8"))

def tree(path):
    files = sorted((item for item in path.rglob("*") if item.is_file()), key=lambda item: item.relative_to(path).as_posix().encode())
    lines = "".join(f"{sha256(item.read_bytes()).hexdigest()}  {item.relative_to(path).as_posix()}\n" for item in files)
    return {
        "fileCount": len(files),
        "bytes": sum(item.stat().st_size for item in files),
        "aggregateSha256": sha256(lines.encode()).hexdigest(),
    }

for arm in ("R0", "R1"):
    treatment = manifest["treatments"][arm]
    actual = tree(root / treatment["path"])
    assert actual == {key: treatment[key] for key in ("fileCount", "bytes", "aggregateSha256")}, (arm, actual, treatment)

r0 = root / manifest["treatments"]["R0"]["path"]
r1 = root / manifest["treatments"]["R1"]["path"]
assert (r1 / "SKILL.md").stat().st_size - (r0 / "SKILL.md").stat().st_size == 261
assert (r0 / "scripts/validate_skill.py").read_bytes() == (r1 / "scripts/validate_skill.py").read_bytes()
assert (r0 / "agents/openai.yaml").read_bytes() == (r1 / "agents/openai.yaml").read_bytes()

harness = manifest["harness"]
actual_harness = tree(root / harness["path"])
assert actual_harness == {key: harness[key] for key in ("fileCount", "bytes", "aggregateSha256")}
task = manifest["tasks"]["safeArchiveInspector"]
actual_task = tree(root / task["path"])
assert actual_task == {key: task[key] for key in ("fileCount", "bytes", "aggregateSha256")}

for path in (benchmark / "harness").glob("*.py"):
    ast.parse(path.read_text(encoding="utf-8"), filename=str(path))

runner_path = benchmark / "harness/run_bounded_refinement.py"
runner_spec = importlib.util.spec_from_file_location("bounded_refinement_runner", runner_path)
assert runner_spec and runner_spec.loader
runner = importlib.util.module_from_spec(runner_spec)
runner_spec.loader.exec_module(runner)
non_green_grade = temporary / "non-green-grade.json"
grader_status = runner.run_grader(
    [
        sys.executable,
        "-B",
        "-c",
        "from pathlib import Path; import sys; Path(sys.argv[1]).write_text('{}\\n', encoding='utf-8'); raise SystemExit(1)",
        str(non_green_grade),
    ],
    non_green_grade,
)
assert grader_status == 1
assert json.loads(non_green_grade.read_text(encoding="utf-8")) == {}

assert manifest["execution"]["tokenEligibilityCap"] is None
assert manifest["preregistrationRevision"] == 2
assert manifest["revisionHistory"][0]["commit"] == "436093fb6c129a4c8741f4093b256188282c1b5a"
assert manifest["revisionHistory"][0]["status"] == "invalidated-before-any-eligible-result"
assert manifest["execution"]["repairSessionsMaximumPerArm"] == 2
assert manifest["execution"]["wallTimeSecondsPerSession"] == 900
assert manifest["claimBoundary"]["generalCreatorImprovementClaimAllowed"] is False
assert manifest["claimBoundary"]["knownGrokDevelopmentRunRanked"] is False
assert manifest["evaluation"]["deterministicPoints"] == 70
assert manifest["evaluation"]["semanticPoints"] == 30
assert manifest["evaluation"]["deterministicGreenFloor"] == 63

answer = json.loads((benchmark / "held-out/safe-archive-inspector/judge-answer-key.json").read_text())
fixtures = json.loads((benchmark / "held-out/safe-archive-inspector/judge-fixtures.json").read_text())
assert len(fixtures["fixtures"]) == 12
assert set(answer["expected"]) == {row["id"] for row in fixtures["fixtures"]}
assert sum(answer["expected"].values()) == 4

grade_path = temporary / "reference-grade.json"
subprocess.run(
    [
        sys.executable,
        str(benchmark / "harness/grade_archive_candidate.py"),
        "--candidate",
        str(benchmark / "harness/fixtures/reference-pass"),
        "--output",
        str(grade_path),
    ],
    check=True,
)
grade = json.loads(grade_path.read_text())
assert grade["deterministicPointsAwarded"] == 70
assert grade["deterministicPointsAvailable"] == 70
assert grade["criticalFailures"] == []
assert grade["recommendableArtifact"] is True
PY

for arm in r0-merged-vnext r1-bounded-refinement; do
  package="$benchmark/treatments/$arm/package"
  validation_copy="$temporary/$arm/toolboxmd-creating-skills"
  mkdir -p "$(dirname "$validation_copy")"
  cp -R "$package" "$validation_copy"
  PYTHONDONTWRITEBYTECODE=1 python3 -B "$validation_copy/scripts/validate_skill.py" \
    --creation-mode --warnings-as-errors --max-package-bytes 48000 "$validation_copy" >/dev/null
done

test -x "$benchmark/harness/run_phase.py"
test -x "$benchmark/harness/run_bounded_refinement.py"
test -x "$benchmark/harness/run_archive_judge.py"
test -x "$benchmark/harness/grade_archive_candidate.py"
test -x "$benchmark/harness/fixtures/reference-pass/scripts/inspect_archive.py"

echo "PASS: bounded Creator refinement preregistration"
