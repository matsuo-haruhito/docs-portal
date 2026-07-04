require "rails_helper"
require "fileutils"
require "tempfile"

RSpec.describe "Document uploads", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "UPLOAD", name: "Upload Project") }
  let(:document_file_root) { Rails.root.join("storage", "document_files") }
  let(:site_root) { Rails.root.join("storage", "docs_sites") }

  after do
    FileUtils.rm_rf(document_file_root.join("manual_uploads"))
    FileUtils.rm_rf(site_root)
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def write_site_file(version, relative_path, content)
    path = version.site_root_absolute_path.join(relative_path)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, content)
  end

  it "creates a draft upload candidate under the selected folder" do
    sign_in_as(user)

    expect do
      expect do
        post project_document_uploads_path(project), params: {
          source_path: "docs/specs",
          file: uploaded_file("overview.md", "# Overview")
        }
      end.to have_enqueued_job(DocusaurusPreviewBuildJob)
    end.to change(Document, :count).by(1)
      .and change(DocumentVersion, :count).by(1)
      .and change(DocumentFile, :count).by(1)

    document = project.documents.find_by!(title: "overview")
    version = document.document_versions.first
    expect(document.latest_version).to be_nil
    expect(version).to be_draft
    expect(version).to be_preview_queued
    expect(version.preview_build_attempted_at).to be_present
    expect(version.preview_build_completed_at).to be_nil
    expect(version.source_relative_path).to eq("docs/specs/overview.md")
    expect(version.source_directory).to eq("docs/specs")
    expect(version.source_file_name).to eq("overview.md")
    expect(version.search_body_text).to include("Overview")
    expect(version.document_files.first.file_name).to eq("docs/specs/overview.md")
    expect(version.rendered_site_available?).to eq(false)
    expect(response).to redirect_to(document_version_path(version, upload_review: "1"))
  end

  it "does not create a draft upload candidate during read-only maintenance" do
    sign_in_as(user)

    with_read_only_maintenance("true") do
      expect do
        post project_document_uploads_path(project), params: {
          source_path: "docs/specs",
          file: uploaded_file("overview.md", "# Overview")
        }
      end.not_to have_enqueued_job(DocusaurusPreviewBuildJob)
    end

    expect(Document.count).to eq(0)
    expect(DocumentVersion.count).to eq(0)
    expect(DocumentFile.count).to eq(0)
    expect(response).to redirect_to(project_documents_path(project))
    expect(flash[:alert]).to include("メンテナンス中")
  end

  it "redirects missing project_code upload errors to the projects list" do
    sign_in_as(user)

    expect do
      post "/projects/%20/document_uploads", params: {
        file: uploaded_file("overview.md", "# Overview")
      }
    end.not_to change(Document, :count)

    expect(response).to redirect_to(projects_path)
    expect(flash[:alert]).to include("project_code")
  end

  it "keeps missing file upload errors scoped to the project documents list" do
    sign_in_as(user)

    expect do
      post project_document_uploads_path(project), params: {
        source_path: "docs/specs"
      }
    end.not_to change(Document, :count)

    expect(response).to redirect_to(project_documents_path(project))
    expect(flash[:alert]).to include("file")
  end

  it "rejects unsafe upload target folders" do
    sign_in_as(user)

    expect do
      post project_document_uploads_path(project), params: {
        source_path: "/etc",
        file: uploaded_file("overview.md", "# Overview")
      }
    end.not_to change(Document, :count)

    expect(response).to redirect_to(project_documents_path(project))
    expect(flash[:alert]).to include("アップロード先フォルダが不正です")
  end

  it "rejects drive-letter upload target folders" do
    sign_in_as(user)

    expect do
      post project_document_uploads_path(project), params: {
        source_path: "C:/docs",
        file: uploaded_file("overview.md", "# Overview")
      }
    end.not_to change(Document, :count)

    expect(response).to redirect_to(project_documents_path(project))
    expect(flash[:alert]).to include("アップロード先フォルダが不正です")
  end

  it "enqueues a Docusaurus preview build for manually uploaded markdown" do
    sign_in_as(user)
    markdown = <<~MD
      # Preview

      ```plantuml
      @startuml
      Alice -> Bob: hello
      @enduml
      ```
    MD

    expect do
      post project_document_uploads_path(project), params: {
        source_path: "docs/specs",
        file: uploaded_file("preview.md", markdown)
      }
    end.to have_enqueued_job(DocusaurusPreviewBuildJob)

    version = project.documents.find_by!(title: "preview").document_versions.first
    expect(version).to be_preview_queued
    expect(version.rendered_site_available?).to eq(false)
    expect(version.markdown_entry_path).to be_blank
    expect(version.site_build_path).to be_blank
  end

  it "shows review actions and pending preview state on a draft manual upload version" do
    sign_in_as(user)
    document = create(:document, project: project, title: "Guide", slug: "guide")
    version = create(:document_version, document: document, status: :draft, source_commit_hash: "manual-upload")
    version.assign_source_path_metadata!(source_path: "docs/guide.md", snapshot_kind: "received_markdown")
    version.save!

    get document_version_path(version, upload_review: "1")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("アップロード候補の確認")
    expect(response.body).to include("OK：この内容を反映")
    expect(response.body).to include("NG：この候補を破棄")
    expect(response.body).to include("Docusaurusプレビュー生成中")
  end

  it "keeps the upload review page readable during read-only maintenance" do
    sign_in_as(user)
    document = create(:document, project: project, title: "Guide", slug: "guide")
    version = create(:document_version, document: document, status: :draft, source_commit_hash: "manual-upload")
    version.assign_source_path_metadata!(source_path: "docs/guide.md", snapshot_kind: "received_markdown")
    version.save!

    with_read_only_maintenance("true") do
      get document_version_path(version, upload_review: "1")
    end

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("アップロード候補の確認")
  end

  it "renders iframe upload wiring on the preview page for internal users" do
    sign_in_as(user)
    document = create(:document, project: project, title: "Guide", slug: "guide")
    version = create(
      :document_version,
      document: document,
      status: :published,
      version_label: "v1.0.0",
      source_commit_hash: "git-import",
      site_build_path: "docs/guide"
    )
    version.assign_source_path_metadata!(source_path: "docs/guide.md", snapshot_kind: "received_markdown")
    version.save!
    document.update!(latest_version: version)
    write_site_file(version, "docs/guide/index.html", "<html><body><h1>Guide</h1></body></html>")

    get project_document_path(project, document.slug)

    expect(response).to have_http_status(:ok)

    shell = parsed_html.at_css(".site-viewer-shell.manual-document-upload-target")
    expect(shell).to be_present
    expect(shell["data-controller"].to_s.split).to include("manual-document-upload")
    expect(shell["data-manual-document-upload-url-value"]).to eq(project_document_uploads_path(project))
    expect(shell["data-manual-document-upload-target-document-id"]).to eq(document.public_id)
    expect(shell["data-action"]).to include("drop->manual-document-upload#drop")
    expect(parsed_html.at_css(".document-preview-drop-overlay[data-manual-document-upload-target='overlay']")).to be_present
    expect(parsed_html.at_css("iframe.site-viewer-frame[data-manual-document-upload-target='frame']")).to be_present
  end

  it "approves a draft upload candidate as the latest version" do
    sign_in_as(user)
    document = create(:document, project: project, title: "Guide", slug: "guide")
    previous_version = create(:document_version, document: document)
    previous_version.assign_source_path_metadata!(source_path: "docs/guide.md", snapshot_kind: "received_markdown")
    previous_version.save!
    document.update!(latest_version: previous_version)
    upload_version = create(:document_version, document: document, status: :draft, source_commit_hash: "manual-upload")
    upload_version.assign_source_path_metadata!(source_path: "docs/guide.md", snapshot_kind: "received_markdown")
    upload_version.save!

    post document_version_upload_review_path(upload_version), params: { decision: "approve" }

    expect(response).to redirect_to(project_document_path(project, document, version_id: upload_version.public_id))
    expect(flash[:notice]).to include("誤りがあればすぐ取り消せます")
    expect(flash[:approved_upload_version_public_id]).to eq(upload_version.public_id)
    expect(upload_version.reload).to be_published
    expect(upload_version.published_by_user).to eq(user)
    expect(document.reload.latest_version).to eq(upload_version)
  end

  %w[approve reject].each do |decision|
    it "does not #{decision} a draft upload candidate during read-only maintenance" do
      sign_in_as(user)
      document = create(:document, project: project, title: "Guide", slug: "guide")
      previous_version = create(:document_version, document: document)
      previous_version.assign_source_path_metadata!(source_path: "docs/guide.md", snapshot_kind: "received_markdown")
      previous_version.save!
      document.update!(latest_version: previous_version)
      upload_version = create(:document_version, document: document, status: :draft, source_commit_hash: "manual-upload")
      upload_version.assign_source_path_metadata!(source_path: "docs/guide.md", snapshot_kind: "received_markdown")
      upload_version.save!

      with_read_only_maintenance("true") do
        post document_version_upload_review_path(upload_version), params: { decision: decision }
      end

      expect(response).to redirect_to(document_version_path(upload_version))
      expect(flash[:alert]).to include("メンテナンス中")
      expect(upload_version.reload).to be_draft
      expect(upload_version.published_by_user).to be_nil
      expect(document.reload.latest_version).to eq(previous_version)
    end
  end

  it "rejects a draft upload candidate without promoting it" do
    sign_in_as(user)
    document = create(:document, project: project, title: "Guide", slug: "guide")
    previous_version = create(:document_version, document: document)
    previous_version.assign_source_path_metadata!(source_path: "docs/guide.md", snapshot_kind: "received_markdown")
    previous_version.save!
    document.update!(latest_version: previous_version)
    upload_version = create(:document_version, document: document, status: :draft, source_commit_hash: "manual-upload")
    upload_version.assign_source_path_metadata!(source_path: "docs/guide.md", snapshot_kind: "received_markdown")
    upload_version.save!

    post document_version_upload_review_path(upload_version), params: { decision: "reject" }

    expect(response).to redirect_to(project_documents_path(project, q: "docs"))
    expect(upload_version.reload).to be_archived
    expect(document.reload.latest_version).to eq(previous_version)
  end

  it "creates a new draft candidate version when dropped on a document with the same filename instead of overwriting latest_version" do
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

    candidate = document.document_versions.order(:created_at, :id).last
    expect(document.reload.latest_version).to eq(version)
    expect(candidate).to be_draft
    expect(candidate).to be_preview_queued
    expect(candidate.source_relative_path).to eq("docs/guide.md")
    expect(candidate.search_body_text).to include("Updated Guide")
    expect(candidate.document_files.first.file_name).to eq("docs/guide.md")
  end

  it "creates a sibling draft document when dropped on a document with a different filename" do
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
    candidate = sibling.document_versions.first
    expect(sibling.latest_version).to be_nil
    expect(candidate).to be_draft
    expect(candidate).to be_preview_not_requested
    expect(candidate.source_relative_path).to eq("docs/appendix.pdf")
    expect(candidate.source_directory).to eq("docs")
  end

  it "rolls back the latest approved upload version to the previous version" do
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

  it "does not roll back a non-manual latest version" do
    sign_in_as(user)
    document = create(:document, project: project, title: "Imported", slug: "imported")
    version = create(:document_version, document: document, source_commit_hash: "git-import")
    version.assign_source_path_metadata!(source_path: "docs/imported.md", snapshot_kind: "received_markdown")
    version.save!
    document.update!(latest_version: version)

    post document_version_rollback_path(version)

    expect(response).to redirect_to(document_version_path(version))
    expect(document.reload.latest_version).to eq(version)
    expect(version.reload).to be_published
  end

  private

  def with_read_only_maintenance(value)
    original = ENV["READ_ONLY_MAINTENANCE"]
    ENV["READ_ONLY_MAINTENANCE"] = value
    yield
  ensure
    if original.nil?
      ENV.delete("READ_ONLY_MAINTENANCE")
    else
      ENV["READ_ONLY_MAINTENANCE"] = original
    end
  end

  def uploaded_file(filename, content)
    tempfile = Tempfile.new([File.basename(filename, ".*"), File.extname(filename)])
    tempfile.binmode
    tempfile.write(content)
    tempfile.rewind
    Rack::Test::UploadedFile.new(tempfile.path, Rack::Mime.mime_type(File.extname(filename)), original_filename: filename)
  end
end
