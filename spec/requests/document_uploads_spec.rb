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
    expect(response).to redirect_to(project_documents_path(project, q: "docs/specs/overview.md", uploaded_version_id: version.public_id))
  end

  it "shows a completion prompt with a diff link" do
    sign_in_as(user)
    document = create(:document, project: project, title: "Guide", slug: "guide")
    version = create(:document_version, document: document)
    document.update!(latest_version: version)

    get project_documents_path(project, uploaded_version_id: version.public_id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("アップロードを完了しました")
    expect(response.body).to include("差異を確認")
    expect(response.body).to include(document_version_path(version))
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

  it "rolls back the latest uploaded version to the previous version" do
    sign_in_as(user)
    document = create(:document, project: project, title: "Guide", slug: "guide")
    previous_version = create(:document_version, document: document)
    previous_version.assign_source_path_metadata!(source_path: "docs/guide.md", snapshot_kind: "received_markdown")
    previous_version.save!
    uploaded_version = create(:document_version, document: document, source_commit_hash: "manual-upload")
    uploaded_version.assign_source_path_metadata!(source_path: "docs/guide.md", snapshot_kind: "received_markdown")
    uploaded_version.save!
    document.update!(latest_version: uploaded_version)

    expect do
      post document_version_rollback_path(uploaded_version)
    end.not_to change(DocumentVersion, :count)

    expect(response).to redirect_to(document_version_path(previous_version))
    expect(document.reload.latest_version).to eq(previous_version)
    expect(uploaded_version.reload).to be_archived
  end

  it "archives the document when rolling back its only version" do
    sign_in_as(user)
    document = create(:document, project: project, title: "Only", slug: "only")
    uploaded_version = create(:document_version, document: document, source_commit_hash: "manual-upload")
    uploaded_version.assign_source_path_metadata!(source_path: "docs/only.md", snapshot_kind: "received_markdown")
    uploaded_version.save!
    document.update!(latest_version: uploaded_version)

    expect do
      post document_version_rollback_path(uploaded_version)
    end.not_to change(DocumentVersion, :count)

    expect(response).to redirect_to(project_documents_path(project))
    expect(document.reload).to be_archived
    expect(document.latest_version).to be_nil
    expect(uploaded_version.reload).to be_archived
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