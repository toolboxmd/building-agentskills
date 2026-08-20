#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

function fail(message) {
  console.error(`FAIL: ${message}`);
  process.exit(1);
}

if (process.argv.length !== 3) {
  fail("usage: hash-tree.mjs <directory>");
}

const root = path.resolve(process.argv[2]);
if (!fs.existsSync(root) || !fs.statSync(root).isDirectory()) {
  fail(`not a directory: ${process.argv[2]}`);
}

const paths = [];

function walk(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const absolute = path.join(directory, entry.name);
    if (entry.isSymbolicLink()) {
      fail(`symbolic links are not supported: ${path.relative(root, absolute)}`);
    }
    if (entry.isDirectory()) {
      walk(absolute);
    } else if (entry.isFile()) {
      paths.push(absolute);
    }
  }
}

walk(root);

const files = paths
  .map(absolute => {
    const contents = fs.readFileSync(absolute);
    return {
      path: path.relative(root, absolute).split(path.sep).join("/"),
      bytes: contents.length,
      sha256: crypto.createHash("sha256").update(contents).digest("hex"),
    };
  })
  .sort((a, b) => a.path < b.path ? -1 : a.path > b.path ? 1 : 0);

const manifestBytes = files
  .map(file => `${file.sha256}  ${file.path}\n`)
  .join("");

const result = {
  algorithm: "SHA-256 of lines '<file-sha256>  <relative-path>\\n' with entries sorted by relative path",
  aggregateSha256: crypto.createHash("sha256").update(manifestBytes).digest("hex"),
  files,
};

process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
