import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

const repoRoot = path.resolve(import.meta.dirname, "..", "..");
const scriptPath = path.join(repoRoot, "scripts", "generate_publish_manifest.mjs");

test("generate_publish_manifest writes artifact replay metadata", () => {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "publish-manifest-"));

  fs.mkdirSync(path.join(tmpDir, "publish", "manifest"), { recursive: true });
  fs.mkdirSync(path.join(tmpDir, "docusaurus", "build", "manuals", "ops"), { recursive: true });
  fs.mkdirSync(path.join(tmpDir, "attachments", "manuals"), { recursive: true });

  fs.writeFileSync(path.join(tmpDir, "docusaurus", "build", "manuals", "ops", "index.html"), "<h1>Ops</h1>");
  fs.writeFileSync(path.join(tmpDir, "attachments", "manuals", "ops.pdf"), "pdf");
  fs.writeFileSync(
    path.join(tmpDir, "publish", "documents.json"),
    JSON.stringify({
      documents: [
        {
          project_code: "pj001",
          slug: "ops",
          title: "Ops",
          category: "manual",
          document_kind: "markdown",
          visibility_policy: "restricted_external",
          version_label: "2026-Q2",
          status: "published",
          site_build_path: "manuals/ops",
          files: [
            {
              file_name: "ops.pdf",
              content_type: "application/pdf",
              storage_key: "manuals/ops.pdf"
            }
          ]
        }
      ]
    })
  );

  execFileSync(
    process.execPath,
    [
      scriptPath,
      "--config", "./publish/documents.json",
      "--output", "./publish/manifest/publish.json",
      "--repository", "matsuo-haruhito/docs-portal",
      "--branch", "main",
      "--sha", "abc123",
      "--artifact-name", "docs-site",
      "--workflow-run-id", "1234567890",
      "--workflow-run-attempt", "2",
      "--manifest-path", "publish/manifest/publish.json"
    ],
    { cwd: tmpDir, stdio: "pipe" }
  );

  const manifest = JSON.parse(fs.readFileSync(path.join(tmpDir, "publish", "manifest", "publish.json"), "utf8"));

  assert.deepEqual(manifest.artifact, {
    name: "docs-site",
    source_repo: "matsuo-haruhito/docs-portal",
    source_branch: "main",
    source_commit_hash: "abc123",
    workflow_run_id: "1234567890",
    workflow_run_attempt: "2",
    manifest_path: "publish/manifest/publish.json"
  });
  assert.equal(manifest.documents[0].files[0].file_size, 3);
});
