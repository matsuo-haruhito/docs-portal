require "rails_helper"

RSpec.describe GeneratedFiles::SiteBuildArtifactRunRecorder do
  it "records allowlisted site build artifact metadata as a generated file run" do
    started_at = Time.zone.parse("2026-06-21 10:00:00")
    finished_at = Time.zone.parse("2026-06-21 10:03:00")

    run = described_class.call(
      status: "success",
      started_at: started_at,
      finished_at: finished_at,
      artifact: {
        name: "docs-site",
        source_repo: "matsuo-haruhito/docs-portal",
        source_branch: "main",
        source_commit_hash: "abc1234def5678",
        workflow_run_id: 7083,
        workflow_run_attempt: 2,
        manifest_path: "publish/manifest/publish.json",
        raw_payload: {"secret" => "do-not-save"},
        token: "do-not-save"
      },
      manifest: {
        documents: [{"path" => "docs/a.md"}, {"path" => "docs/b.md"}],
        raw_files: [{"body" => "do-not-save"}]
      }
    )

    expect(run).to be_completed
    expect(run.job_id).to eq("docusaurus_site_build_artifact")
    expect(run.generator).to eq("docusaurus_site_build")
    expect(run.output_writer).to eq("docs_site_artifact")
    expect(run.event_source).to eq("docusaurus_site_build")
    expect(run.source_paths).to eq(["publish/manifest/publish.json"])
    expect(run.changed_files).to eq([])
    expect(run.generated_paths).to eq(["docs-site.tar.gz", "publish/manifest/publish.json"])
    expect(run.started_at).to eq(started_at)
    expect(run.finished_at).to eq(finished_at)
    expect(run.metadata).to eq(
      "artifact" => {
        "name" => "docs-site",
        "source_repo" => "matsuo-haruhito/docs-portal",
        "source_branch" => "main",
        "source_commit_hash" => "abc1234def5678",
        "workflow_run_id" => "7083",
        "workflow_run_attempt" => "2",
        "manifest_path" => "publish/manifest/publish.json"
      },
      "read_only_evidence" => true,
      "raw_payload_saved" => false,
      "manifest_document_count" => 2
    )
    expect(run.metadata.to_json).not_to include("do-not-save", "raw_payload", "raw_files")
  end

  it "drops unsafe raw paths, nonnumeric workflow ids, and invalid commit hashes" do
    run = described_class.call(
      status: "failed",
      artifact: {
        name: "docs-site",
        source_repo: "matsuo-haruhito/docs-portal",
        source_branch: "feature/site-build",
        source_commit_hash: "not-a-sha",
        workflow_run_id: "run-7083",
        workflow_run_attempt: "attempt-two",
        manifest_path: "/workspace/private/publish.json"
      },
      manifest: {document_count: 4}
    )

    expect(run).to be_failed
    expect(run.source_paths).to eq([GeneratedFiles::SiteBuildArtifactRunRecorder::DEFAULT_MANIFEST_PATH])
    expect(run.generated_paths).to eq(["docs-site.tar.gz", GeneratedFiles::SiteBuildArtifactRunRecorder::DEFAULT_MANIFEST_PATH])
    expect(run.metadata).to include(
      "artifact" => {
        "name" => "docs-site",
        "source_repo" => "matsuo-haruhito/docs-portal",
        "source_branch" => "feature/site-build"
      },
      "manifest_document_count" => 4
    )
    expect(run.metadata.to_json).not_to include("not-a-sha", "run-7083", "attempt-two", "/workspace/private")
  end

  it "rejects statuses outside the generated file run lifecycle" do
    expect do
      described_class.call(status: "queued", artifact: {})
    end.to raise_error(ArgumentError, /unsupported site build status/)
  end
end
