require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe "Document file embedded assets", type: :request do
  let(:internal_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "PJ#{SecureRandom.hex(4)}", name: "Project #{SecureRandom.hex(2)}") }
  let(:document) { create(:document, project:, title: "HTML guide", slug: "html-guide") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0") }

  let(:owner_file) do
    create_document_file(
      file_name: "site/index.html",
      content_type: "text/html",
      storage_key: "spec/embedded-assets/site/index.html",
      content: "<html><head><title>Guide</title></head><body><img src=\"assets/logo.png\"></body></html>",
      sort_order: 1
    )
  end

  let(:css_asset_file) do
    create_document_file(
      file_name: "assets/app.css",
      content_type: "text/css",
      storage_key: "spec/embedded-assets/assets/app.css",
      content: "body { color: #123456; }",
      sort_order: 2
    )
  end

  let(:nested_html_asset_file) do
    create_document_file(
      file_name: "nested/page.html",
      content_type: "text/html",
      storage_key: "spec/embedded-assets/nested/page.html",
      content: "<html><head><title>Nested</title></head><body><img src=\"image.png\"></body></html>",
      sort_order: 3
    )
  end

  before do
    owner_file
  end

  after do
    Array(@document_files).each { |document_file| FileUtils.rm_f(document_file.absolute_path) }
  end

  def create_document_file(file_name:, content_type:, storage_key:, content:, sort_order:, scan_status: :scan_clean, document_version: version)
    document_file = DocumentFile.create!(
      document_version:,
      file_name:,
      content_type:,
      storage_key:,
      file_size: content.bytesize,
      sort_order:,
      scan_status:
    )

    @document_files ||= []
    @document_files << document_file

    FileUtils.mkdir_p(document_file.absolute_path.dirname)
    File.write(document_file.absolute_path, content)

    document_file
  end

  it "serves an embedded asset only after the owner file is viewable" do
    external_user = create(:user, :external)
    create(:project_membership, project:, user: external_user)

    sign_in_as(external_user)

    get asset_document_file_path(owner_file, asset_path: css_asset_file.tree_path)

    expect(response).to have_http_status(:forbidden)
  end

  it "serves a clean embedded asset for a user who can view the owner file" do
    external_user = create(:user, :external)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company: external_user.company, access_level: :view)

    sign_in_as(external_user)

    get asset_document_file_path(owner_file, asset_path: css_asset_file.tree_path)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/css")
    expect(response.body).to include("color: #123456")
    expect(response.headers["content-disposition"]).to include("inline")
  end

  it "blocks the asset route when the owner file is not deliverable after scan" do
    external_user = create(:user, :external)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company: external_user.company, access_level: :view)
    owner_file.update!(scan_status: :scan_pending)

    sign_in_as(external_user)

    get asset_document_file_path(owner_file, asset_path: css_asset_file.tree_path)

    expect(response).to have_http_status(:forbidden)
  end

  it "returns not found when the embedded asset is not deliverable after scan" do
    external_user = create(:user, :external)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company: external_user.company, access_level: :view)
    css_asset_file.update!(scan_status: :scan_pending)

    sign_in_as(external_user)

    get asset_document_file_path(owner_file, asset_path: css_asset_file.tree_path)

    expect(response).to have_http_status(:not_found)
    expect(response.body).to eq("File not found")
  end

  it "returns not found for missing, owner-external, and traversal-like asset paths" do
    other_version = create(:document_version, document:, version_label: "v1.0.1")
    other_asset = create_document_file(
      file_name: "assets/other.css",
      content_type: "text/css",
      storage_key: "spec/embedded-assets/other-version/assets/other.css",
      content: "body { color: red; }",
      sort_order: 1,
      document_version: other_version
    )

    sign_in_as(internal_user)

    get asset_document_file_path(owner_file, asset_path: "assets/missing.css")
    expect(response).to have_http_status(:not_found)
    expect(response.body).to eq("File not found")

    get asset_document_file_path(owner_file, asset_path: other_asset.tree_path)
    expect(response).to have_http_status(:not_found)
    expect(response.body).to eq("File not found")

    get asset_document_file_path(owner_file, asset_path: "assets/../outside.css")
    expect(response).to have_http_status(:not_found)
    expect(response.body).to eq("File not found")
  end

  it "adds a base tag relative to the current HTML asset tree path" do
    sign_in_as(internal_user)

    get asset_document_file_path(owner_file, asset_path: nested_html_asset_file.tree_path)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include(%(<base href="#{asset_document_file_path(owner_file, asset_path: "nested")}/">))
    expect(response.body).to include("<title>Nested</title>")
  end
end
