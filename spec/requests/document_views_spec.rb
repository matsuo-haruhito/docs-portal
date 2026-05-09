require "rails_helper"
require "securerandom"

RSpec.describe "Document views", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "PJ#{SecureRandom.hex(4)}", name: "Project #{SecureRandom.hex(2)}") }
  let(:document) { create(:document, project:, title: "運用手順", slug: "operation-manual") }

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
