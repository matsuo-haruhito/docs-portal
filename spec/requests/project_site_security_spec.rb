require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe "Project site security", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "PJ#{SecureRandom.hex(4)}", name: "Project #{SecureRandom.hex(2)}") }
  let(:document) { create(:document, project:, title: "操作説明", slug: "operation-guide") }
  let(:site_build_path) { "docs-#{SecureRandom.hex(3)}/operation-guide" }
  let(:version) do
    create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      markdown_entry_path: site_build_path,
      site_build_path:
    )
  end

  before do
    FileUtils.mkdir_p(version.site_root_absolute_path.join(site_build_path))
    File.write(
      version.site_root_absolute_path.join(site_build_path, "index.html"),
      "<html><body><h1>操作説明</h1></body></html>"
    )

    FileUtils.mkdir_p(version.site_root_absolute_path.join("assets", "css"))
    File.write(version.site_root_absolute_path.join("assets", "css", "app.css"), "body{color:#333;}")

    document.update!(latest_version: version)
  end

  after do
    FileUtils.rm_rf(version.site_root_absolute_path) if version&.id
  end

  it "records access logs for html pages but not for assets" do
    sign_in_as(user)

    expect do
      get project_site_path(project, site_path: version.html_view_site_path, version_id: version.public_id)
    end.to change(AccessLog, :count).by(1)

    expect(response).to have_http_status(:ok)

    log = AccessLog.order(:id).last
    expect(log.action_type).to eq("view")
    expect(log.target_type).to eq("page")
    expect(log.target_name).to eq(version.html_view_site_path)
    expect(log.project).to eq(project)
    expect(log.document).to eq(document)
    expect(log.document_version).to eq(version)

    expect do
      get project_site_path(project, site_path: "assets/css/app.css", version_id: version.public_id)
    end.not_to change(AccessLog, :count)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/css")
  end

  it "forbids non-member external users from requesting project site assets directly" do
    external_user = create(:user, :external)

    sign_in_as(external_user)

    get project_site_path(project, site_path: "assets/css/app.css", version_id: version.public_id)

    expect(response).to have_http_status(:forbidden)
  end

  it "does not allow path traversal outside the project site root" do
    sign_in_as(user)

    get project_site_path(project, site_path: "../secrets.yml", version_id: version.public_id)

    expect(response).to have_http_status(:not_found)
  end

  it "does not allow path traversal after path normalization" do
    sign_in_as(user)

    get project_site_path(project, site_path: "assets/../../secrets.yml", version_id: version.public_id)

    expect(response).to have_http_status(:not_found)
  end

  it "does not allow a version id from another project to be used on the current project site route" do
    other_project = create(:project, code: "PJ#{SecureRandom.hex(4)}", name: "Other Project")
    other_document = create(:document, project: other_project, title: "別案件資料", slug: "other-doc")
    other_version = create(
      :document_version,
      document: other_document,
      version_label: "v1.0.0",
      markdown_entry_path: "other-docs/other-doc",
      site_build_path: "other-docs/other-doc"
    )

    FileUtils.mkdir_p(other_version.site_root_absolute_path.join("other-docs", "other-doc"))
    File.write(
      other_version.site_root_absolute_path.join("other-docs", "other-doc", "index.html"),
      "<html><body><h1>別案件資料</h1></body></html>"
    )

    sign_in_as(user)

    get project_site_path(project, site_path: version.html_view_site_path, version_id: other_version.public_id)

    expect(response).to have_http_status(:not_found)
  ensure
    FileUtils.rm_rf(other_version.site_root_absolute_path) if other_version&.id
  end
end
