#!/usr/bin/env node

import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

function usageError(message) {
  console.error(`FAIL: ${message}`);
  process.exit(2);
}

if (process.argv.length !== 5) {
  usageError("usage: grade-toolboxmd-case.mjs <deterministic-contract.json> <run-root> <events.jsonl>");
}

const contractPath = path.resolve(process.argv[2]);
const runRoot = path.resolve(process.argv[3]);
const eventsPath = path.resolve(process.argv[4]);
const contract = JSON.parse(fs.readFileSync(contractPath, "utf8"));
const checks = [];

function record(id, passed, detail) {
  checks.push({ id, passed: Boolean(passed), detail });
}

function runPath(relative) {
  return path.join(runRoot, relative);
}

function existsFile(relative) {
  const absolute = runPath(relative);
  return fs.existsSync(absolute) && fs.statSync(absolute).isFile();
}

function readText(relative) {
  return fs.readFileSync(runPath(relative), "utf8");
}

function includesInsensitive(text, term) {
  return text.toLocaleLowerCase("en-US").includes(term.toLocaleLowerCase("en-US"));
}

function includesUnnegatedInsensitive(text, term) {
  const normalizedText = text.toLocaleLowerCase("en-US");
  const normalizedTerm = term.toLocaleLowerCase("en-US");
  let offset = 0;
  while (offset < normalizedText.length) {
    const index = normalizedText.indexOf(normalizedTerm, offset);
    if (index === -1) return false;
    const prefix = normalizedText.slice(Math.max(0, index - 24), index);
    if (!/(?:do not|don't|must not|never|no)\s*$/.test(prefix)) return true;
    offset = index + normalizedTerm.length;
  }
  return false;
}

function sha256(contents) {
  return crypto.createHash("sha256").update(contents).digest("hex");
}

function deepEqual(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

function gradeWebhook() {
  const relative = contract.downstream.requiredFile;
  const present = existsFile(relative);
  record("required-output", present, relative);
  if (!present) return;

  const text = readText(relative);
  for (const label of contract.downstream.requiredLabels) {
    record(`label:${label}`, includesInsensitive(text, label), label);
  }
  for (const term of contract.downstream.requiredCaseInsensitiveTerms) {
    record(`required-term:${term}`, includesInsensitive(text, term), term);
  }
  for (const alternatives of contract.downstream.requiredAnyCaseInsensitiveTerms) {
    record(
      `required-any:${alternatives.join("|")}`,
      alternatives.some(term => includesInsensitive(text, term)),
      alternatives.join(" | "),
    );
  }
  for (const term of contract.downstream.forbiddenCaseInsensitiveTerms) {
    record(`forbidden-term:${term}`, !includesUnnegatedInsensitive(text, term), term);
  }
  const observedRuleIds = [...new Set(text.match(/\bNSR-[A-Z]+-[0-9]+\b/g) ?? [])].sort();
  const unknownRuleIds = observedRuleIds.filter(id => !contract.downstream.allowedRuleIdentifiers.includes(id));
  record("known-rule-identifiers", unknownRuleIds.length === 0, unknownRuleIds.join(", ") || "all rule identifiers are allowed");
  record("selected-rule", observedRuleIds.includes(contract.downstream.selectedRule), contract.downstream.selectedRule);
  record("selected-classification", includesInsensitive(text, contract.downstream.selectedClassification), contract.downstream.selectedClassification);
  record("selected-priority", includesInsensitive(text, contract.downstream.selectedPriority), contract.downstream.selectedPriority);
  record("missing-fact", includesInsensitive(text, contract.downstream.missingFact), contract.downstream.missingFact);
}

function gradeCsv() {
  const downstream = contract.downstream;
  for (const relative of downstream.requiredFiles) {
    record(`required-file:${relative}`, existsFile(relative), relative);
  }
  for (const relative of downstream.forbiddenFiles) {
    record(`forbidden-file:${relative}`, !fs.existsSync(runPath(relative)), relative);
  }

  for (const [left, right] of downstream.byteEqualityPairs) {
    const comparable = existsFile(left) && existsFile(right);
    const equal = comparable && fs.readFileSync(runPath(left)).equals(fs.readFileSync(runPath(right)));
    record(`byte-equality:${left}:${right}`, equal, comparable ? `${left} equals ${right}: ${equal}` : "one or both files are missing");
  }

  for (const relative of ["downstream-output/customers-sanitized.csv", "downstream-output/customers-sanitized-second.csv"]) {
    const exact = existsFile(relative) && readText(relative) === downstream.expectedCsvText;
    record(`exact-csv:${relative}`, exact, relative);
  }

  const inputBytes = fs.readFileSync(runPath(downstream.hashChecks.input_sha256Source));
  const inputHash = sha256(inputBytes);
  const auditPairs = [
    ["downstream-output/customers-audit.json", "downstream-output/customers-sanitized.csv"],
    ["downstream-output/customers-audit-second.json", "downstream-output/customers-sanitized-second.csv"],
  ];
  for (const [auditRelative, outputRelative] of auditPairs) {
    if (!existsFile(auditRelative) || !existsFile(outputRelative)) {
      record(`audit:${auditRelative}`, false, "audit or output is missing");
      continue;
    }
    let audit;
    try {
      audit = JSON.parse(readText(auditRelative));
    } catch (error) {
      record(`audit-json:${auditRelative}`, false, error.message);
      continue;
    }
    const outputHash = sha256(fs.readFileSync(runPath(outputRelative)));
    const keysMatch = deepEqual(Object.keys(audit), downstream.auditKeyOrder);
    const expectedValuesMatch = Object.entries(downstream.expectedAuditValues)
      .every(([key, value]) => deepEqual(audit[key], value));
    record(`audit-key-order:${auditRelative}`, keysMatch, Object.keys(audit).join(", "));
    record(`audit-values:${auditRelative}`, expectedValuesMatch, auditRelative);
    record(`audit-input-hash:${auditRelative}`, audit.input_sha256 === inputHash, audit.input_sha256 ?? "missing");
    record(`audit-output-hash:${auditRelative}`, audit.output_sha256 === outputHash, audit.output_sha256 ?? "missing");
  }

  const finishedCommands = fs.readFileSync(eventsPath, "utf8")
    .split(/\r?\n/)
    .filter(Boolean)
    .map(line => JSON.parse(line))
    .map(event => event.item)
    .filter(item => item?.type === "command_execution" && item.status !== "in_progress" && Number.isInteger(item.exit_code));
  const rejectedRuns = finishedCommands.filter(item => item.command.includes("sanitize_export.py") && item.command.includes("customers-prohibited.csv"));
  record(
    "invalid-invocation-nonzero",
    rejectedRuns.length > 0 && rejectedRuns.every(item => Number.isInteger(item.exit_code) && item.exit_code !== 0),
    rejectedRuns.map(item => item.exit_code).join(", ") || "no prohibited-input invocation found",
  );
}

function gradeRelease() {
  const downstream = contract.downstream;
  const relative = downstream.requiredFile;
  const present = existsFile(relative);
  record("required-output", present, relative);
  if (!present) return;

  const text = readText(relative);
  const headingMatches = [...text.matchAll(/^(#{1,6})\s+(.+?)\s*$/gm)];
  const headings = headingMatches.map(match => match[2]);
  const headingLevels = headingMatches.map(match => match[1].length);
  const consistentLevel = headingLevels.length > 0 && headingLevels.every(level => level === headingLevels[0]);
  record(
    "top-level-headings",
    consistentLevel && deepEqual(headings, downstream.requiredTopLevelHeadings),
    headingMatches.map(match => `${match[1]} ${match[2]}`).join(" | "),
  );

  const releaseStart = headingMatches[0]?.index ?? -1;
  const withheldStart = headingMatches[1]?.index ?? -1;
  const releaseText = releaseStart >= 0 && withheldStart > releaseStart
    ? text.slice(releaseStart, withheldStart)
    : "";
  const withheldText = withheldStart >= 0 ? text.slice(withheldStart) : "";

  for (const id of downstream.requiredReleaseEvidenceIds) {
    record(`release-evidence:${id}`, releaseText.includes(id), id);
  }
  for (const id of downstream.requiredWithheldEvidenceIds) {
    record(`withheld-evidence:${id}`, withheldText.includes(id), id);
  }
  for (const term of downstream.requiredQualifierTerms) {
    record(`qualifier:${term}`, includesInsensitive(releaseText, term), term);
  }
  for (const concept of downstream.requiredSupportedConcepts) {
    record(`supported-concept:${concept}`, includesInsensitive(releaseText, concept), concept);
  }
  for (const claim of downstream.forbiddenReleaseNoteClaimsCaseInsensitive) {
    record(`forbidden-release-claim:${claim}`, !includesInsensitive(releaseText, claim), claim);
  }
  const citationRegex = new RegExp(downstream.citationPattern, "g");
  record("supported-citation-format", citationRegex.test(releaseText), downstream.citationPattern);

  const observedEvidenceIds = [...new Set(text.match(/\b[A-Z]+-HL-[0-9]+\b/g) ?? [])].sort();
  const unknownEvidenceIds = observedEvidenceIds.filter(id => !downstream.knownEvidenceIds.includes(id));
  record("known-evidence-identifiers", unknownEvidenceIds.length === 0, unknownEvidenceIds.join(", ") || "all evidence identifiers are known");
}

switch (contract.caseId) {
  case "webhook-triage":
    gradeWebhook();
    break;
  case "csv-sanitizer":
    gradeCsv();
    break;
  case "release-evidence":
    gradeRelease();
    break;
  default:
    usageError(`unsupported caseId: ${contract.caseId}`);
}

const failedChecks = checks.filter(check => !check.passed);
const result = {
  schemaVersion: 1,
  caseId: contract.caseId,
  passed: failedChecks.length === 0,
  checkCount: checks.length,
  failedCheckCount: failedChecks.length,
  checks,
};

process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
if (!result.passed) process.exit(1);
