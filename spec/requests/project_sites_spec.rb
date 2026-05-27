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
    File.write(
      version_v1.site_root_absolute_path.join("assets", "js", "runtime~main.app.js"),
      '(()=>{f.p="/";var d=f.p+f.u(r);return f.p+f.u(e)})();'
    )

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

  it "redirects a non-embedded project site html page to the unified document reader and records a page view access log" do
    sign_in_as(user)

    expect do
      get project_site_path(project, site_path: version_v1.html_view_site_path, version_id: version_v1.public_id)
    end.to change(AccessLog, :count).by(1)

    expect(response).to redirect_to(project_document_path(project, document.slug, version_id: version_v1.public_id, site_path: version_v1.html_view_site_path))

    log = AccessLog.order(:id).last
    expect(log.user).to eq(user)
    expect(log.project).to eq(project)
    expect(log.document).to eq(document)
    expect(log.document_version).to eq(version_v1)
    expect(log.action_type).to eq("view")
    expect(log.target_type).to eq("page")
    expect(log.target_name).to eq(version_v1.html_view_site_path)
  end

  it "renders embedded project site html for the iframe body" do
    sign_in_as(user)

    get project_site_path(project, site_path: version_v1.html_view_site_path, version_id: version_v1.public_id, embedded: "1")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("見積対象・費用感整理")
    expect(response.body).to include("portal-doc-body")
    expect(response.body).to include(%(data-docs-portal-preview-context-key="document_version:#{version_v1.public_id}:#{version_v1.normalized_html_view_site_path}"))
    expect(response.body).to include("data-docs-portal-embedded-viewer=\"true\"")
    expect(response.body).to include("data-docs-portal-embedded-height-sync=\"true\"")
    expect(response.body).to include('docs-portal:site-viewer-height')
    expect(response.body).not_to include("portal-site-nav")
    expect(response.body).not_to include("案件トップへ戻る")
    expect(response.body).to include(project_site_path(project, site_path: "external_samples/sample-site/edit-original/other-doc", version_id: version_v1.public_id, embedded: "1").gsub("&", "&amp;"))
    expect(response.body).to include(project_site_path(project, site_path: "assets/css/app.css", version_id: version_v1.public_id, embedded: "1").gsub("&", "&amp;"))
    expect(response.body).to include(project_site_path(project, site_path: "assets/js/app.js", version_id: version_v1.public_id, embedded: "1").gsub("&", "&amp;"))
  end

  it "uses the same preview context key for project and document embedded routes of the same page" do
    sign_in_as(user)

    get project_site_path(project, site_path: version_v1.html_view_site_path, version_id: version_v1.public_id, embedded: "1")
    project_context_key = Nokogiri::HTML(response.body).at_css("body")&.[]("data-docs-portal-preview-context-key")

    get site_document_version_path(version_v1, site_path: version_v1.html_view_site_path, embedded: "1")
    document_context_key = Nokogiri::HTML(response.body).at_css("body")&.[]("data-docs-portal-preview-context-key")

    expect(project_context_key).to eq("document_version:#{version_v1.public_id}:#{version_v1.normalized_html_view_site_path}")
    expect(document_context_key).to eq(project_context_key)
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

  it "rewrites Docusaurus runtime chunk paths to the project site route" do
    sign_in_as(user)

    get project_site_path(project, site_path: "assets/js/runtime~main.app.js", version_id: version_v1.public_id, embedded: "1")

    proxied_site_root = project_site_path(project, site_path: "__docs_portal_asset__").delete_suffix("__docs_portal_asset__")
    asset_query = "?embedded=1&version_id=#{version_v1.public_id}"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("f.p=#{proxied_site_root.dump}")
    expect(response.body).to include("f.p+f.u(r)+#{asset_query.dump}")
    expect(response.body).to include("f.p+f.u(e)+#{asset_query.dump}")
  end

  it "resolves markdown-style index paths to generated html" do
    sign_in_as(user)

    get project_site_path(project, site_path: "#{site_build_path}/guide/index.md", version_id: version_v1.public_id, embedded: "1")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Guide Index")
  end

  it "shows a document reader link on the project detail page" do
    sign_in_as(user)

    get project_path(project)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("文書を読む")
    expect(response.body).to include(project_document_path(project, document.slug, version_id: version_v2.public_id, site_path: version_v2.html_view_site_path).gsub("&", "&amp;"))
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

  it "filters restricted site navigation links for external users and blocks direct page access without recording an access log" do
    external_user = create(:user, :external)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company: external_user.company, access_level: :view)

    sign_in_as(external_user)

    get project_site_path(project, site_path: version_v1.html_view_site_path, version_id: version_v1.public_id, embedded: "1")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Allowed page")
    expect(response.body).not_to include("Restricted page")

    expect do
      get project_site_path(project, site_path: restricted_version.html_view_site_path, version_id: version_v1.public_id)
    end.not_to change(AccessLog, :count)

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

    get project_site_path(project, site_path: version_v1.html_view_site_path, version_id: version_v1.public_id, embedded: "1")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("見積対象・費用感整理")
  end
end
