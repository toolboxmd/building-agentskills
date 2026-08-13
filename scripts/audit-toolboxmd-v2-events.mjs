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
const gitCommandEvents = [];
const warnings = [];
let gitStatusObserved = false;
let gitStatusOutsideNamesObserved = false;
let firstOutputMutationIndex = null;
let expectedLoadIndex = null;
let eventCount = 0;
let commandExecutionEventCount = 0;
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

function shellTokens(command) {
  const tokens = [];
  const pattern = /"((?:\\.|[^"\\])*)"|'([^']*)'|(&&|\|\||[;|\n])|([^\s"';&|]+)/g;
  for (const match of command.matchAll(pattern)) {
    const value = match[1] ?? match[2] ?? match[3] ?? match[4];
    tokens.push({ value, index: match.index ?? 0 });
  }
  return tokens;
}

function commandTokens(command) {
  const tokens = [];
  let value = "";
  let start = null;
  let quote = null;
  const flush = () => {
    if (start !== null) tokens.push({ value, index: start });
    value = "";
    start = null;
  };

  for (let index = 0; index < command.length; index += 1) {
    const character = command[index];
    if (quote !== null) {
      if (character === quote) quote = null;
      else if (quote === '"' && character === "\\" && index + 1 < command.length) value += command[index += 1];
      else value += character;
      continue;
    }
    if (character === "'" || character === '"') {
      if (start === null) start = index;
      quote = character;
    } else if (character === "\\" && index + 1 < command.length) {
      if (start === null) start = index;
      value += command[index += 1];
    } else if (character === "\n") {
      flush();
      tokens.push({ value: "\n", index });
    } else if (/\s/.test(character)) {
      flush();
    } else if (/[;|&]/.test(character)) {
      flush();
      const doubled = command[index + 1] === character && /[|&]/.test(character);
      tokens.push({ value: doubled ? `${character}${character}` : character, index });
      if (doubled) index += 1;
    } else {
      if (start === null) start = index;
      value += character;
    }
  }
  flush();
  return tokens;
}

function parenthesizedPayload(command, openIndex) {
  let depth = 1;
  let quote = null;
  for (let index = openIndex + 1; index < command.length; index += 1) {
    const character = command[index];
    if (quote === "'") {
      if (character === "'") quote = null;
      continue;
    }
    if (quote === '"') {
      if (character === '"') quote = null;
      else if (character === "\\") index += 1;
      continue;
    }
    if (character === "\\") {
      index += 1;
      continue;
    }
    if (character === "'" || character === '"') {
      quote = character;
      continue;
    }
    if (character === "`") {
      for (index += 1; index < command.length; index += 1) {
        if (command[index] === "\\") index += 1;
        else if (command[index] === "`") break;
      }
      continue;
    }
    if (character === "(") depth += 1;
    else if (character === ")") {
      depth -= 1;
      if (depth === 0) {
        return { payload: command.slice(openIndex + 1, index), endIndex: index };
      }
    }
  }
  return null;
}

function backtickPayload(command, openIndex) {
  for (let index = openIndex + 1; index < command.length; index += 1) {
    if (command[index] === "\\") index += 1;
    else if (command[index] === "`") {
      return { payload: command.slice(openIndex + 1, index), endIndex: index };
    }
  }
  return null;
}

function shellSubstitutionPayloads(command) {
  const payloads = [];
  let quote = null;
  for (let index = 0; index < command.length; index += 1) {
    const character = command[index];
    if (quote === "'") {
      if (character === "'") quote = null;
      continue;
    }
    if (character === "\\") {
      index += 1;
      continue;
    }
    if (character === "'" && quote === null) {
      quote = character;
      continue;
    }
    if (character === '"') {
      quote = quote === '"' ? null : '"';
      continue;
    }

    const commandSubstitution = character === "$" && command[index + 1] === "(";
    const arithmeticSubstitution = commandSubstitution && command[index + 2] === "(";
    const processSubstitution = quote === null
      && (character === "<" || character === ">")
      && command[index + 1] === "(";
    if (commandSubstitution || processSubstitution) {
      const parsed = parenthesizedPayload(command, index + 1);
      if (parsed !== null) {
        if (arithmeticSubstitution) payloads.push(...shellSubstitutionPayloads(parsed.payload));
        else payloads.push(parsed.payload);
        index = parsed.endIndex;
      }
      continue;
    }
    if (character === "`") {
      const parsed = backtickPayload(command, index);
      if (parsed !== null) {
        payloads.push(parsed.payload);
        index = parsed.endIndex;
      }
    }
  }
  return payloads;
}

function splitHeredocs(command) {
  const shell = [];
  const bodies = [];
  let delimiter = null;
  let body = [];
  for (const line of command.split("\n")) {
    if (delimiter !== null) {
      if (line.trim() === delimiter) {
        bodies.push(body.join("\n"));
        body = [];
        delimiter = null;
        shell.push(line);
      } else {
        body.push(line);
      }
      continue;
    }
    shell.push(line);
    const match = line.match(/<<-?\s*(?:'([^']+)'|"([^"]+)"|\\?([A-Za-z_][A-Za-z0-9_]*))/);
    if (match) delimiter = match[1] ?? match[2] ?? match[3];
  }
  if (body.length > 0) bodies.push(body.join("\n"));
  return { shell: shell.join("\n"), bodies };
}

function isWindowsAbsolutePath(value) {
  return /^[A-Za-z]:[\\/]/.test(value) || /^\\\\[^\\/]+[\\/][^\\/]+/.test(value);
}

function isAbsoluteFilesystemPath(value) {
  return path.posix.isAbsolute(value) || isWindowsAbsolutePath(value);
}

function isUrl(value) {
  return /^[A-Za-z][A-Za-z0-9+.-]*:\/\//.test(value);
}

function isExecutablePosition(tokens, index) {
  if (index === 0) return true;
  const previous = tokens[index - 1]?.value ?? "";
  return /^(?:&&|\|\||\||;|\n|then|do|elif|else|if|while|until|!)$/.test(previous);
}

function commandSegmentStart(tokens, index) {
  let start = 0;
  for (let cursor = index - 1; cursor >= 0; cursor -= 1) {
    if (/^(?:&&|\|\||\||;|\n)$/.test(tokens[cursor].value)) {
      start = cursor + 1;
      break;
    }
  }
  while (["!", "if", "then", "do", "elif", "else", "while", "until"].includes(tokens[start]?.value)) start += 1;
  return start;
}

function commandInvocationIndex(tokens, candidateIndex) {
  let cursor = commandSegmentStart(tokens, candidateIndex);
  while (/^[A-Za-z_][A-Za-z0-9_]*=.*/.test(tokens[cursor]?.value ?? "")) cursor += 1;

  for (let depth = 0; depth < 8 && cursor < tokens.length; depth += 1) {
    const wrapperIndex = cursor;
    const wrapper = shellBasename(tokens[cursor].value);
    if (wrapper === "command") {
      cursor += 1;
      let lookupOnly = false;
      while (cursor < tokens.length && tokens[cursor].value.startsWith("-")) {
        const option = tokens[cursor].value;
        cursor += 1;
        if (option === "--") break;
        if (/^-[^-]*[vV]/.test(option)) lookupOnly = true;
      }
      if (lookupOnly || cursor >= tokens.length) return wrapperIndex;
      continue;
    }
    if (wrapper === "env") {
      cursor += 1;
      let terminalOption = false;
      while (cursor < tokens.length) {
        const option = tokens[cursor].value;
        if (option === "--") {
          cursor += 1;
          break;
        }
        if (/^[A-Za-z_][A-Za-z0-9_]*=.*/.test(option)) {
          cursor += 1;
          continue;
        }
        if (!option.startsWith("-") || option === "-") break;
        cursor += 1;
        if (["--help", "--version"].includes(option)) terminalOption = true;
        if (["-u", "--unset", "-C", "--chdir", "-S", "--split-string", "-a", "--argv0"].includes(option)) cursor += 1;
      }
      if (terminalOption || cursor >= tokens.length) return wrapperIndex;
      continue;
    }
    if (wrapper === "nice") {
      cursor += 1;
      let terminalOption = false;
      while (cursor < tokens.length && tokens[cursor].value.startsWith("-")) {
        const option = tokens[cursor].value;
        cursor += 1;
        if (option === "--") break;
        if (["--help", "--version"].includes(option)) terminalOption = true;
        if (["-n", "--adjustment"].includes(option)) cursor += 1;
      }
      if (terminalOption || cursor >= tokens.length) return wrapperIndex;
      continue;
    }
    if (wrapper === "nohup") {
      cursor += 1;
      if (tokens[cursor]?.value === "--") cursor += 1;
      else if (tokens[cursor]?.value?.startsWith("-")) return wrapperIndex;
      if (cursor >= tokens.length) return wrapperIndex;
      continue;
    }
    return cursor;
  }
  return cursor;
}

function isCommandInvocationPosition(tokens, index) {
  return commandInvocationIndex(tokens, index) === index;
}

function executedGitCommands(command, depth = 0) {
  if (depth > 3) return [];
  const observed = [];
  const heredoc = splitHeredocs(command);
  const wrapperTokens = commandTokens(heredoc.shell);

  for (let index = 0; index < wrapperTokens.length; index += 1) {
    if (!isCommandInvocationPosition(wrapperTokens, index)) continue;
    if (!new Set(["sh", "bash", "zsh", "dash", "ksh"]).has(shellBasename(wrapperTokens[index].value))) continue;
    const optionIndex = index + 1;
    const payloadIndex = index + 2;
    if (!/^-+[A-Za-z]*c[A-Za-z]*$/.test(wrapperTokens[optionIndex]?.value ?? "") || wrapperTokens[payloadIndex] === undefined) continue;
    observed.push(...executedGitCommands(wrapperTokens[payloadIndex].value, depth + 1));
  }

  for (const payload of shellSubstitutionPayloads(heredoc.shell)) {
    observed.push(...executedGitCommands(payload, depth + 1));
  }

  const tokens = commandTokens(heredoc.shell);
  for (let index = 0; index < tokens.length; index += 1) {
    if (shellBasename(tokens[index].value) !== "git") continue;
    if (isCommandInvocationPosition(tokens, index)) observed.push(tokens[index].value);
  }
  return observed;
}

function looksLikeLiteralPath(value) {
  if (/[$`{}*?\[\]|^]/.test(value)) return false;
  if (path.posix.isAbsolute(value)) return value !== "/" && !/[\\\s]/.test(value);
  if (isWindowsAbsolutePath(value)) return !/[\s]/.test(value);
  return true;
}

function shellBasename(value) {
  return value.replace(/\\/g, "/").split("/").pop()?.toLowerCase() ?? "";
}

function heredocAbsoluteFilesystemOperands(body) {
  return quotedAbsoluteFilesystemLiterals(body).map(literal => literal.value);
}

function quotedAbsoluteFilesystemLiterals(body) {
  const literals = [];
  const quoted = /(['"])((?:\\.|(?!\1).)*)\1/gs;
  for (const match of body.matchAll(quoted)) {
    const value = match[2];
    if (!isAbsoluteFilesystemPath(value) || !looksLikeLiteralPath(value)) continue;
    const remainder = body.slice(match.index + match[0].length).trimStart();
    if ((value.includes("|") || value.endsWith("/")) && !/^(?:\)|\]|\}|,|\.\w+\s*\()/.test(remainder)) continue;
    literals.push({ value, index: match.index, endIndex: match.index + match[0].length });
  }
  return literals;
}

function interpreterInlineCodeOptions(executable) {
  if (/^python(?:3(?:\.\d+)*)?$/.test(executable)) return { short: "-c", long: [] };
  if (executable === "node") return { short: "-e", long: ["--eval"] };
  if (["ruby", "perl"].includes(executable)) return { short: "-e", long: [] };
  if (executable === "php") return { short: "-r", long: [] };
  return null;
}

function inlineInterpreterCodePayloads(command, depth = 0) {
  if (depth > 3) return [];
  const payloads = [];
  const heredoc = splitHeredocs(command);
  const tokens = commandTokens(heredoc.shell);

  for (let index = 0; index < tokens.length; index += 1) {
    if (!isCommandInvocationPosition(tokens, index)) continue;
    if (!new Set(["sh", "bash", "zsh", "dash", "ksh"]).has(shellBasename(tokens[index].value))) continue;
    const optionIndex = index + 1;
    const payloadIndex = index + 2;
    if (!/^-+[A-Za-z]*c[A-Za-z]*$/.test(tokens[optionIndex]?.value ?? "") || tokens[payloadIndex] === undefined) continue;
    payloads.push(...inlineInterpreterCodePayloads(tokens[payloadIndex].value, depth + 1));
  }

  for (const payload of shellSubstitutionPayloads(heredoc.shell)) {
    payloads.push(...inlineInterpreterCodePayloads(payload, depth + 1));
  }

  for (let index = 0; index < tokens.length; index += 1) {
    if (!isCommandInvocationPosition(tokens, index)) continue;
    const options = interpreterInlineCodeOptions(shellBasename(tokens[index].value));
    if (options === null) continue;
    for (let cursor = index + 1; cursor < tokens.length; cursor += 1) {
      const value = tokens[cursor].value;
      if (/^(?:&&|\|\||\||;|\n)$/.test(value) || value === "--") break;
      if (value === options.short || options.long.includes(value)) {
        if (tokens[cursor + 1] !== undefined) payloads.push(tokens[cursor + 1].value);
        break;
      }
      const long = options.long.find(option => value.startsWith(`${option}=`));
      if (long !== undefined) {
        payloads.push(value.slice(long.length + 1));
        break;
      }
      if (value.startsWith(options.short) && value.length > options.short.length) {
        payloads.push(value.slice(options.short.length));
        break;
      }
    }
  }
  return payloads;
}

function literalAbsoluteFilesystemOperands(command, depth = 0) {
  if (depth > 2) return [];
  const heredoc = splitHeredocs(command);
  const tokens = shellTokens(heredoc.shell);
  const operands = heredoc.bodies.flatMap(heredocAbsoluteFilesystemOperands);
  // Inline interpreter code is opaque here. Conservatively treat every literal
  // absolute path as an operand rather than infer whether the program reads it.
  operands.push(...inlineInterpreterCodePayloads(heredoc.shell)
    .flatMap(payload => quotedAbsoluteFilesystemLiterals(payload).map(literal => literal.value)));
  const nestedPayloadIndexes = new Set();

  for (let index = 0; index < tokens.length; index += 1) {
    if (!isExecutablePosition(tokens, index)) continue;
    if (!new Set(["sh", "bash", "zsh", "dash", "ksh"]).has(shellBasename(tokens[index].value))) continue;
    const optionIndex = index + 1;
    const payloadIndex = index + 2;
    if (!/^-+[A-Za-z]*c[A-Za-z]*$/.test(tokens[optionIndex]?.value ?? "") || tokens[payloadIndex] === undefined) continue;
    nestedPayloadIndexes.add(payloadIndex);
    operands.push(...literalAbsoluteFilesystemOperands(tokens[payloadIndex].value, depth + 1));
  }

  for (let index = 0; index < tokens.length; index += 1) {
    const rawToken = tokens[index].value;
    if (nestedPayloadIndexes.has(index)) continue;
    const token = tokens[index].value.replace(/^[()]+|[(),;]+$/g, "");
    const candidates = [];
    if (token.startsWith("file://")) candidates.push(token.slice("file://".length));
    else if (!isUrl(token)) {
      if (isAbsoluteFilesystemPath(token)) candidates.push(token);
      if (token.includes("=")) {
        const value = token.slice(token.indexOf("=") + 1);
        if (isAbsoluteFilesystemPath(value)) candidates.push(value);
      }
      const redirect = token.match(/^\d*(?:>>?|<<?)(\/.+|[A-Za-z]:[\\/].+)$/);
      if (redirect) candidates.push(redirect[1]);
    }

    for (const value of [...new Set(candidates)]) {
      if (!looksLikeLiteralPath(value)) continue;
      if (value === token && isExecutablePosition(tokens, index)) continue;
      if (value === "/dev/null" && /(?:^|\s)(?:\d*(?:>>?|<<?)|&>)\s*\/?dev\/null(?=\s|$|[;&|)])/.test(command)) continue;
      operands.push(value);
    }
  }
  return [...new Set(operands)];
}

function absoluteOperandInsideRunRoot(operand) {
  if (path.posix.isAbsolute(operand)) return isInsideRunRoot(path.resolve(operand));
  if (isWindowsAbsolutePath(operand)) {
    if (process.platform !== "win32") return false;
    const resolved = path.win32.resolve(operand);
    const root = path.win32.resolve(runRoot);
    return resolved.toLowerCase() === root.toLowerCase()
      || resolved.toLowerCase().startsWith(`${root.toLowerCase()}${path.win32.sep}`);
  }
  return false;
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
  if (item?.type === "command_execution") commandExecutionEventCount += 1;
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

  const gitCommands = executedGitCommands(command);
  if (gitCommands.length > 0) {
    gitCommandEvents.push({ command, exitCode: item.exit_code ?? null });
    reasons.push("Git command executed without proof of read isolation from repository and configuration metadata");
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

  const absoluteFilesystemOperands = literalAbsoluteFilesystemOperands(command);
  if (absoluteFilesystemOperands.some(operand => !absoluteOperandInsideRunRoot(operand))) {
    reasons.push("absolute filesystem path outside run root observed");
  }

  for (const relative of commandSkillPaths(command)) {
    observedSkillPaths.add(relative);
    const output = typeof item.aggregated_output === "string" ? item.aggregated_output : "";
    if (!skillOutputs.has(relative)) skillOutputs.set(relative, []);
    skillOutputs.get(relative).push(output);
    if (expectedRelative === relative && expectedLoadIndex === null) expectedLoadIndex = index;
  }
}

if (commandExecutionEventCount > 0) {
  reasons.push("command execution lacks recorded trusted filesystem, environment, and network isolation evidence");
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
  schemaVersion: 3,
  mode,
  eligible: uniqueReasons.length === 0,
  reasons: uniqueReasons,
  warnings: [...new Set(warnings)],
  eventCount,
  commandCount: commands.length,
  commandExecutionEventCount,
  isolationEvidence: {
    required: commandExecutionEventCount > 0,
    status: commandExecutionEventCount > 0 ? "not_recorded" : "not_required",
    trusted: false,
  },
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
  gitExecution: {
    observed: gitCommandEvents.length > 0,
    commandCount: gitCommandEvents.length,
    readIsolationProven: gitCommandEvents.length > 0 ? false : null,
  },
  usage,
};

process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
if (!result.eligible) process.exit(1);
