require "rails_helper"
require "fileutils"
require "securerandom"
require "tempfile"
require "zip"

RSpec.describe ZipImportStager do
  let(:project) { create(:project, code: "ZIPSPEC", name: "ZIP Spec") }
  let(:actor) { create(:user, :internal, email_address: "importer@example.com") }
  let(:import_root) { Rails.root.join("storage", "imports") }

  after do
    FileUtils.rm_rf(import_root.join("zip_uploads"))
  end

  it "expands a zip, builds a manifest, and stages referenced attachments" do
    uploaded_file = build_uploaded_zip(
      "docs/README.md" => "# Overview\n\n![Flow](images/flow.png)\n",
      "docs/images/flow.png" => "image",
      "docs/orphan.txt" => "orphan",
      "__MACOSX/._README.md" => "noise"
    )

    result = described_class.new(
      uploaded_file:,
      project:,
      actor:,
      source_branch: "release.zip",
      version_label: "zip-v1"
    ).call

    expect(result.manifest["source_repo"]).to eq("zip_upload")
    expect(result.manifest["source_branch"]).to eq("release.zip")
    expect(result.manifest["source_commit_hash"]).to be_present
    expect(result.manifest["documents"].size).to eq(1)

    document = result.manifest["documents"].first
    expect(document["project_code"]).to eq(project.code)
    expect(document["slug"]).to eq("docs")
    expect(document["source_relative_path"]).to eq("docs/README.md")
    expect(document["version_label"]).to eq("zip-v1")
    expect(document["files"].map { _1["file_name"] }).to contain_exactly("docs/README.md", "docs/images/flow.png")
    expect(document["files"].map { _1["storage_key"] }).to all(include("zip_uploads/"))

    preview = result.manifest.fetch("zip_import_preview")
    expect(preview["orphan_files"]).to contain_exactly("docs/orphan.txt")
    expect(preview["skipped_files"]).to contain_exactly("__MACOSX/._README.md")

    staged_attachment = result.artifact_root.join("attachments", document["files"].find { _1["file_name"] == "docs/images/flow.png" }.fetch("storage_key"))
    expect(staged_attachment).to exist
  ensure
    uploaded_file&.tempfile&.close!
  end

  private

  def build_uploaded_zip(entries)
    tempfile = Tempfile.new(["zip-import", ".zip"])
    tempfile.binmode

    Zip::File.open(tempfile.path, create: true) do |zip_file|
      entries.each do |path, content|
        zip_file.get_output_stream(path) { _1.write(content) }
      end
    end

    Rack::Test::UploadedFile.new(tempfile.path, "application/zip", original_filename: "sample.zip")
  end
end
