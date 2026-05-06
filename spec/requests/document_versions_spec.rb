require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe "Document versions", type: :request do
  let(:internal_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }
  let(:project) { create(:project, code: "VERSIONED", name: "Versioned Project") }
  let(:document) { create(:document, project:, title: "Versioned Document", slug: "versioned-document") }

  def create_stored_document_file(version, file_name:, content:, sort_order: 0)
    storage_key = "spec/versioned-document/#{SecureRandom.hex(8)}/#{file_name}"
    absolute_path = Rails.root.join("storage", "document_files", storage_key)
    FileUtils.mkdir_p(absolute_path.dirname)
    File.binwrite(absolute_path, content)

    DocumentFile.create!(
      document_version: version,
      file_name:,
      content_type: "text/plain",
      storage_key:,
      file_size: content.bytesize,
      sort_order:
    )
  end

  after do
    FileUtils.rm_rf(Rails.root.join("storage", "document_files", "spec", "versioned-document"))
  end

  it "shows version metadata, files, and links to other versions" do
    older_version = create(:document_version, document:, version_label: "v0.9.0", status: :archived)
    version = create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      status: :published,
      changelog_summary: "initial release",
      markdown_entry_path: "docs/versioned-document",
      site_build_path: "docs/versioned-document"
    )
    document.update!(latest_version: version)
    DocumentFile.create!(
      document_version: version,
      file_name: "README.md",
      content_type: "text/markdown",
      storage_key: "spec/versioned-document/README.md",
      file_size: 123,
      sort_order: 0
    )

    sign_in_as(internal_user)

    get document_version_path(version)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Versioned Document")
    expect(response.body).to include("v1.0.0")
    expect(response.body).to include("initial release")
    expect(response.body).to include("README.md")
    expect(response.body).to include(older_version.version_label)
    expect(response.body).to include(document_version_archive_path(version))
  end

  it "shows export handling notes on version detail" do
    version = create(:document_version, document:, version_label: "v1.0.0", status: :published)
    document.update!(latest_version: version)
    pdf_key = "spec/versioned-document/#{SecureRandom.hex(8)}/manual.pdf"
    pdf_path = Rails.root.join("storage", "document_files", pdf_key)
    FileUtils.mkdir_p(pdf_path.dirname)
    File.binwrite(pdf_path, "%PDF-1.4")
    create(:document_file, document_version: version, file_name: "manual.pdf", content_type: "application/pdf", storage_key: pdf_key, file_size: 8, sort_order: 0, scan_status: :scan_clean)

    sign_in_as(internal_user)
    get document_version_path(version)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("出力時の扱い")
    expect(response.body).to include("HTML 表示には透かしを入れません")
    expect(response.body).to include("Confidential")
  end

  it "links from document detail to each visible version detail" do
    version = create(:document_version, document:, version_label: "v1.0.0", status: :published)
    document.update!(latest_version: version)

    sign_in_as(internal_user)

    get project_document_path(project, document.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(document_version_path(version))
  end

  it "downloads version files as a zip archive and records a download log" do
    version = create(:document_version, document:, version_label: "v1.0.0", status: :published)
    document.update!(latest_version: version)
    create_stored_document_file(version, file_name: "README.md", content: "hello", sort_order: 0)
    create_stored_document_file(version, file_name: "assets/guide.txt", content: "guide", sort_order: 1)

    sign_in_as(internal_user)

    expect do
      get document_version_archive_path(version)
    end.to change(AccessLog.where(action_type: :download, target_type: "zip"), :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/zip")
    expect(response.headers["Content-Disposition"]).to include("attachment")
    expect(response.body).to start_with("PK")
    expect(response.body).to include("README.md")
    expect(response.body).to include("assets/guide.txt")
  end

  it "applies external user visibility rules to version detail and zip archive pages" do
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company: external_user.company, access_level: :view)
    published_version = create(:document_version, document:, version_label: "v1.0.0", status: :published)
    draft_version = create(:document_version, document:, version_label: "v1.1.0", status: :draft)
    archived_version = create(:document_version, document:, version_label: "v0.9.0", status: :archived)

    sign_in_as(external_user)

    get document_version_path(published_version)
    expect(response).to have_http_status(:ok)

    get document_version_archive_path(published_version)
    expect(response).to have_http_status(:forbidden)

    get document_version_path(draft_version)
    expect(response).to have_http_status(:forbidden)

    get document_version_archive_path(draft_version)
    expect(response).to have_http_status(:forbidden)

    get document_version_path(archived_version)
    expect(response).to have_http_status(:forbidden)

    get document_version_archive_path(archived_version)
    expect(response).to have_http_status(:forbidden)
  end
end
