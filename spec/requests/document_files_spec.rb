require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe "Document files", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "PJ#{SecureRandom.hex(4)}", name: "Project #{SecureRandom.hex(2)}") }
  let(:document) { create(:document, project:, title: "運用手順", slug: "operation-manual") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0") }
  let(:file) do
    DocumentFile.create!(
      document_version: version,
      file_name: "manual.pdf",
      content_type: "application/pdf",
      storage_key: "spec/manual.pdf",
      file_size: 12,
      scan_status: :scan_clean
    )
  end
  let(:markdown_file) do
    DocumentFile.create!(
      document_version: version,
      file_name: "README.md",
      content_type: "application/octet-stream",
      storage_key: "spec/README.md",
      file_size: 20,
      sort_order: 1,
      scan_status: :scan_clean
    )
  end
  let(:binary_file) do
    DocumentFile.create!(
      document_version: version,
      file_name: "archive.bin",
      content_type: "application/octet-stream",
      storage_key: "spec/archive.bin",
      file_size: 6,
      sort_order: 2,
      scan_status: :scan_clean
    )
  end

  before do
    FileUtils.mkdir_p(file.absolute_path.dirname)
    File.write(file.absolute_path, "%PDF-1.4")
    File.write(markdown_file.absolute_path, "# hello\n")
    File.binwrite(binary_file.absolute_path, "binary")
  end

  after do
    FileUtils.rm_f(file.absolute_path)
    FileUtils.rm_f(markdown_file.absolute_path)
    FileUtils.rm_f(binary_file.absolute_path)
  end

  it "downloads the file and records an access log" do
    sign_in_as(user)

    expect do
      get document_file_path(file)
    end.to change(AccessLog, :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/pdf")

    log = AccessLog.order(:id).last
    expect(log.user).to eq(user)
    expect(log.project).to eq(project)
    expect(log.document).to eq(document)
    expect(log.document_version).to eq(version)
    expect(log.action_type).to eq("download")
    expect(log.target_type).to eq("file")
    expect(log.target_name).to eq("manual.pdf")
  end

  it "records a file view access log for embedded preview requests" do
    sign_in_as(user)

    expect do
      get document_file_path(file, embedded: "1")
    end.to change(AccessLog, :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/pdf")
    expect(response.headers["content-disposition"]).to include("inline")

    log = AccessLog.order(:id).last
    expect(log.user).to eq(user)
    expect(log.project).to eq(project)
    expect(log.document).to eq(document)
    expect(log.document_version).to eq(version)
    expect(log.action_type).to eq("view")
    expect(log.target_type).to eq("file")
    expect(log.target_name).to eq("manual.pdf")
  end

  it "does not fail the download when access log creation fails" do
    sign_in_as(user)
    allow(AccessLog).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

    get document_file_path(file)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/pdf")
  end

  it "returns not found when the stored file is missing" do
    sign_in_as(user)
    FileUtils.rm_f(file.absolute_path)

    get document_file_path(file)

    expect(response).to have_http_status(:not_found)
    expect(response.body).to eq("File not found")
  end

  it "does not serve files outside the document file storage root" do
    unsafe_file = DocumentFile.create!(
      document_version: version,
      file_name: "outside.yml",
      content_type: "text/yaml",
      storage_key: "../outside.yml",
      file_size: 1,
      scan_status: :scan_clean
    )

    sign_in_as(user)

    expect do
      get document_file_path(unsafe_file)
    end.not_to change(AccessLog, :count)

    expect(response).to have_http_status(:not_found)
  end

  it "does not serve files outside the storage root after path normalization" do
    unsafe_file = DocumentFile.create!(
      document_version: version,
      file_name: "outside.yml",
      content_type: "text/yaml",
      storage_key: "spec/../../outside.yml",
      file_size: 1,
      scan_status: :scan_clean
    )

    sign_in_as(user)

    get document_file_path(unsafe_file)

    expect(response).to have_http_status(:not_found)
  end

  it "serves markdown files inline" do
    sign_in_as(user)

    get document_file_path(markdown_file)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include("line-preview")
    expect(response.body).to include("README.md")
    expect(response.body).to include("# hello")
  end

  it "serves inline-capable files inline when inline disposition is requested" do
    sign_in_as(user)

    get document_file_path(markdown_file, disposition: "inline")

    expect(response).to have_http_status(:ok)
    expect(response.headers["content-disposition"]).to include("inline")
  end

  it "serves files as attachments when download disposition is requested" do
    sign_in_as(user)

    get document_file_path(markdown_file, disposition: "download")

    expect(response).to have_http_status(:ok)
    expect(response.headers["content-disposition"]).to include("attachment")
  end

  it "falls back to attachment for non-inline files even when inline is requested" do
    sign_in_as(user)

    get document_file_path(binary_file, disposition: "inline")

    expect(response).to have_http_status(:ok)
    expect(response.headers["content-disposition"]).to include("attachment")
  end

  it "forbids external users who only have view permission from downloading attachments" do
    external_user = create(:user, :external)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company: external_user.company, access_level: :view)

    sign_in_as(external_user)

    expect do
      get document_file_path(file)
    end.not_to change(AccessLog, :count)

    expect(response).to have_http_status(:forbidden)
  end

  it "allows external users with download permission to download attachments" do
    external_user = create(:user, :external)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company: external_user.company, access_level: :download)

    sign_in_as(external_user)

    get document_file_path(file)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/pdf")
  end

  it "forbids version archive downloads for external users who only have view permission" do
    external_user = create(:user, :external)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company: external_user.company, access_level: :view)

    sign_in_as(external_user)

    expect do
      get document_version_archive_path(version)
    end.not_to change(AccessLog.where(action_type: :download, target_type: "zip"), :count)

    expect(response).to have_http_status(:forbidden)
  end

  it "allows version archive downloads for external users with download permission" do
    external_user = create(:user, :external)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company: external_user.company, access_level: :download)

    sign_in_as(external_user)

    expect do
      get document_version_archive_path(version)
    end.to change(AccessLog.where(action_type: :download, target_type: "zip"), :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/zip")
  end

  it "hides attachment links from external users who only have view permission" do
    external_user = create(:user, :external)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company: external_user.company, access_level: :view)

    sign_in_as(external_user)
    get project_document_path(project, document.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(file.file_name)
    expect(response.body).not_to include(document_file_path(file, disposition: "download"))
  end

  it "shows attachment links to external users who have download permission" do
    external_user = create(:user, :external)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company: external_user.company, access_level: :download)

    sign_in_as(external_user)
    get project_document_path(project, document.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(document_file_path(file))
  end

  it "labels markdown attachments as raw file display in the document detail page" do
    sign_in_as(user)

    get project_document_path(project, document.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("元Markdown・生ファイル")
  end

  it "shows separate preview and download links on the version detail page" do
    sign_in_as(user)

    get document_version_path(version)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(document_file_path(markdown_file))
    expect(response.body).to include(document_file_path(markdown_file, disposition: "download"))
  end

  it "renders attachment folders as a tree in document and version detail pages" do
    nested_file = DocumentFile.create!(
      document_version: version,
      file_name: "docs/images/flow.png",
      content_type: "image/png",
      storage_key: "spec/docs/images/flow.png",
      file_size: 6,
      sort_order: 3,
      scan_status: :scan_clean
    )

    FileUtils.mkdir_p(nested_file.absolute_path.dirname)
    File.binwrite(nested_file.absolute_path, "image")
    sign_in_as(user)

    get document_version_path(version)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("docs")
    expect(response.body).to include("images")
    expect(response.body).to include("flow.png")

    get project_document_path(project, document.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("docs")
    expect(response.body).to include("images")
    expect(response.body).to include("flow.png")
  end
end