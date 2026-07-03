require "rails_helper"
require "fileutils"

RSpec.describe "Project site path redirects", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "SITEREDIR", name: "Site Redirect Project") }
  let(:document) { create(:document, project:, title: "Site Redirect Document", slug: "site-redirect-document") }

  after do
    document.document_versions.find_each { |version| FileUtils.rm_rf(version.site_root_absolute_path) }
  end

  def create_site_version(label:, entry_path:)
    create(
      :document_version,
      document:,
      version_label: label,
      status: :published,
      markdown_entry_path: entry_path,
      site_build_path: entry_path
    ).tap do |version|
      index_path = version.site_root_absolute_path.join(entry_path, "index.html")
      FileUtils.mkdir_p(index_path.dirname)
      File.write(index_path, "<html></html>")
    end
  end

  it "redirects previous project site paths to the canonical site path without using a permanent redirect" do
    create_site_version(label: "v0.9.0", entry_path: "docs/previous-site")
    current_version = create_site_version(label: "v1.0.0", entry_path: "docs/current-site")
    document.update!(latest_version: current_version)

    sign_in_as(user)

    get project_site_path(project, version_id: current_version.public_id, site_path: "docs/previous-site")

    expect(response).to have_http_status(:found)
    expect(response).not_to have_http_status(:moved_permanently)
    expect(response.location).to include("/projects/#{project.code}/site/docs/current-site")
    expect(response.location).to include("previous_site_path=docs%2Fprevious-site")
    expect(response.location).to include("version_id=#{current_version.public_id}")
  end

  it "keeps embedded mode while redirecting previous project site paths without using a permanent redirect" do
    create_site_version(label: "v0.9.0", entry_path: "docs/previous-site")
    current_version = create_site_version(label: "v1.0.0", entry_path: "docs/current-site")
    document.update!(latest_version: current_version)

    sign_in_as(user)

    get project_site_path(project, version_id: current_version.public_id, site_path: "docs/previous-site/appendix", embedded: "1")

    expect(response).to have_http_status(:found)
    expect(response).not_to have_http_status(:moved_permanently)
    expect(response.location).to include("/projects/#{project.code}/site/docs/current-site/appendix")
    expect(response.location).to include("previous_site_path=docs%2Fprevious-site%2Fappendix")
    expect(response.location).to include("embedded=1")
  end

  it "carries the previous path from project site redirect into the reader notice" do
    create_site_version(label: "v0.9.0", entry_path: "docs/previous-site")
    current_version = create_site_version(label: "v1.0.0", entry_path: "docs/current-site")
    document.update!(latest_version: current_version)

    sign_in_as(user)

    get project_site_path(
      project,
      version_id: current_version.public_id,
      site_path: "docs/current-site",
      previous_site_path: "docs/previous-site"
    )

    expect(response).to have_http_status(:redirect)
    expect(response.location).to include("/projects/#{project.code}/documents/#{document.slug}")
    expect(response.location).to include("previous_site_path=docs%2Fprevious-site")

    get response.location

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("移動済み")
    expect(response.body).to include("旧URLから現在の文書位置へ移動しました")
    expect(response.body).to include("docs/previous-site")
    expect(response.body).to include("docs/current-site")
  end
end
