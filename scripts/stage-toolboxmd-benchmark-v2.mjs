#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

function fail(message) {
  console.error(`FAIL: ${message}`);
  process.exit(2);
}

function requireDirectory(value, label) {
  const resolved = path.resolve(value);
  if (!fs.existsSync(resolved) || !fs.statSync(resolved).isDirectory()) {
    fail(`${label} is not a directory: ${value}`);
  }
  return resolved;
}

function requireFile(value, label) {
  const resolved = path.resolve(value);
  if (!fs.existsSync(resolved) || !fs.statSync(resolved).isFile()) {
    fail(`${label} is not a file: ${value}`);
  }
  return resolved;
}

function rejectSymlinks(root) {
  function walk(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const absolute = path.join(directory, entry.name);
      if (entry.isSymbolicLink()) fail(`symbolic link is not allowed: ${absolute}`);
      if (entry.isDirectory()) walk(absolute);
    }
  }
  walk(root);
}

function copyDirectory(source, destination) {
  rejectSymlinks(source);
  fs.cpSync(source, destination, {
    recursive: true,
    force: false,
    errorOnExist: true,
    preserveTimestamps: false,
  });
}

function createRunRoot(value) {
  const resolved = path.resolve(value);
  if (fs.existsSync(resolved)) fail(`run root already exists: ${resolved}`);
  fs.mkdirSync(resolved, { recursive: true });
  return resolved;
}

function readContract(caseRoot) {
  const contractPath = requireFile(path.join(caseRoot, "contract.json"), "case contract");
  let contract;
  try {
    contract = JSON.parse(fs.readFileSync(contractPath, "utf8"));
  } catch (error) {
    fail(`invalid case contract JSON: ${error.message}`);
  }
  if (contract.schemaVersion !== 2 || typeof contract.targetSkillName !== "string") {
    fail(`invalid case contract shape: ${contractPath}`);
  }
  return contract;
}

function copyPrompt(source, runRoot) {
  fs.copyFileSync(requireFile(source, "prompt"), path.join(runRoot, "task.md"), fs.constants.COPYFILE_EXCL);
}

function stageOrdinaryWorkspace(caseRoot, runRoot) {
  const workspace = requireDirectory(path.join(caseRoot, "downstream-workspace"), "downstream workspace");
  rejectSymlinks(workspace);
  for (const entry of fs.readdirSync(workspace, { withFileTypes: true })) {
    const source = path.join(workspace, entry.name);
    const destination = path.join(runRoot, entry.name);
    if (entry.isDirectory()) copyDirectory(source, destination);
    else if (entry.isFile()) fs.copyFileSync(source, destination, fs.constants.COPYFILE_EXCL);
    else fail(`unsupported workspace entry: ${source}`);
  }
  fs.mkdirSync(path.join(runRoot, "output"));
}

const [mode, ...args] = process.argv.slice(2);

if (mode === "authoring") {
  if (args.length !== 4) fail("usage: stage-toolboxmd-benchmark-v2.mjs authoring <cases-root> <case-id> <creator-dir> <run-root>");
  const [casesValue, caseId, creatorValue, runValue] = args;
  const casesRoot = requireDirectory(casesValue, "cases root");
  const caseRoot = requireDirectory(path.join(casesRoot, caseId), "case root");
  const creatorRoot = requireDirectory(creatorValue, "creator directory");
  const sources = requireDirectory(path.join(caseRoot, "authoring-sources"), "authoring sources");
  readContract(caseRoot);
  const runRoot = createRunRoot(runValue);
  copyPrompt(path.join(caseRoot, "authoring-prompt.md"), runRoot);
  copyDirectory(creatorRoot, path.join(runRoot, "creator"));
  copyDirectory(sources, path.join(runRoot, "authoring-sources"));
  fs.mkdirSync(path.join(runRoot, "output"));
  process.stdout.write(`${runRoot}\n`);
  process.exit(0);
}

if (mode === "noskill") {
  if (args.length !== 3) fail("usage: stage-toolboxmd-benchmark-v2.mjs noskill <cases-root> <case-id> <run-root>");
  const [casesValue, caseId, runValue] = args;
  const casesRoot = requireDirectory(casesValue, "cases root");
  const caseRoot = requireDirectory(path.join(casesRoot, caseId), "case root");
  readContract(caseRoot);
  const runRoot = createRunRoot(runValue);
  copyPrompt(path.join(caseRoot, "downstream-prompt.md"), runRoot);
  stageOrdinaryWorkspace(caseRoot, runRoot);
  process.stdout.write(`${runRoot}\n`);
  process.exit(0);
}

if (mode === "downstream") {
  if (args.length !== 4) fail("usage: stage-toolboxmd-benchmark-v2.mjs downstream <cases-root> <case-id> <generated-skill-dir> <run-root>");
  const [casesValue, caseId, skillValue, runValue] = args;
  const casesRoot = requireDirectory(casesValue, "cases root");
  const caseRoot = requireDirectory(path.join(casesRoot, caseId), "case root");
  const skillRoot = requireDirectory(skillValue, "generated skill directory");
  const contract = readContract(caseRoot);
  if (path.basename(skillRoot) !== contract.targetSkillName) {
    fail(`generated skill directory must be named ${contract.targetSkillName}`);
  }
  const runRoot = createRunRoot(runValue);
  copyPrompt(path.join(caseRoot, "downstream-prompt.md"), runRoot);
  stageOrdinaryWorkspace(caseRoot, runRoot);
  const skillDestination = path.join(runRoot, ".agents", "skills", contract.targetSkillName);
  fs.mkdirSync(path.dirname(skillDestination), { recursive: true });
  copyDirectory(skillRoot, skillDestination);
  process.stdout.write(`${runRoot}\n`);
  process.exit(0);
}

if (mode === "near-miss") {
  if (args.length !== 4) fail("usage: stage-toolboxmd-benchmark-v2.mjs near-miss <cases-root> <comma-separated-case-ids> <skills-root> <run-root>");
  const [casesValue, caseList, skillsValue, runValue] = args;
  const casesRoot = requireDirectory(casesValue, "cases root");
  const skillsRoot = requireDirectory(skillsValue, "treatment skills root");
  const caseIds = caseList.split(",").map(value => value.trim()).filter(Boolean);
  if (caseIds.length === 0 || new Set(caseIds).size !== caseIds.length) fail("near-miss case list must contain unique case ids");
  const prompts = caseIds.map((caseId, index) => {
    const caseRoot = requireDirectory(path.join(casesRoot, caseId), "case root");
    const contract = readContract(caseRoot);
    if (!fs.existsSync(path.join(skillsRoot, contract.targetSkillName, "SKILL.md"))) {
      fail(`near-miss skill is missing: ${contract.targetSkillName}`);
    }
    const prompt = fs.readFileSync(requireFile(path.join(caseRoot, "near-miss-prompt.md"), "near-miss prompt"), "utf8").trim();
    return `${index + 1}. ${prompt}`;
  });
  const runRoot = createRunRoot(runValue);
  fs.writeFileSync(path.join(runRoot, "task.md"), `Answer each request briefly and independently.\n\n${prompts.join("\n\n")}\n`);
  const destination = path.join(runRoot, ".agents", "skills");
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  copyDirectory(skillsRoot, destination);
  fs.mkdirSync(path.join(runRoot, "output"));
  process.stdout.write(`${runRoot}\n`);
  process.exit(0);
}

if (mode === "preflight") {
  if (args.length !== 2) fail("usage: stage-toolboxmd-benchmark-v2.mjs preflight <preflight-root> <run-root>");
  const [preflightValue, runValue] = args;
  const preflightRoot = requireDirectory(preflightValue, "preflight root");
  const skillRoot = requireDirectory(path.join(preflightRoot, "skill"), "preflight skill");
  const runRoot = createRunRoot(runValue);
  copyPrompt(path.join(preflightRoot, "prompt.md"), runRoot);
  const skillDestination = path.join(runRoot, ".agents", "skills", path.basename(skillRoot) === "skill" ? "cobalt-finch-preflight" : path.basename(skillRoot));
  fs.mkdirSync(path.dirname(skillDestination), { recursive: true });
  copyDirectory(skillRoot, skillDestination);
  fs.mkdirSync(path.join(runRoot, "output"));
  process.stdout.write(`${runRoot}\n`);
  process.exit(0);
}

fail("mode must be authoring, noskill, downstream, near-miss, or preflight");
