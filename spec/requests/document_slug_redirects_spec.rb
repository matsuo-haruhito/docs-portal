require "rails_helper"
require "fileutils"

RSpec.describe "Document slug redirects", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "SLUGREDIR", name: "Slug Redirect Project") }

  after do
    DocumentVersion.find_each { |version| FileUtils.rm_rf(version.site_root_absolute_path) }
  end

  def prepare_site(version)
    index_path = version.site_root_absolute_path.join(version.site_build_path, "index.html")
    FileUtils.mkdir_p(index_path.dirname)
    File.write(index_path, "<html></html>")
  end

  it "redirects a historical source-file slug to the current document slug" do
    document = create(:document, project:, title: "Current Guide", slug: "current-guide")
    version = create(
      :document_version,
      document:,
      status: :published,
      source_file_name: "previous-guide.md",
      markdown_entry_path: "docs/current-guide",
      site_build_path: "docs/current-guide"
    )
    document.update!(latest_version: version)
    prepare_site(version)

    sign_in_as(user)

    get project_document_path(project, "previous-guide")

    expect(response).to have_http_status(:found)
    expect(response.location).to include("/projects/#{project.code}/documents/current-guide")
    expect(response.location).to include("previous_slug=previous-guide")
  end

  it "shows a notice after redirecting to the canonical document slug" do
    document = create(:document, project:, title: "Current Guide", slug: "current-guide")
    version = create(
      :document_version,
      document:,
      status: :published,
      source_file_name: "previous-guide.md",
      markdown_entry_path: "docs/current-guide",
      site_build_path: "docs/current-guide"
    )
    document.update!(latest_version: version)
    prepare_site(version)

    sign_in_as(user)

    get project_document_path(project, document.slug, previous_slug: "previous-guide")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("移動済み")
    expect(response.body).to include("旧URLから現在の文書位置へ移動しました")
    expect(response.body).to include("previous-guide -&gt; current-guide")
  end
end
