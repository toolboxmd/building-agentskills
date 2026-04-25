import fs from "node:fs";
import path from "node:path";

type DocsConfig = {
  navigation: { groups: Array<{ group: string; pages: string[] }> };
};

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

  const slugs = docs.navigation.groups.flatMap(g => g.pages);
  const llms = fs.readFileSync(llmsPath, "utf8");

  const missing = slugs.filter(slug => !llms.includes(slug));
  if (missing.length > 0) {
    console.error(`Missing pages in llms.txt: ${missing.join(", ")}`);
    process.exit(1);
  }

  console.log(`all ${slugs.length} pages covered`);
}

main();
