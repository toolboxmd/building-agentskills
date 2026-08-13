#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

function fail(message) {
  console.error(`FAIL: ${message}`);
  process.exit(2);
}

if (process.argv.length !== 3) fail("usage: inspect-skill-package.mjs <skill-directory>");
const root = path.resolve(process.argv[2]);
if (!fs.existsSync(root) || !fs.statSync(root).isDirectory()) fail(`skill directory not found: ${root}`);
const skillPath = path.join(root, "SKILL.md");
if (!fs.existsSync(skillPath) || !fs.statSync(skillPath).isFile()) fail(`SKILL.md not found: ${skillPath}`);

const files = [];
function walk(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const absolute = path.join(directory, entry.name);
    if (entry.isSymbolicLink()) fail(`symbolic link is not allowed: ${absolute}`);
    if (entry.isDirectory()) walk(absolute);
    else if (entry.isFile()) {
      const contents = fs.readFileSync(absolute);
      files.push({
        path: path.relative(root, absolute).split(path.sep).join("/"),
        bytes: contents.length,
        sha256: crypto.createHash("sha256").update(contents).digest("hex"),
      });
    }
  }
}
walk(root);
files.sort((left, right) => left.path < right.path ? -1 : left.path > right.path ? 1 : 0);

const aggregateSha256 = crypto.createHash("sha256")
  .update(files.map(file => `${file.sha256}  ${file.path}\n`).join(""))
  .digest("hex");
const skillText = fs.readFileSync(skillPath, "utf8");
const frontmatter = skillText.match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/)?.[1] ?? "";
const frontmatterLines = frontmatter.split(/\r?\n/);
let description = "";
for (let index = 0; index < frontmatterLines.length; index += 1) {
  const match = frontmatterLines[index].match(/^description:\s*(.*)$/);
  if (!match) continue;
  const value = match[1].trim();
  if (value === "|" || value === ">" || value === "|-" || value === ">-") {
    const parts = [];
    for (let next = index + 1; next < frontmatterLines.length; next += 1) {
      if (!/^\s+/.test(frontmatterLines[next])) break;
      parts.push(frontmatterLines[next].trim());
    }
    description = parts.join(value.startsWith(">") ? " " : "\n").trim();
  } else {
    description = value.replace(/^['"]|['"]$/g, "");
  }
  break;
}

const result = {
  schemaVersion: 1,
  aggregateSha256,
  fileCount: files.length,
  packageBytes: files.reduce((sum, file) => sum + file.bytes, 0),
  referenceFileCount: files.filter(file => file.path.startsWith("references/")).length,
  scriptFileCount: files.filter(file => file.path.startsWith("scripts/")).length,
  evalFileCount: files.filter(file => file.path.startsWith("evals/")).length,
  skillMd: {
    bytes: Buffer.byteLength(skillText),
    lines: skillText.split(/\r?\n/).length - (skillText.endsWith("\n") ? 1 : 0),
    words: (skillText.match(/[\p{L}\p{N}]+(?:[-'][\p{L}\p{N}]+)*/gu) ?? []).length,
    descriptionCharacters: [...description].length,
  },
  files,
};

process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
