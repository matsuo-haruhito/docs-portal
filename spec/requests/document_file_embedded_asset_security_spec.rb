require "rails_helper"
require "fileutils"

RSpec.describe "Document file embedded asset boundaries", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project) }
  let(:document) { create(:document, project:) }
  let(:version) { create(:document_version, document:) }

  def create_embedded_file(file_name:, content_type:, content:, scan_status: :scan_clean)
    document_file = DocumentFile.create!(
      document_version: version,
      file_name:,
      content_type:,
      storage_key: "spec/embedded-boundaries/#{file_name}",
      file_size: content.bytesize,
      scan_status:
    )

    @embedded_files ||= []
    @embedded_files << document_file

    FileUtils.mkdir_p(document_file.absolute_path.dirname)
    File.write(document_file.absolute_path, content)

    document_file
  end

  def embedded_asset_path(owner_file, asset_path)
    asset_document_file_path(owner_file, asset_path:)
  end

  def external_viewer
    external_user = create(:user, :external)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company: external_user.company, access_level: :view)
    external_user
  end

  after do
    Array(@embedded_files).each { |document_file| FileUtils.rm_f(document_file.absolute_path) }
  end

  it "requires access to the owner file before serving an embedded asset" do
    owner_file = create_embedded_file(
      file_name: "site/index.html",
      content_type: "text/html",
      content: "<html><head></head><body>owner</body></html>"
    )
    create_embedded_file(
      file_name: "site/assets/app.css",
      content_type: "text/css",
      content: "body { color: #111; }"
    )
    external_user = create(:user, :external)

    sign_in_as(external_user)

    get embedded_asset_path(owner_file, "site/assets/app.css")

    expect(response).to have_http_status(:forbidden)
  end

  it "does not serve assets when the owner file is not deliverable after scan" do
    owner_file = create_embedded_file(
      file_name: "site/index.html",
      content_type: "text/html",
      content: "<html><head></head><body>owner</body></html>",
      scan_status: :scan_pending
    )
    create_embedded_file(
      file_name: "site/assets/app.css",
      content_type: "text/css",
      content: "body { color: #111; }"
    )

    sign_in_as(external_viewer)

    get embedded_asset_path(owner_file, "site/assets/app.css")

    expect(response).to have_http_status(:forbidden)
  end

  it "does not serve assets that are not deliverable after scan" do
    owner_file = create_embedded_file(
      file_name: "site/index.html",
      content_type: "text/html",
      content: "<html><head></head><body>owner</body></html>"
    )
    create_embedded_file(
      file_name: "site/assets/app.css",
      content_type: "text/css",
      content: "body { color: #111; }",
      scan_status: :scan_pending
    )

    sign_in_as(external_viewer)

    get embedded_asset_path(owner_file, "site/assets/app.css")

    expect(response).to have_http_status(:not_found)
    expect(response.body).to eq("File not found")
  end

  it "rejects traversal asset paths before matching files in the same version" do
    owner_file = create_embedded_file(
      file_name: "site/index.html",
      content_type: "text/html",
      content: "<html><head></head><body>owner</body></html>"
    )
    create_embedded_file(
      file_name: "secret.txt",
      content_type: "text/plain",
      content: "safe placeholder"
    )

    sign_in_as(user)

    get embedded_asset_path(owner_file, "../secret.txt")

    expect(response).to have_http_status(:not_found)
    expect(response.body).to eq("File not found")
  end

  it "renders embedded HTML assets with a base path from the asset tree directory" do
    owner_file = create_embedded_file(
      file_name: "site/index.html",
      content_type: "text/html",
      content: "<html><head></head><body>owner</body></html>"
    )
    create_embedded_file(
      file_name: "site/pages/detail.html",
      content_type: "text/html",
      content: "<html><head><title>detail</title></head><body>detail</body></html>"
    )

    sign_in_as(user)

    get embedded_asset_path(owner_file, "site/pages/detail.html")

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/html")
    expect(response.body).to include(%(<base href="#{embedded_asset_path(owner_file, "site/pages")}/">))
    expect(response.body).to include("<title>detail</title>")
  end
end
