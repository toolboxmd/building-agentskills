#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

function fail(message) {
  console.error(`FAIL: ${message}`);
  process.exit(1);
}

function requireFile(filePath) {
  if (!fs.existsSync(filePath) || !fs.statSync(filePath).isFile()) {
    fail(`missing file: ${filePath}`);
  }
}

function requireDirectory(directory) {
  if (!fs.existsSync(directory) || !fs.statSync(directory).isDirectory()) {
    fail(`missing directory: ${directory}`);
  }
}

function copyDirectory(source, destination) {
  requireDirectory(source);
  fs.cpSync(source, destination, {
    recursive: true,
    dereference: false,
    errorOnExist: true,
    force: false,
    verbatimSymlinks: true,
    filter(currentSource) {
      if (fs.lstatSync(currentSource).isSymbolicLink()) {
        fail(`symbolic link is not allowed in staged input: ${currentSource}`);
      }
      return true;
    },
  });
}

if (process.argv.length !== 7) {
  fail("usage: stage-toolboxmd-benchmark.mjs <authoring|downstream> <sealed-root> <case-id> <package-source> <run-root>");
}

const [mode, rawSealedRoot, caseId, rawPackageSource, rawRunRoot] = process.argv.slice(2);
if (!new Set(["authoring", "downstream"]).has(mode)) fail(`unknown mode: ${mode}`);

const sealedRoot = path.resolve(rawSealedRoot);
const caseRoot = path.join(sealedRoot, caseId);
const packageSource = path.resolve(rawPackageSource);
const runRoot = path.resolve(rawRunRoot);

requireDirectory(caseRoot);
requireDirectory(packageSource);
const contractPath = path.join(caseRoot, "deterministic-contract.json");
requireFile(contractPath);
const contract = JSON.parse(fs.readFileSync(contractPath, "utf8"));
if (contract.caseId !== caseId) fail(`contract caseId does not match directory: ${caseId}`);
if (typeof contract.requiredSkillName !== "string" || contract.requiredSkillName.length === 0) {
  fail(`contract requiredSkillName is missing: ${contractPath}`);
}
if (fs.existsSync(runRoot)) fail(`run root already exists: ${runRoot}`);
fs.mkdirSync(runRoot, { recursive: true });

let exactPrompt;
let guard;

if (mode === "authoring") {
  const promptPath = path.join(caseRoot, "authoring-prompt.md");
  requireFile(promptPath);
  exactPrompt = fs.readFileSync(promptPath, "utf8").trimEnd();
  copyDirectory(packageSource, path.join(runRoot, "creator"));
  copyDirectory(path.join(caseRoot, "visible-inputs"), path.join(runRoot, "visible-inputs"));
  guard = `# Frozen benchmark guard

This is one arm of a frozen skill-authoring comparison.

- Read \`creator/SKILL.md\` first and follow that creator package.
- Read only \`task.md\`, files below \`creator/\`, and files below \`visible-inputs/\`.
- Write only below \`output/\`. Do not modify creator or input files.
- Do not read parent directories, installed skills, user memory, benchmark rubrics, sibling runs, prior outputs, or grader material.
- Do not use network access, subagents, another model, or an agentic CLI.
- Do not mention the creator package name, vendor, treatment, or benchmark arm in the generated skill or final report.
- Do not repair or revise the package after the final validation pass.

# Authoring brief`;
} else {
  const promptPath = path.join(caseRoot, "downstream-prompt.md");
  requireFile(promptPath);
  exactPrompt = fs.readFileSync(promptPath, "utf8").trimEnd();
  const stagedSkillRoot = path.join(runRoot, "output", contract.requiredSkillName);
  fs.mkdirSync(path.dirname(stagedSkillRoot), { recursive: true });
  copyDirectory(packageSource, stagedSkillRoot);
  copyDirectory(path.join(caseRoot, "downstream-inputs"), path.join(runRoot, "downstream-inputs"));
  guard = `# Frozen benchmark guard

This is one downstream-use arm of a frozen comparison.

- Read \`output/${contract.requiredSkillName}/SKILL.md\` first and follow that generated skill explicitly.
- Read only \`task.md\`, files below \`output/${contract.requiredSkillName}/\`, and files below \`downstream-inputs/\`.
- Treat the generated skill and \`downstream-inputs/\` as immutable. Write only below \`downstream-output/\`.
- Do not read parent directories, installed skills, user memory, sibling runs, prior outputs, creator packages, rubrics, identity maps, or grader material.
- Do not use network access, subagents, another model, or an agentic CLI.
- Do not repair or edit the generated skill, even if it is incomplete.

# Downstream task`;
}

fs.writeFileSync(path.join(runRoot, "task.md"), `${guard}\n\n${exactPrompt}\n`);
process.stdout.write(`${runRoot}\n`);
