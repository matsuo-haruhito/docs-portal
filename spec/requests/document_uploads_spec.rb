require "rails_helper"
require "fileutils"
require "tempfile"

RSpec.describe "Document uploads", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "UPLOAD", name: "Upload Project") }
  let(:document_file_root) { Rails.root.join("storage", "document_files") }

  after do
    FileUtils.rm_rf(document_file_root.join("manual_uploads"))
  end

  it "creates a new document under the selected folder" do
    sign_in_as(user)

    expect do
      post project_document_uploads_path(project), params: {
        source_path: "docs/specs",
        file: uploaded_file("overview.md", "# Overview")
      }
    end.to change(Document, :count).by(1)
      .and change(DocumentVersion, :count).by(1)
      .and change(DocumentFile, :count).by(1)

    document = project.documents.find_by!(title: "overview")
    version = document.latest_version
    expect(version.source_relative_path).to eq("docs/specs/overview.md")
    expect(version.source_directory).to eq("docs/specs")
    expect(version.source_file_name).to eq("overview.md")
    expect(version.document_files.first.file_name).to eq("docs/specs/overview.md")
  end

  it "creates a new version when dropped on a document with the same filename" do
    sign_in_as(user)
    document = create(:document, project: project, title: "Guide", slug: "guide")
    version = create(:document_version, document: document)
    version.assign_source_path_metadata!(source_path: "docs/guide.md", snapshot_kind: "received_markdown")
    version.save!
    document.update!(latest_version: version)

    expect do
      post project_document_uploads_path(project), params: {
        target_document_id: document.public_id,
        file: uploaded_file("guide.md", "# Updated Guide")
      }
    end.to change(Document, :count).by(0)
      .and change { document.document_versions.count }.by(1)

    latest = document.reload.latest_version
    expect(latest.source_relative_path).to eq("docs/guide.md")
    expect(latest.document_files.first.file_name).to eq("docs/guide.md")
  end

  it "creates a sibling document when dropped on a document with a different filename" do
    sign_in_as(user)
    document = create(:document, project: project, title: "Guide", slug: "guide")
    version = create(:document_version, document: document)
    version.assign_source_path_metadata!(source_path: "docs/guide.md", snapshot_kind: "received_markdown")
    version.save!
    document.update!(latest_version: version)

    expect do
      post project_document_uploads_path(project), params: {
        target_document_id: document.public_id,
        file: uploaded_file("appendix.pdf", "PDF")
      }
    end.to change(Document, :count).by(1)
      .and change(DocumentVersion, :count).by(1)

    sibling = project.documents.find_by!(title: "appendix")
    expect(sibling.latest_version.source_relative_path).to eq("docs/appendix.pdf")
    expect(sibling.latest_version.source_directory).to eq("docs")
  end

  private

  def uploaded_file(filename, content)
    tempfile = Tempfile.new([File.basename(filename, ".*"), File.extname(filename)])
    tempfile.binmode
    tempfile.write(content)
    tempfile.rewind
    Rack::Test::UploadedFile.new(tempfile.path, Rack::Mime.mime_type(File.extname(filename)), original_filename: filename)
  end
end
