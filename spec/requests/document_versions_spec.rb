require "rails_helper"

RSpec.describe "Document versions", type: :request do
  let(:internal_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }
  let(:project) { create(:project, code: "VERSIONED", name: "Versioned Project") }
  let(:document) { create(:document, project:, title: "Versioned Document", slug: "versioned-document") }

  it "shows version metadata, files, and links to other versions" do
    older_version = create(:document_version, document:, version_label: "v0.9.0", status: :archived)
    version = create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      status: :published,
      changelog_summary: "initial release",
      markdown_entry_path: "docs/versioned-document",
      site_build_path: "docs/versioned-document"
    )
    document.update!(latest_version: version)
    DocumentFile.create!(
      document_version: version,
      file_name: "README.md",
      content_type: "text/markdown",
      storage_key: "spec/versioned-document/README.md",
      file_size: 123,
      sort_order: 0
    )

    sign_in_as(internal_user)

    get document_version_path(version)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Versioned Document")
    expect(response.body).to include("v1.0.0")
    expect(response.body).to include("initial release")
    expect(response.body).to include("README.md")
    expect(response.body).to include(older_version.version_label)
  end

  it "links from document detail to each visible version detail" do
    version = create(:document_version, document:, version_label: "v1.0.0", status: :published)
    document.update!(latest_version: version)

    sign_in_as(internal_user)

    get project_document_path(project, document.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(document_version_path(version))
  end

  it "applies external user visibility rules to version detail pages" do
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company: external_user.company, access_level: :view)
    published_version = create(:document_version, document:, version_label: "v1.0.0", status: :published)
    draft_version = create(:document_version, document:, version_label: "v1.1.0", status: :draft)
    archived_version = create(:document_version, document:, version_label: "v0.9.0", status: :archived)

    sign_in_as(external_user)

    get document_version_path(published_version)
    expect(response).to have_http_status(:ok)

    get document_version_path(draft_version)
    expect(response).to have_http_status(:forbidden)

    get document_version_path(archived_version)
    expect(response).to have_http_status(:forbidden)
  end
end
