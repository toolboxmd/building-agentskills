#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

function fail(message) {
  console.error(`FAIL: ${message}`);
  process.exit(2);
}

if (process.argv.length !== 5) {
  fail("usage: verify-run-boundary.mjs <input-manifest.json> <run-root> <allowed-new-prefix>");
}

const manifestPath = path.resolve(process.argv[2]);
const runRoot = path.resolve(process.argv[3]);
const allowedPrefix = process.argv[4].replace(/^\.\//, "").replace(/\/+$/, "");
if (!allowedPrefix || allowedPrefix === "." || allowedPrefix.startsWith("../")) {
  fail(`invalid allowed-new-prefix: ${process.argv[4]}`);
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
if (!Array.isArray(manifest.files)) fail("input manifest has no files array");
if (!fs.existsSync(runRoot) || !fs.statSync(runRoot).isDirectory()) fail(`run root not found: ${runRoot}`);

const reasons = [];
const originalFiles = new Map(manifest.files.map(file => [file.path, file]));
const currentFiles = [];

function walk(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const absolute = path.join(directory, entry.name);
    const relative = path.relative(runRoot, absolute).split(path.sep).join("/");
    if (entry.isSymbolicLink()) {
      reasons.push(`symbolic link created or retained: ${relative}`);
    } else if (entry.isDirectory()) {
      walk(absolute);
    } else if (entry.isFile()) {
      currentFiles.push(relative);
    } else {
      reasons.push(`unsupported filesystem entry: ${relative}`);
    }
  }
}

walk(runRoot);

for (const [relative, expected] of originalFiles) {
  const absolute = path.join(runRoot, relative);
  if (!fs.existsSync(absolute) || !fs.statSync(absolute).isFile()) {
    reasons.push(`protected file missing: ${relative}`);
    continue;
  }
  const contents = fs.readFileSync(absolute);
  const sha256 = crypto.createHash("sha256").update(contents).digest("hex");
  if (sha256 !== expected.sha256 || contents.length !== expected.bytes) {
    reasons.push(`protected file changed: ${relative}`);
  }
}

const newFiles = currentFiles
  .filter(relative => !originalFiles.has(relative))
  .filter(relative => !relative.startsWith(".tmp/"));

for (const relative of newFiles) {
  if (relative !== allowedPrefix && !relative.startsWith(`${allowedPrefix}/`)) {
    reasons.push(`new file outside allowed prefix: ${relative}`);
  }
}

const uniqueReasons = [...new Set(reasons)];
const result = {
  schemaVersion: 1,
  eligible: uniqueReasons.length === 0,
  allowedNewPrefix: allowedPrefix,
  protectedFileCount: originalFiles.size,
  newFiles: newFiles.sort(),
  reasons: uniqueReasons,
};

process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
if (!result.eligible) process.exit(1);
