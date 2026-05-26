require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe "Document views", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "PJ#{SecureRandom.hex(4)}", name: "Project #{SecureRandom.hex(2)}") }
  let(:document) { create(:document, project:, title: "運用手順", slug: "operation-manual") }

  def with_rendered_site_version(markdown_entry_path: "external_samples/sample-site/operation-manual", site_build_path: "external_samples/sample-site")
    version = create(
      :document_version,
      document:,
      version_label: "v#{SecureRandom.hex(3)}",
      markdown_entry_path:,
      site_build_path:
    )

    yield version
  ensure
    FileUtils.rm_rf(version.site_root_absolute_path) if version&.id
  end

  def write_site_file(version, relative_path, body)
    absolute_path = version.site_root_absolute_path.join(relative_path)
    FileUtils.mkdir_p(absolute_path.dirname)
    File.write(absolute_path, body)
  end

  def expect_latest_page_view_log(version:, target_name:)
    log = AccessLog.order(:id).last
    expect(log.user).to eq(user)
    expect(log.project).to eq(project)
    expect(log.document).to eq(document)
    expect(log.document_version).to eq(version)
    expect(log.action_type).to eq("view")
    expect(log.target_type).to eq("page")
    expect(log.target_name).to eq(target_name)
  end

  it "returns a clearer message when rendered html is unavailable" do
    version = create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      markdown_entry_path: "docs/README.md",
      site_build_path: "docs/v1.0.0"
    )

    sign_in_as(user)
    get view_document_version_path(version)

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("Rendered HTML is not available")
  end

  it "hides the rendered view link when html does not exist" do
    version = create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      markdown_entry_path: "docs/README.md",
      site_build_path: "docs/v1.0.0"
    )

    sign_in_as(user)
    get project_document_path(project, document.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(view_document_version_path(version))
  end

  it "redirects rendered html views to the unified document reader" do
    version = create(
      :document_version,
      document:,
      version_label: "v2.0.0",
      markdown_entry_path: "external_samples/sample-site/operation-manual",
      site_build_path: "external_samples/sample-site"
    )

    FileUtils.mkdir_p(version.site_root_absolute_path.join("external_samples/sample-site"))
    File.write(version.site_root_absolute_path.join("external_samples/sample-site", "operation-manual.html"), "<html></html>")
    File.write(version.site_root_absolute_path.join("external_samples/sample-site", "index.html"), "<html></html>")

    sign_in_as(user)
    get view_document_version_path(version)

    expect(response).to redirect_to(
      project_document_path(project, document.slug, version_id: version.public_id, site_path: version.html_view_site_path)
    )
  ensure
    FileUtils.rm_rf(version.site_root_absolute_path) if version&.id
  end

  it "records a page view access log for embedded project site html" do
    with_rendered_site_version do |version|
      write_site_file(version, "external_samples/sample-site/operation-manual.html", "<html><body>Rendered page</body></html>")
      write_site_file(version, "external_samples/sample-site/index.html", "<html><body>Index</body></html>")

      sign_in_as(user)

      expect do
        get project_site_path(project, site_path: version.html_view_site_path, version_id: version.public_id, embedded: "1")
      end.to change(AccessLog, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/html")
      expect_latest_page_view_log(version:, target_name: version.html_view_site_path)
    end
  end

  it "does not record an access log for project site assets" do
    with_rendered_site_version do |version|
      write_site_file(version, "assets/app.js", "console.log('asset');")

      sign_in_as(user)

      expect do
        get project_site_path(project, site_path: "assets/app.js", version_id: version.public_id)
      end.not_to change(AccessLog, :count)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("console.log('asset');")
    end
  end

  it "records a page view access log for the root document site html" do
    with_rendered_site_version(markdown_entry_path: nil) do |version|
      write_site_file(version, "external_samples/sample-site/index.html", "<html><body>Root page</body></html>")

      sign_in_as(user)

      expect do
        get site_document_version_path(version)
      end.to change(AccessLog, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/html")
      expect_latest_page_view_log(version:, target_name: version.site_build_path)
    end
  end

  it "does not record an access log for document site assets" do
    with_rendered_site_version(markdown_entry_path: nil) do |version|
      write_site_file(version, "assets/app.js", "console.log('document asset');")

      sign_in_as(user)

      expect do
        get site_document_version_path(version, site_path: "assets/app.js")
      end.not_to change(AccessLog, :count)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("console.log('document asset');")
    end
  end

  it "does not show archived versions to external users" do
    external_user = create(:user, :external)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company: external_user.company, access_level: :view)

    create(:document_version, document:, version_label: "v1.0.0", status: :published)
    create(:document_version, document:, version_label: "v0.9.0", status: :archived)

    sign_in_as(external_user)
    get project_document_path(project, document.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("v1.0.0")
    expect(response.body).not_to include("v0.9.0")
  end
end
