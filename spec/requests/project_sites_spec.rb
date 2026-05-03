require "rails_helper"
require "fileutils"
require "securerandom"
require "tmpdir"

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
  let!(:restricted_document) do
    create(
      :document,
      project:,
      title: "社外秘メモ",
      slug: "secret-memo"
    )
  end
  let!(:restricted_version) do
    create(
      :document_version,
      document: restricted_document,
      version_label: "v1",
      markdown_entry_path: "#{site_build_path}/secret-memo",
      site_build_path:
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
            <nav>
              <a href="mitsumori-fee">Allowed page</a>
              <a href="secret-memo">Restricted page</a>
            </nav>
            <a href="other-doc">Other</a>
          </body>
        </html>
      HTML
    )
    File.write(
      version_v1.site_root_absolute_path.join(site_build_path, "secret-memo.html"),
      "<html><body><h1>社外秘メモ</h1></body></html>"
    )
    FileUtils.mkdir_p(version_v1.site_root_absolute_path.join(site_build_path, "guide"))
    File.write(
      version_v1.site_root_absolute_path.join(site_build_path, "guide", "index.html"),
      "<html><body><h1>Guide Index</h1></body></html>"
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
    File.write(
      version_v2.site_root_absolute_path.join("#{site_build_path}-v2", "index.html"),
      "<html><body><h1>見積対象・費用感整理 v2</h1></body></html>"
    )
    FileUtils.mkdir_p(restricted_version.site_root_absolute_path.join(site_build_path))
    File.write(
      restricted_version.site_root_absolute_path.join(site_build_path, "secret-memo.html"),
      "<html><body><h1>社外秘メモ</h1></body></html>"
    )
    File.write(
      restricted_version.site_root_absolute_path.join(site_build_path, "index.html"),
      "<html><body><h1>社外秘メモ</h1></body></html>"
    )

    document.update!(latest_version: version_v2)
    restricted_document.update!(latest_version: restricted_version)
  end

  after do
    FileUtils.rm_rf(version_v1.site_root_absolute_path)
    FileUtils.rm_rf(version_v2.site_root_absolute_path)
    FileUtils.rm_rf(restricted_version.site_root_absolute_path)
  end

  it "renders project site html from a project-based route" do
    sign_in_as(user)

    get project_site_path(project, site_path: version_v1.html_view_site_path, version_id: version_v1.public_id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("見積対象・費用感整理")
    expect(response.body).to include(project_path(project))
    expect(response.body).to include(project_document_path(project, document.slug))
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

  it "resolves markdown-style index paths to generated html" do
    sign_in_as(user)

    get project_site_path(project, site_path: "#{site_build_path}/guide/index.md", version_id: version_v1.public_id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Guide Index")
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

  it "filters restricted site navigation links for external users and blocks direct page access" do
    external_user = create(:user, :external)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company: external_user.company, access_level: :view)

    sign_in_as(external_user)

    get project_site_path(project, site_path: version_v1.html_view_site_path, version_id: version_v1.public_id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Allowed page")
    expect(response.body).not_to include("Restricted page")

    get project_site_path(project, site_path: restricted_version.html_view_site_path, version_id: version_v1.public_id)

    expect(response).to have_http_status(:forbidden)
  end

  it "rejects path traversal and symlink escapes outside the site root" do
    sign_in_as(user)

    get project_site_path(project, site_path: "../secrets.yml", version_id: version_v1.public_id)
    expect(response).to have_http_status(:not_found)

    outside_dir = Dir.mktmpdir("site-escape-")
    outside_file = File.join(outside_dir, "secret.txt")
    File.write(outside_file, "secret")
    File.symlink(outside_file, version_v1.site_root_absolute_path.join(site_build_path, "escape.txt"))

    get project_site_path(project, site_path: "#{site_build_path}/escape.txt", version_id: version_v1.public_id)
    expect(response).to have_http_status(:not_found)
  ensure
    FileUtils.rm_rf(outside_dir) if outside_dir
  end

  it "keeps rendering html when access log creation fails" do
    sign_in_as(user)
    allow(AccessLog).to receive(:create!).and_raise(StandardError, "db down")

    get project_site_path(project, site_path: version_v1.html_view_site_path, version_id: version_v1.public_id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("見積対象・費用感整理")
  end
end
