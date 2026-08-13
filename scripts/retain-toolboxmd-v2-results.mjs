#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

function fail(message) {
  console.error(`FAIL: ${message}`);
  process.exit(2);
}

if (process.argv.length !== 4) {
  fail("usage: retain-toolboxmd-v2-results.mjs <runtime-root> <result-root>");
}

const runtimeRoot = path.resolve(process.argv[2]);
const resultRoot = path.resolve(process.argv[3]);
if (!fs.existsSync(runtimeRoot) || !fs.statSync(runtimeRoot).isDirectory()) fail(`runtime root not found: ${runtimeRoot}`);
if (fs.existsSync(resultRoot)) fail(`result root already exists: ${resultRoot}`);

function requireFile(value) {
  const resolved = path.resolve(value);
  if (!fs.existsSync(resolved) || !fs.statSync(resolved).isFile()) fail(`required file not found: ${resolved}`);
  return resolved;
}

function requireDirectory(value) {
  const resolved = path.resolve(value);
  if (!fs.existsSync(resolved) || !fs.statSync(resolved).isDirectory()) fail(`required directory not found: ${resolved}`);
  return resolved;
}

function rejectSymlinks(root) {
  function walk(directory) {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      const absolute = path.join(directory, entry.name);
      if (entry.isSymbolicLink()) fail(`symbolic link is not allowed in retained evidence: ${absolute}`);
      if (entry.isDirectory()) walk(absolute);
    }
  }
  walk(root);
}

function copyFile(sourceValue, destinationRelative) {
  const source = requireFile(sourceValue);
  const destination = path.join(resultRoot, destinationRelative);
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.copyFileSync(source, destination, fs.constants.COPYFILE_EXCL);
}

function copyTree(sourceValue, destinationRelative) {
  const source = requireDirectory(sourceValue);
  rejectSymlinks(source);
  const destination = path.join(resultRoot, destinationRelative);
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.cpSync(source, destination, {
    recursive: true,
    force: false,
    errorOnExist: true,
    preserveTimestamps: false,
  });
}

function sha256File(value) {
  return crypto.createHash("sha256").update(fs.readFileSync(value)).digest("hex");
}

function treeManifest(rootValue) {
  const root = requireDirectory(rootValue);
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
  return { aggregateSha256, files };
}

function writeJson(destinationRelative, value) {
  const destination = path.join(resultRoot, destinationRelative);
  fs.mkdirSync(path.dirname(destination), { recursive: true });
  fs.writeFileSync(destination, `${JSON.stringify(value, null, 2)}\n`, { flag: "wx" });
}

function readUsage(runRelative) {
  const evidence = path.join(runtimeRoot, runRelative, "evidence");
  const eventsPath = requireFile(path.join(evidence, "events.jsonl"));
  const metadata = JSON.parse(fs.readFileSync(requireFile(path.join(evidence, "run-metadata.json")), "utf8"));
  let usage = null;
  for (const line of fs.readFileSync(eventsPath, "utf8").split(/\r?\n/).filter(Boolean)) {
    const event = JSON.parse(line);
    if (event.type === "turn.completed" && event.usage) usage = event.usage;
  }
  if (!usage) fail(`turn usage not found: ${eventsPath}`);
  const inputTokens = usage.input_tokens ?? 0;
  const cachedInputTokens = usage.cached_input_tokens ?? 0;
  const outputTokens = usage.output_tokens ?? 0;
  const uncachedInputTokens = Math.max(0, inputTokens - cachedInputTokens);
  return {
    run: runRelative,
    durationSeconds: metadata.durationSeconds,
    inputTokens,
    cachedInputTokens,
    uncachedInputTokens,
    outputTokens,
    runtimeTokens: uncachedInputTokens + outputTokens,
    rawEvents: {
      bytes: fs.statSync(eventsPath).size,
      sha256: sha256File(eventsPath),
    },
  };
}

fs.mkdirSync(path.dirname(resultRoot), { recursive: true });
fs.mkdirSync(resultRoot, { recursive: false });

const primaryCases = ["meeting-followups", "weekly-status-deck"];
const treatments = ["builtin", "toolboxmd"];

for (const relative of [
  "preflight-v2/evidence/event-audit.json",
  "preflight-v2/evidence/boundary-audit.json",
  "preflight-v2/evidence/input-manifest.json",
  "preflight-v2/evidence/final-message.txt",
  "preflight-v2/evidence/events.jsonl",
  "preflight-v2/evidence/stderr.txt",
  "preflight-v2/evidence/run-metadata.json",
]) {
  copyFile(path.join(runtimeRoot, relative), path.join("preflight", path.basename(relative)));
}

for (const caseId of primaryCases) {
  const source = path.join(runtimeRoot, "qualification", caseId);
  copyTree(path.join(source, "run", "output"), path.join("qualification", caseId, "output"));
  for (const name of ["event-audit.json", "boundary-audit.json", "grade.json", "input-manifest.json", "final-message.txt", "events.jsonl", "stderr.txt", "run-metadata.json"]) {
    copyFile(path.join(source, "evidence", name), path.join("qualification", caseId, "evidence", name));
  }
  writeJson(path.join("qualification", caseId, "evidence", "output-manifest.json"), treeManifest(path.join(source, "run", "output")));
}

for (const caseId of primaryCases) {
  for (const treatment of treatments) {
    const authoring = path.join(runtimeRoot, "runs", "authoring-r2", caseId, treatment);
    const downstream = path.join(runtimeRoot, "runs", "downstream", caseId, treatment);
    const destination = path.join("cases", caseId, treatment);
    copyTree(path.join(authoring, "run", "output", caseId), path.join(destination, "skill"));
    copyTree(path.join(downstream, "run", "output"), path.join(destination, "downstream-output"));
    const authoringEvidence = {
      "event-audit.json": "authoring-event-audit.json",
      "boundary-audit.json": "authoring-boundary-audit.json",
      "input-manifest.json": "authoring-input-manifest.json",
      "package-inspection.json": "authoring-package-inspection.json",
      "package-validation.txt": "authoring-package-validation.txt",
      "final-message.txt": "authoring-final-message.txt",
      "events.jsonl": "authoring-events.jsonl",
      "stderr.txt": "authoring-stderr.txt",
      "run-metadata.json": "authoring-run-metadata.json",
    };
    for (const [sourceName, destinationName] of Object.entries(authoringEvidence)) {
      copyFile(path.join(authoring, "evidence", sourceName), path.join(destination, "evidence", destinationName));
    }
    const downstreamEvidence = {
      "event-audit.json": "downstream-event-audit.json",
      "boundary-audit.json": "downstream-boundary-audit.json",
      "input-manifest.json": "downstream-input-manifest.json",
      "grade.json": "downstream-grade.json",
      "output-manifest.json": "downstream-output-manifest.json",
      "final-message.txt": "downstream-final-message.txt",
      "events.jsonl": "downstream-events.jsonl",
      "stderr.txt": "downstream-stderr.txt",
      "run-metadata.json": "downstream-run-metadata.json",
    };
    for (const [sourceName, destinationName] of Object.entries(downstreamEvidence)) {
      copyFile(path.join(downstream, "evidence", sourceName), path.join(destination, "evidence", destinationName));
    }
  }
}

for (const treatment of treatments) {
  const source = path.join(runtimeRoot, "runs", "near-miss", treatment);
  for (const name of ["event-audit.json", "boundary-audit.json", "input-manifest.json", "final-message.txt", "events.jsonl", "stderr.txt", "run-metadata.json"]) {
    copyFile(path.join(source, "evidence", name), path.join("near-miss", treatment, name));
  }
}

const discardedAttempts = [];
for (const caseId of primaryCases) {
  for (const treatment of treatments) {
    const source = path.join(runtimeRoot, "runs", "authoring", caseId, treatment);
    const boundary = JSON.parse(fs.readFileSync(requireFile(path.join(source, "evidence", "boundary-audit.json")), "utf8"));
    const eventPath = requireFile(path.join(source, "evidence", "events.jsonl"));
    const pycPaths = [];
    function findPyc(directory) {
      for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
        const absolute = path.join(directory, entry.name);
        if (entry.isDirectory()) findPyc(absolute);
        else if (entry.isFile() && entry.name.endsWith(".pyc")) {
          pycPaths.push({
            path: path.relative(path.join(source, "run"), absolute).split(path.sep).join("/"),
            bytes: fs.statSync(absolute).size,
            sha256: sha256File(absolute),
          });
        }
      }
    }
    findPyc(path.join(source, "run"));
    discardedAttempts.push({
      caseId,
      treatment,
      batchDisposition: "discarded_before_downstream_for_symmetric_runner_correction",
      boundaryEligible: boundary.eligible,
      boundaryReasons: boundary.reasons,
      pycFiles: pycPaths,
      rawEvents: {
        bytes: fs.statSync(eventPath).size,
        sha256: sha256File(eventPath),
      },
    });
    for (const name of ["event-audit.json", "boundary-audit.json", "input-manifest.json", "final-message.txt", "events.jsonl", "stderr.txt", "run-metadata.json"]) {
      copyFile(
        path.join(source, "evidence", name),
        path.join("discarded-authoring", caseId, treatment, name),
      );
    }
  }
}
writeJson("discarded-authoring/failure.json", {
  schemaVersion: 1,
  reason: "Both built-in attempts wrote Python bytecode under the protected creator tree. The complete four-run batch was discarded before downstream use and repeated symmetrically with bytecode isolation.",
  attempts: discardedAttempts,
});

const usageGroups = {
  qualification: primaryCases.map(caseId => path.join("qualification", caseId)),
  authoringDiscarded: primaryCases.flatMap(caseId => treatments.map(treatment => path.join("runs", "authoring", caseId, treatment))),
  authoringEligible: primaryCases.flatMap(caseId => treatments.map(treatment => path.join("runs", "authoring-r2", caseId, treatment))),
  downstream: primaryCases.flatMap(caseId => treatments.map(treatment => path.join("runs", "downstream", caseId, treatment))),
  nearMiss: treatments.map(treatment => path.join("runs", "near-miss", treatment)),
};

const usage = { schemaVersion: 1, groups: {}, total: null };
const total = {
  sessions: 0,
  durationSeconds: 0,
  inputTokens: 0,
  cachedInputTokens: 0,
  uncachedInputTokens: 0,
  outputTokens: 0,
  runtimeTokens: 0,
};
for (const [group, runPaths] of Object.entries(usageGroups)) {
  const runs = runPaths.map(readUsage);
  const aggregate = {
    sessions: runs.length,
    durationSeconds: 0,
    inputTokens: 0,
    cachedInputTokens: 0,
    uncachedInputTokens: 0,
    outputTokens: 0,
    runtimeTokens: 0,
  };
  for (const run of runs) {
    for (const key of Object.keys(aggregate)) {
      if (key !== "sessions") aggregate[key] += run[key];
    }
  }
  usage.groups[group] = { ...aggregate, runs };
  for (const key of Object.keys(total)) total[key] += aggregate[key];
}
usage.total = total;
writeJson("session-usage.json", usage);

const retainedTree = treeManifest(resultRoot);
writeJson("retention-manifest.json", {
  schemaVersion: 1,
  recordedOn: "2026-08-13",
  excludesSelf: true,
  ...retainedTree,
});

process.stdout.write(`${resultRoot}\n`);
