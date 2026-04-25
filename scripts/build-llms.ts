import fs from "node:fs";
import path from "node:path";

const START_MARKER = "<!-- TOOLS:START -->";
const END_MARKER = "<!-- TOOLS:END -->";
const MAX_DESC = 200;

type DocsConfig = {
  navigation: {
    groups: Array<{
      group: string;
      pages: string[];
    }>;
  };
};

function extractTitleAndDescription(slug: string): { title: string; description: string } {
  const filePath = path.join(process.cwd(), `${slug}.md`);
  if (!fs.existsSync(filePath)) {
    console.error(`Missing source file for slug: ${slug} (expected ${filePath})`);
    process.exit(1);
  }
  const lines = fs.readFileSync(filePath, "utf8").split("\n");

  let title = slug;
  let titleIdx = -1;
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].startsWith("# ")) {
      title = lines[i].slice(2).trim();
      titleIdx = i;
      break;
    }
  }

  let description = "";
  if (titleIdx >= 0) {
    const paraLines: string[] = [];
    let started = false;
    for (let i = titleIdx + 1; i < lines.length; i++) {
      const line = lines[i];
      if (!started) {
        if (line.trim() === "") continue;
        const first = line[0];
        // Skip headings (#), blockquotes (>), list bullets (- *), and indented code/lists.
        // YAML frontmatter delimiters (---) are incidentally caught by the "-" skip; this
        // is fine for v0.1 since no docs use frontmatter. If frontmatter parsing is added
        // in v0.2, drop the "-" skip and parse the YAML block explicitly.
        // Edge cases not handled: MDX `import` lines and HTML comments would be captured
        // as descriptions if they appeared as the first prose paragraph; no current doc
        // triggers this.
        if (first === "#" || first === ">" || first === "-" || first === "*" || first === " " || first === "\t") {
          continue;
        }
        started = true;
        paraLines.push(line);
        continue;
      }
      if (line.trim() === "") break;
      paraLines.push(line);
    }
    description = paraLines.join(" ").trim();
  }

  if (description.length > MAX_DESC) {
    description = description.slice(0, MAX_DESC).trimEnd() + "...";
  }

  return { title, description };
}

function formatBody(docs: DocsConfig): { body: string; bulletCount: number } {
  const lines: string[] = [];
  lines.push("(auto-generated; do not edit manually. Run `npm run build:llms`)");
  lines.push("");
  let bulletCount = 0;

  for (const group of docs.navigation.groups) {
    lines.push(`### ${group.group}`);
    lines.push("");
    for (const slug of group.pages) {
      const { title, description } = extractTitleAndDescription(slug);
      if (description.length > 0) {
        lines.push(`- [${title}](${slug}): ${description}`);
      } else {
        lines.push(`- [${title}](${slug})`);
      }
      bulletCount++;
    }
    lines.push("");
  }

  return { body: lines.join("\n").replace(/\n+$/, ""), bulletCount };
}

function main(): void {
  const docsPath = path.join(process.cwd(), "docs.json");
  const llmsPath = path.join(process.cwd(), "public", "llms.txt");

  if (!fs.existsSync(docsPath)) {
    console.error(`Missing ${docsPath}.`);
    process.exit(1);
  }
  if (!fs.existsSync(llmsPath)) {
    console.error(`Missing ${llmsPath}.`);
    process.exit(1);
  }

  let docs: DocsConfig;
  try {
    docs = JSON.parse(fs.readFileSync(docsPath, "utf8")) as DocsConfig;
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`Malformed docs.json: ${message}`);
    process.exit(1);
  }
  const llms = fs.readFileSync(llmsPath, "utf8");

  const start = llms.indexOf(START_MARKER);
  const end = llms.indexOf(END_MARKER);
  if (start < 0 || end < 0 || start > end) {
    console.error(`Missing TOOLS markers in ${llmsPath}`);
    process.exit(1);
  }

  const { body, bulletCount } = formatBody(docs);
  const before = llms.substring(0, start + START_MARKER.length);
  const after = llms.substring(end);
  const newContent = `${before}\n${body}\n${after}`;

  fs.writeFileSync(llmsPath, newContent);
  console.log(`wrote ${bulletCount} bullets`);
}

main();
