#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

function fail(message) {
  console.error(`FAIL: ${message}`);
  process.exit(2);
}

if (process.argv.length !== 6) {
  fail("usage: audit-toolboxmd-v2-events.mjs <events.jsonl> <run-root> <authoring|positive|noskill|near-miss|preflight> <expected-skill-relative-path|none>");
}

const eventsPath = path.resolve(process.argv[2]);
const runRoot = path.resolve(process.argv[3]);
const mode = process.argv[4];
const expectedValue = process.argv[5];
const allowedModes = new Set(["authoring", "positive", "noskill", "near-miss", "preflight"]);
if (!allowedModes.has(mode)) fail(`unsupported mode: ${mode}`);
if (!fs.existsSync(eventsPath) || !fs.statSync(eventsPath).isFile()) fail(`events file not found: ${eventsPath}`);
if (!fs.existsSync(runRoot) || !fs.statSync(runRoot).isDirectory()) fail(`run root not found: ${runRoot}`);

let expectedRelative = null;
let expectedAbsolute = null;
let expectedText = null;
if (expectedValue !== "none") {
  expectedRelative = expectedValue.replace(/^\.\//, "");
  expectedAbsolute = path.resolve(runRoot, expectedRelative);
  if (expectedAbsolute !== runRoot && !expectedAbsolute.startsWith(`${runRoot}${path.sep}`)) fail("expected skill path escapes run root");
  if (!fs.existsSync(expectedAbsolute) || !fs.statSync(expectedAbsolute).isFile()) fail(`expected skill file not found: ${expectedRelative}`);
  expectedText = fs.readFileSync(expectedAbsolute, "utf8");
} else if (["authoring", "positive", "preflight"].includes(mode)) {
  fail(`${mode} mode requires an expected skill path`);
}

const reasons = [];
const commands = [];
const commandEvents = [];
const observedSkillPaths = new Set();
const skillOutputs = new Map();
const networkCommands = [];
const warnings = [];
let gitStatusObserved = false;
let gitStatusOutsideNamesObserved = false;
let firstOutputMutationIndex = null;
let expectedLoadIndex = null;
let eventCount = 0;
let turnCompleted = false;
const usage = {
  inputTokens: null,
  cachedInputTokens: null,
  uncachedInputTokens: null,
  outputTokens: null,
  runtimeTokens: null,
};

function commandSkillPaths(command) {
  const paths = new Set();
  for (const match of command.matchAll(/(?:^|[\s"'(])((?:\.\/?|[A-Za-z0-9._~+/-]*\/)?(?:creator|output\/[A-Za-z0-9._-]+|\.agents\/skills\/[A-Za-z0-9._-]+)\/SKILL\.md)(?=$|[\s"')])/g)) {
    let value = match[1].replace(/^\.\//, "");
    const absolute = path.isAbsolute(value) ? value : path.resolve(runRoot, value);
    if (absolute === runRoot || absolute.startsWith(`${runRoot}${path.sep}`)) {
      value = path.relative(runRoot, absolute).split(path.sep).join("/");
    }
    paths.add(value);
  }
  return [...paths];
}

function isInsideRunRoot(candidate) {
  return candidate === runRoot || candidate.startsWith(`${runRoot}${path.sep}`);
}

function parentRelativeOperands(command) {
  const operands = [];
  const pattern = /(?:^|[\s"'(=,:;|&<>])([^\s"'(),:;|&<>]+)(?=$|[\s"'),:;|&<>])/g;
  for (const match of command.matchAll(pattern)) {
    const operand = match[1];
    if (operand.split("/").includes("..")) operands.push(operand);
  }
  return operands;
}

function canResolveLiterally(operand) {
  return !/[$`~{}*?]/.test(operand);
}

function recordedCommandCwd(item) {
  if (typeof item.cwd !== "string" || item.cwd.trim().length === 0) return null;
  return path.isAbsolute(item.cwd)
    ? path.resolve(item.cwd)
    : path.resolve(runRoot, item.cwd);
}

function changesWorkingDirectory(command) {
  return /(?:^|[\s;&|()])(?:builtin\s+)?cd(?=$|[\s;&|()])/.test(command);
}

function isOutputMutation(event, index) {
  const item = event.item;
  if (!item) return false;
  if (item.type === "file_change" && JSON.stringify(item).includes("output/")) return true;
  if (item.type !== "command_execution" || typeof item.command !== "string") return false;
  if (!item.command.includes("output/")) return false;
  if (/\b(?:mkdir|touch|cp|mv|install|tee)\b/i.test(item.command)) return true;
  if (/(?:^|[\s;])>{1,2}\s*["']?output\//.test(item.command)) return true;
  return /\b(?:python|python3|node|bash|zsh|sh)\b/i.test(item.command) && index > 0;
}

const lines = fs.readFileSync(eventsPath, "utf8").split(/\r?\n/).filter(Boolean);
eventCount = lines.length;
for (let index = 0; index < lines.length; index += 1) {
  let event;
  try {
    event = JSON.parse(lines[index]);
  } catch (error) {
    reasons.push(`invalid JSONL at line ${index + 1}`);
    continue;
  }

  if (event.type === "turn.completed") {
    turnCompleted = true;
    if (event.usage) {
      usage.inputTokens = event.usage.input_tokens ?? null;
      usage.cachedInputTokens = event.usage.cached_input_tokens ?? 0;
      usage.outputTokens = event.usage.output_tokens ?? null;
    }
  }

  if (firstOutputMutationIndex === null && isOutputMutation(event, index)) firstOutputMutationIndex = index;

  const item = event.item;
  if (!item || item.type !== "command_execution" || item.status === "in_progress" || typeof item.command !== "string") continue;

  const command = item.command;
  commands.push(command);
  commandEvents.push({ index, command, exitCode: item.exit_code ?? null });

  if (/(^|[\s"'])(codex|claude|gemini|grok)([\s"']|$)/i.test(command)) {
    reasons.push("nested model or agentic CLI command observed");
  }

  const networkCapable = /(^|[\s"'])(curl|wget)([\s"']|$)|\b(?:git|gh)\s+(?:clone|fetch|pull|api)\b/i.test(command);
  if (networkCapable) {
    networkCommands.push({ command, exitCode: item.exit_code ?? null });
    if (mode !== "preflight") reasons.push("network-capable command observed");
  }

  const commandCwd = recordedCommandCwd(item);
  if (commandCwd !== null && !isInsideRunRoot(commandCwd)) {
    reasons.push("command working directory outside run root observed");
  }

  const parentOperands = parentRelativeOperands(command);
  if (parentOperands.length > 0) {
    const cwdIsUsable = commandCwd !== null
      && isInsideRunRoot(commandCwd)
      && !changesWorkingDirectory(command);
    const allStayInside = cwdIsUsable
      && parentOperands.every(operand => canResolveLiterally(operand) && isInsideRunRoot(path.resolve(commandCwd, operand)));
    if (!allStayInside) reasons.push("parent-directory traversal observed");
  }

  if (/\bgit\s+status\b/i.test(command)) {
    gitStatusObserved = true;
    const output = typeof item.aggregated_output === "string" ? item.aggregated_output : "";
    if (/(?:^|\n)[ MARCUD?!]{1,2}\s+(?:\.\.\/)+/m.test(output)) {
      gitStatusOutsideNamesObserved = true;
      warnings.push("git status exposed names from an ancestor worktree without reading file contents");
    }
  }

  const absoluteUserPaths = command.match(/\/Users\/[A-Za-z0-9._-]+(?:\/[A-Za-z0-9._~+\/-]+)+/g) ?? [];
  for (const rawPath of absoluteUserPaths) {
    const candidate = rawPath.replace(/[),;:]+$/, "");
    if (candidate !== runRoot && !candidate.startsWith(`${runRoot}${path.sep}`)) {
      reasons.push("absolute user path outside run root observed");
      break;
    }
  }

  for (const relative of commandSkillPaths(command)) {
    observedSkillPaths.add(relative);
    const output = typeof item.aggregated_output === "string" ? item.aggregated_output : "";
    if (!skillOutputs.has(relative)) skillOutputs.set(relative, []);
    skillOutputs.get(relative).push(output);
    if (expectedRelative === relative && expectedLoadIndex === null) expectedLoadIndex = index;
  }
}

if (Number.isInteger(usage.inputTokens) && Number.isInteger(usage.cachedInputTokens)) {
  usage.uncachedInputTokens = Math.max(0, usage.inputTokens - usage.cachedInputTokens);
}
if (Number.isInteger(usage.uncachedInputTokens) && Number.isInteger(usage.outputTokens)) {
  usage.runtimeTokens = usage.uncachedInputTokens + usage.outputTokens;
}

function fullContentObserved(relative, text) {
  const combined = (skillOutputs.get(relative) ?? []).join("\n");
  if (!combined) return false;
  if (combined.includes(text.trimEnd())) return true;
  const uniqueLines = [...new Set(text.split(/\r?\n/).map(line => line.trimEnd()).filter(line => line.trim().length > 0))];
  return uniqueLines.length > 0 && uniqueLines.every(line => combined.includes(line));
}

const observedLoads = [...observedSkillPaths].sort().map(relative => {
  const absolute = path.resolve(runRoot, relative);
  const text = absolute.startsWith(`${runRoot}${path.sep}`) && fs.existsSync(absolute) && fs.statSync(absolute).isFile()
    ? fs.readFileSync(absolute, "utf8")
    : null;
  return {
    path: relative,
    fullContentObserved: text === null ? false : fullContentObserved(relative, text),
  };
});

const expectedSkillLoad = expectedRelative === null
  ? null
  : {
      path: expectedRelative,
      observed: observedSkillPaths.has(expectedRelative),
      fullContentObserved: fullContentObserved(expectedRelative, expectedText),
      eventIndex: expectedLoadIndex,
      beforeFirstOutputMutation: firstOutputMutationIndex === null || (expectedLoadIndex !== null && expectedLoadIndex < firstOutputMutationIndex),
    };

if (["authoring", "positive", "preflight"].includes(mode)) {
  if (!expectedSkillLoad.observed) reasons.push("expected skill load not observed");
  else if (!expectedSkillLoad.fullContentObserved) reasons.push("full expected SKILL.md content not observed");
  if (expectedSkillLoad.observed && !expectedSkillLoad.beforeFirstOutputMutation) reasons.push("expected skill loaded after output mutation began");
}

if (mode === "noskill" && observedLoads.length > 0) reasons.push("skill load observed in no-skill arm");

if (mode === "positive" || mode === "preflight") {
  const unexpected = observedLoads.filter(load => load.path !== expectedRelative);
  if (unexpected.length > 0) reasons.push("unexpected skill load observed");
}

if (mode === "authoring") {
  const unexpected = observedLoads.filter(load => load.path !== expectedRelative && !load.path.startsWith("output/"));
  if (unexpected.length > 0) reasons.push("unexpected skill load observed");
}

const networkProbe = {
  observed: networkCommands.length > 0,
  attemptCount: networkCommands.length,
  blocked: networkCommands.length > 0 && networkCommands.every(item => Number.isInteger(item.exitCode) && item.exitCode !== 0),
  exitCodes: networkCommands.map(item => item.exitCode),
};
if (mode === "preflight") {
  if (!networkProbe.observed) reasons.push("network probe not observed");
  else if (!networkProbe.blocked) reasons.push("network probe succeeded or lacked a nonzero exit");
}

if (!turnCompleted) reasons.push("turn.completed event not observed");

const uniqueReasons = [...new Set(reasons)];
const result = {
  schemaVersion: 2,
  mode,
  eligible: uniqueReasons.length === 0,
  reasons: uniqueReasons,
  warnings: [...new Set(warnings)],
  eventCount,
  commandCount: commands.length,
  turnCompleted,
  expectedSkillLoad,
  observedSkillLoads: observedLoads,
  falsePositiveSkillLoad: mode === "near-miss" && observedLoads.some(load => load.path.startsWith(".agents/skills/")),
  firstOutputMutationEventIndex: firstOutputMutationIndex,
  networkProbe,
  gitStatus: {
    observed: gitStatusObserved,
    ancestorWorktreeNamesObserved: gitStatusOutsideNamesObserved,
  },
  usage,
};

process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
if (!result.eligible) process.exit(1);
