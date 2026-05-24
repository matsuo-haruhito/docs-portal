require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe "Document sites", type: :request do
  let(:site_build_path) { "docs-#{SecureRandom.hex(3)}/dispatch-api-spec/v1.0.0" }
  let(:user) { create(:user) }
  let(:project) { create(:project, code: "PJ#{SecureRandom.hex(4)}", name: "Project #{SecureRandom.hex(2)}") }
  let(:document) do
    create(
      :document,
      project:,
      title: "配車管理API仕様書",
      slug: "dispatch-api-spec"
    )
  end
  let(:version) do
    create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      site_build_path:
    )
  end

  before do
    FileUtils.mkdir_p(version.site_root_absolute_path.join(site_build_path))
    File.write(
      version.site_root_absolute_path.join(site_build_path, "index.html"),
      <<~HTML
        <!DOCTYPE html>
        <html>
          <head>
            <link rel="stylesheet" href="/assets/css/styles.css">
            <script src="../../assets/js/app.js"></script>
          </head>
          <body>
            <a href="../guide/getting-started">Guide</a>
            <h1>API Spec</h1>
          </body>
        </html>
      HTML
    )

    FileUtils.mkdir_p(Rails.root.join("docusaurus/build/assets/css"))
    File.write(Rails.root.join("docusaurus/build/assets/css/styles.css"), "body{background:#fff;}")
    FileUtils.mkdir_p(Rails.root.join("docusaurus/build/assets/js"))
    File.write(Rails.root.join("docusaurus/build/assets/js/app.js"), "console.log('ok')")
  end

  after do
    FileUtils.rm_rf(version.site_root_absolute_path) if version.id
  end

  it "serves a site viewer shell for version path containing dots" do
    sign_in_as(user)

    get site_document_version_path(version, site_path: site_build_path)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("site-viewer-hero")
    expect(response.body).to include("site-viewer-frame")
    expect(response.body).to include(site_document_version_path(version, site_path: site_build_path, embedded: "1").gsub("&", "&amp;"))
  end

  it "serves embedded docusaurus html for the iframe body" do
    sign_in_as(user)

    get site_document_version_path(version, site_path: site_build_path, embedded: "1")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("API Spec")
    expect(response.body).to include("portal-doc-body")
    expect(response.body).to include(%(data-docs-portal-preview-context-key="document_version:#{version.public_id}:#{version.normalized_html_view_site_path}"))
    expect(response.body).not_to include("portal-site-nav")
    expect(response.body).to include(site_document_version_path(version, site_path: "assets/css/styles.css", embedded: "1").gsub("&", "&amp;"))
  end

  it "serves shared docusaurus css asset when version storage does not include it" do
    sign_in_as(user)

    get site_document_version_path(version, site_path: "assets/css/styles.css")

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/css")
    expect(response.body).to include("background:#fff")
  end
end
