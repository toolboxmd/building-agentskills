#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

function fail(message) {
  console.error(`FAIL: ${message}`);
  process.exit(2);
}

if (process.argv.length !== 4) {
  fail("usage: audit-codex-events.mjs <events.jsonl> <run-root>");
}

const eventsPath = path.resolve(process.argv[2]);
const runRoot = path.resolve(process.argv[3]);
if (!fs.existsSync(eventsPath)) fail(`events file not found: ${eventsPath}`);
if (!fs.existsSync(runRoot) || !fs.statSync(runRoot).isDirectory()) fail(`run root not found: ${runRoot}`);

const reasons = [];
const commands = [];
const usage = {
  inputTokens: null,
  cachedInputTokens: null,
  outputTokens: null,
};

const lines = fs.readFileSync(eventsPath, "utf8").split(/\r?\n/).filter(Boolean);
for (let index = 0; index < lines.length; index += 1) {
  let event;
  try {
    event = JSON.parse(lines[index]);
  } catch (error) {
    reasons.push(`invalid JSONL at line ${index + 1}`);
    continue;
  }

  if (event.type === "turn.completed" && event.usage) {
    usage.inputTokens = event.usage.input_tokens ?? null;
    usage.cachedInputTokens = event.usage.cached_input_tokens ?? null;
    usage.outputTokens = event.usage.output_tokens ?? null;
  }

  const item = event.item;
  if (!item || item.type !== "command_execution" || typeof item.command !== "string") continue;

  const command = item.command;
  commands.push(command);

  if (/(^|[\s"'])(codex|claude|gemini|grok)([\s"']|$)/i.test(command)) {
    reasons.push("nested model or agentic CLI command observed");
  }
  if (/(^|[\s"'])(curl|wget)([\s"']|$)|\b(?:git|gh)\s+(?:clone|fetch|pull|api)\b/i.test(command)) {
    reasons.push("network-capable command observed");
  }
  const commandWithoutAllowedAncestorTargets = command.replace(
    /(?:\.\.\/)+(?:visible-inputs|downstream-inputs|creator|output|downstream-output)(?:\/[A-Za-z0-9._~+\/-]*)?/g,
    "<allowed-run-target>",
  );
  if (/(^|[\s"'(])\.\.\//.test(commandWithoutAllowedAncestorTargets)) {
    reasons.push("parent-directory traversal observed");
  }

  const absoluteUserPaths = command.match(/\/Users\/[A-Za-z0-9._-]+(?:\/[A-Za-z0-9._~+\/-]+)+/g) ?? [];
  for (const rawPath of absoluteUserPaths) {
    const candidate = rawPath.replace(/[),;:]+$/, "");
    if (candidate !== runRoot && !candidate.startsWith(`${runRoot}${path.sep}`)) {
      reasons.push("absolute user path outside run root observed");
      break;
    }
  }
}

const uniqueReasons = [...new Set(reasons)];
const result = {
  schemaVersion: 1,
  eligible: uniqueReasons.length === 0,
  reasons: uniqueReasons,
  eventCount: lines.length,
  commandCount: commands.length,
  usage,
};

process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
if (!result.eligible) process.exit(1);
