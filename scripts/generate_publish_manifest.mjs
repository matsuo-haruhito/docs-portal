import fs from "node:fs";
import path from "node:path";

function parseArgs(argv) {
  const args = {};

  for (let i = 0; i < argv.length; i += 1) {
    const key = argv[i];
    const value = argv[i + 1];

    if (!key.startsWith("--")) {
      throw new Error(`Unexpected argument: ${key}`);
    }

    args[key.slice(2)] = value;
    i += 1;
  }

  return args;
}

function readJson(jsonPath) {
  return JSON.parse(fs.readFileSync(jsonPath, "utf8"));
}

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function fileSizeOrThrow(filePath) {
  return fs.statSync(filePath).size;
}

function normalizeDocument(doc, rootDir) {
  const publish = doc.publish ?? doc.status === "published";
  if (!publish) {
    return null;
  }

  const normalizedFiles = (doc.files ?? []).map((file) => {
    const sourceRelativePath = file.source_path ?? path.posix.join("attachments", file.storage_key);
    const sourcePath = path.join(rootDir, sourceRelativePath);

    if (!fs.existsSync(sourcePath)) {
      throw new Error(`Attachment not found: ${sourceRelativePath}`);
    }

    return {
      file_name: file.file_name,
      content_type: file.content_type,
      storage_key: file.storage_key,
      file_size: file.file_size ?? fileSizeOrThrow(sourcePath)
    };
  });

  if (doc.site_build_path) {
    const buildRoot = path.join(rootDir, "docusaurus", "build");
    const sitePath = path.join(buildRoot, doc.site_build_path);
    const siteIndexPath = path.join(sitePath, "index.html");

    if (!fs.existsSync(buildRoot)) {
      throw new Error("Docusaurus build directory not found: docusaurus/build");
    }

    if (!fs.existsSync(sitePath)) {
      throw new Error(`Site build path not found: docusaurus/build/${doc.site_build_path}`);
    }

    if (!fs.existsSync(siteIndexPath)) {
      throw new Error(`Site entry page not found: docusaurus/build/${doc.site_build_path}/index.html`);
    }
  }

  return {
    project_code: doc.project_code,
    slug: doc.slug,
    title: doc.title,
    category: doc.category,
    document_kind: doc.document_kind,
    visibility_policy: doc.visibility_policy,
    version_label: doc.version_label,
    status: doc.status,
    changelog_summary: doc.changelog_summary ?? null,
    published_at: doc.published_at ?? null,
    markdown_entry_path: doc.markdown_entry_path ?? null,
    site_build_path: doc.site_build_path ?? null,
    pdf_snapshot_path: doc.pdf_snapshot_path ?? null,
    files: normalizedFiles
  };
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const rootDir = process.cwd();
  const configPath = path.resolve(rootDir, args.config);
  const outputPath = path.resolve(rootDir, args.output);
  const config = readJson(configPath);

  const documents = (config.documents ?? [])
    .map((doc) => normalizeDocument(doc, rootDir))
    .filter(Boolean);

  const manifest = {
    source_repo: args.repository,
    source_branch: args.branch,
    source_commit_hash: args.sha,
    documents
  };

  ensureDir(path.dirname(outputPath));
  fs.writeFileSync(outputPath, `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
  process.stdout.write(`Generated ${outputPath}\n`);
}

main();
