require "rails_helper"
require "fileutils"

RSpec.describe "Document path redirects", type: :request do
  let(:internal_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "PATHREDIR", name: "Path Redirect Project") }
  let(:document) { create(:document, project:, title: "Path Redirect Document", slug: "path-redirect-document") }

  after do
    document.document_versions.find_each { |version| FileUtils.rm_rf(version.site_root_absolute_path) }
  end

  def prepare_site(version)
    index_path = version.site_root_absolute_path.join(version.site_build_path, "index.html")
    FileUtils.mkdir_p(index_path.dirname)
    File.write(index_path, "<html></html>")
  end

  def create_version(label:, entry_path:)
    create(
      :document_version,
      document:,
      version_label: label,
      status: :published,
      markdown_entry_path: entry_path,
      site_build_path: entry_path
    ).tap { |version| prepare_site(version) }
  end

  it "redirects previous site paths to the current canonical site path" do
    create_version(label: "v0.9.0", entry_path: "docs/previous-guide")
    current_version = create_version(label: "v1.0.0", entry_path: "docs/current-guide")
    document.update!(latest_version: current_version)

    sign_in_as(internal_user)

    get project_document_path(project, document.slug, version_id: current_version.public_id, site_path: "docs/previous-guide")

    expect(response).to have_http_status(:moved_permanently)
    expect(response.location).to include("site_path=docs%2Fcurrent-guide")
    expect(response.location).to include("previous_site_path=docs%2Fprevious-guide")
    expect(response.location).to include("version_id=#{current_version.public_id}")
  end

  it "keeps nested suffixes when redirecting previous paths" do
    create_version(label: "v0.9.0", entry_path: "docs/previous-guide")
    current_version = create_version(label: "v1.0.0", entry_path: "docs/current-guide")
    document.update!(latest_version: current_version)

    sign_in_as(internal_user)

    get project_document_path(project, document.slug, version_id: current_version.public_id, site_path: "docs/previous-guide/appendix/page")

    expect(response).to have_http_status(:moved_permanently)
    expect(response.location).to include("site_path=docs%2Fcurrent-guide%2Fappendix%2Fpage")
    expect(response.location).to include("previous_site_path=docs%2Fprevious-guide%2Fappendix%2Fpage")
  end

  it "shows a notice after redirecting to the canonical reader path" do
    create_version(label: "v0.9.0", entry_path: "docs/previous-guide")
    current_version = create_version(label: "v1.0.0", entry_path: "docs/current-guide")
    document.update!(latest_version: current_version)

    sign_in_as(internal_user)

    get project_document_path(
      project,
      document.slug,
      version_id: current_version.public_id,
      site_path: "docs/current-guide",
      previous_site_path: "docs/previous-guide"
    )

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("現在の場所へ移動しました")
    expect(response.body).to include("docs/previous-guide")
    expect(response.body).to include("docs/current-guide")
  end
end
