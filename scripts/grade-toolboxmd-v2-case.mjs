#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

function fail(message) {
  console.error(`FAIL: ${message}`);
  process.exit(2);
}

if (process.argv.length !== 4) {
  fail("usage: grade-toolboxmd-v2-case.mjs <contract.json> <run-root>");
}

const contractPath = path.resolve(process.argv[2]);
const runRoot = path.resolve(process.argv[3]);
if (!fs.existsSync(contractPath) || !fs.statSync(contractPath).isFile()) fail(`contract not found: ${contractPath}`);
if (!fs.existsSync(runRoot) || !fs.statSync(runRoot).isDirectory()) fail(`run root not found: ${runRoot}`);

let contract;
try {
  contract = JSON.parse(fs.readFileSync(contractPath, "utf8"));
} catch (error) {
  fail(`invalid contract JSON: ${error.message}`);
}
if (contract.schemaVersion !== 2 || typeof contract.caseId !== "string" || !Array.isArray(contract.checks)) {
  fail("contract must have schemaVersion 2, caseId, and checks");
}
if (!Array.isArray(contract.criticalCheckIds)) fail("contract must have criticalCheckIds");

const criticalIds = new Set(contract.criticalCheckIds);
const checkIds = new Set();
for (const check of contract.checks) {
  if (!check || typeof check.id !== "string" || typeof check.type !== "string") fail("every check needs id and type");
  if (checkIds.has(check.id)) fail(`duplicate check id: ${check.id}`);
  checkIds.add(check.id);
}
for (const id of criticalIds) {
  if (!checkIds.has(id)) fail(`critical check is not declared: ${id}`);
}

function resolveRunPath(relative) {
  if (typeof relative !== "string" || relative.length === 0 || path.isAbsolute(relative)) fail(`invalid check path: ${relative}`);
  const absolute = path.resolve(runRoot, relative);
  if (absolute !== runRoot && !absolute.startsWith(`${runRoot}${path.sep}`)) fail(`check path escapes run root: ${relative}`);
  return absolute;
}

function readFile(relative) {
  const absolute = resolveRunPath(relative);
  if (!fs.existsSync(absolute) || !fs.statSync(absolute).isFile()) return null;
  return fs.readFileSync(absolute, "utf8");
}

function normalize(value) {
  if (Array.isArray(value)) return value.map(normalize);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.keys(value).sort().map(key => [key, normalize(value[key])]));
  }
  return value;
}

function deepEqual(left, right) {
  return JSON.stringify(normalize(left)) === JSON.stringify(normalize(right));
}

function markdownHeadings(text) {
  return [...text.matchAll(/^#{1,6}\s+(.+?)\s*#*\s*$/gm)].map(match => match[1].trim());
}

function parseFrontmatter(text) {
  const match = text.match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/);
  if (!match) return null;
  const values = {};
  for (const rawLine of match[1].split(/\r?\n/)) {
    if (!rawLine.trim()) continue;
    const separator = rawLine.indexOf(":");
    if (separator < 1) return null;
    const key = rawLine.slice(0, separator).trim();
    let value = rawLine.slice(separator + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    values[key] = value;
  }
  return { values, body: text.slice(match[0].length) };
}

function marpHeadings(text) {
  const parsed = parseFrontmatter(text);
  if (!parsed) return null;
  const slides = parsed.body.split(/^\s*---\s*$/m).map(value => value.trim()).filter(Boolean);
  const headings = [];
  for (const slide of slides) {
    const match = slide.match(/^#\s+(.+?)\s*$/m);
    if (!match) return null;
    headings.push(match[1].trim());
  }
  return headings;
}

const results = [];

for (const check of contract.checks) {
  let passed = false;
  let detail = "";
  const text = typeof check.path === "string" ? readFile(check.path) : null;

  switch (check.type) {
    case "file-exists": {
      const absolute = resolveRunPath(check.path);
      passed = fs.existsSync(absolute) && fs.statSync(absolute).isFile();
      detail = passed ? `${check.path} exists` : `${check.path} is missing`;
      break;
    }
    case "markdown-headings-exact": {
      const observed = text === null ? null : markdownHeadings(text);
      passed = observed !== null && deepEqual(observed, check.headings);
      detail = observed === null ? `${check.path} is missing` : `observed: ${JSON.stringify(observed)}`;
      break;
    }
    case "contains-all": {
      const source = text === null ? null : (check.caseSensitive === false ? text.toLowerCase() : text);
      const missing = text === null
        ? [...check.values]
        : check.values.filter(value => !source.includes(check.caseSensitive === false ? String(value).toLowerCase() : String(value)));
      passed = text !== null && missing.length === 0;
      detail = missing.length === 0 ? "all required values present" : `missing: ${JSON.stringify(missing)}`;
      break;
    }
    case "not-contains": {
      const source = text === null ? null : (check.caseSensitive === false ? text.toLowerCase() : text);
      const observed = text === null
        ? []
        : check.values.filter(value => source.includes(check.caseSensitive === false ? String(value).toLowerCase() : String(value)));
      passed = text !== null && observed.length === 0;
      detail = text === null ? `${check.path} is missing` : observed.length === 0 ? "no forbidden values present" : `observed: ${JSON.stringify(observed)}`;
      break;
    }
    case "exact-text": {
      passed = text !== null && text === check.value;
      detail = text === null ? `${check.path} is missing` : passed ? "text is byte-exact UTF-8" : "text differs";
      break;
    }
    case "json-equals": {
      if (text === null) {
        detail = `${check.path} is missing`;
        break;
      }
      try {
        const observed = JSON.parse(text);
        passed = deepEqual(observed, check.value);
        detail = passed ? "JSON value matches" : `observed: ${JSON.stringify(observed)}`;
      } catch (error) {
        detail = `invalid JSON: ${error.message}`;
      }
      break;
    }
    case "frontmatter-equals": {
      const observed = text === null ? null : parseFrontmatter(text)?.values ?? null;
      passed = observed !== null && deepEqual(observed, check.value);
      detail = observed === null ? "frontmatter missing or malformed" : `observed: ${JSON.stringify(observed)}`;
      break;
    }
    case "marp-slide-headings-exact": {
      const observed = text === null ? null : marpHeadings(text);
      passed = observed !== null && deepEqual(observed, check.headings);
      detail = observed === null ? "Marp slides missing or malformed" : `observed: ${JSON.stringify(observed)}`;
      break;
    }
    default:
      fail(`unsupported check type: ${check.type}`);
  }

  results.push({
    id: check.id,
    type: check.type,
    critical: criticalIds.has(check.id),
    passed,
    detail,
  });
}

const failed = results.filter(check => !check.passed);
const critical = results.filter(check => check.critical);
const result = {
  schemaVersion: 2,
  caseId: contract.caseId,
  passed: failed.length === 0,
  checkCount: results.length,
  passedCheckCount: results.length - failed.length,
  failedCheckCount: failed.length,
  failedCheckIds: failed.map(check => check.id),
  criticalCheckCount: critical.length,
  criticalPassCount: critical.filter(check => check.passed).length,
  criticalFailedCheckIds: critical.filter(check => !check.passed).map(check => check.id),
  checks: results,
};

process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
if (!result.passed) process.exit(1);
