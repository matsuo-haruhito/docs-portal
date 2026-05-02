require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe "Project sites", type: :request do
  let(:site_build_path) { "external_samples/sample-site/edit-original" }
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "PJ#{SecureRandom.hex(4)}", name: "Project #{SecureRandom.hex(2)}") }
  let!(:document) do
    create(
      :document,
      project:,
      title: "見積対象・費用感整理",
      slug: "mitsumori-fee"
    )
  end
  let!(:version_v1) do
    create(
      :document_version,
      document:,
      version_label: "v1",
      markdown_entry_path: "#{site_build_path}/mitsumori-fee",
      site_build_path:
    )
  end
  let!(:version_v2) do
    create(
      :document_version,
      document:,
      version_label: "v2",
      markdown_entry_path: "#{site_build_path}/mitsumori-fee",
      site_build_path: "#{site_build_path}-v2"
    )
  end

  before do
    FileUtils.mkdir_p(version_v1.site_root_absolute_path.join(site_build_path))
    File.write(
      version_v1.site_root_absolute_path.join(site_build_path, "mitsumori-fee.html"),
      <<~HTML
        <!DOCTYPE html>
        <html>
          <head>
            <link rel="stylesheet" href="/assets/css/app.css">
            <script src="/assets/js/app.js"></script>
          </head>
          <body>
            <h1>見積対象・費用感整理</h1>
            <a href="../other-doc">Other</a>
          </body>
        </html>
      HTML
    )
    FileUtils.mkdir_p(version_v1.site_root_absolute_path.join("assets", "css"))
    File.write(version_v1.site_root_absolute_path.join("assets", "css", "app.css"), "body{color:#333;}")
    FileUtils.mkdir_p(version_v1.site_root_absolute_path.join("assets", "js"))
    File.write(version_v1.site_root_absolute_path.join("assets", "js", "app.js"), "console.log('ok');")

    FileUtils.mkdir_p(version_v2.site_root_absolute_path.join("#{site_build_path}-v2"))
    File.write(
      version_v2.site_root_absolute_path.join("#{site_build_path}-v2", "mitsumori-fee.html"),
      "<html><body><h1>見積対象・費用感整理 v2</h1></body></html>"
    )

    document.update!(latest_version: version_v2)
  end

  after do
    FileUtils.rm_rf(version_v1.site_root_absolute_path)
    FileUtils.rm_rf(version_v2.site_root_absolute_path)
  end

  it "renders project site html from a project-based route" do
    sign_in_as(user)

    get project_site_path(project, site_path: version_v1.html_view_site_path, version_id: version_v1.public_id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("見積対象・費用感整理")
    expect(response.body).to include(project_site_path(project, site_path: "external_samples/sample-site/edit-original/other-doc", version_id: version_v1.public_id))
    expect(response.body).to include(project_site_path(project, site_path: "assets/css/app.css", version_id: version_v1.public_id))
    expect(response.body).to include(project_site_path(project, site_path: "assets/js/app.js", version_id: version_v1.public_id))
  end

  it "serves assets from the project site route" do
    sign_in_as(user)

    get project_site_path(project, site_path: "assets/css/app.css", version_id: version_v1.public_id)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/css")
  end

  it "serves javascript assets from the project site route" do
    sign_in_as(user)

    get project_site_path(project, site_path: "assets/js/app.js", version_id: version_v1.public_id)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to end_with("javascript")
  end

  it "shows a project site link on the project detail page" do
    sign_in_as(user)

    get project_path(project)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("ドキュメントサイトを表示")
    expect(response.body).to include(project_site_path(project, site_path: version_v2.html_view_site_path, version_id: version_v2.public_id))
  end

  it "forbids external users from requesting archived versions by version_id" do
    external_user = create(:user, :external)
    create(:project_membership, project:, user: external_user)
    version_v1.update!(status: :archived)

    sign_in_as(external_user)

    get project_site_path(project, site_path: version_v1.html_view_site_path, version_id: version_v1.public_id)
    expect(response).to have_http_status(:forbidden)

    get project_site_path(project, site_path: "assets/css/app.css", version_id: version_v1.public_id)
    expect(response).to have_http_status(:forbidden)
  end
end
