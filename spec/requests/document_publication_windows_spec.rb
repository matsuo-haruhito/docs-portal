require "rails_helper"
require "fileutils"

RSpec.describe "Document publication windows", type: :request do
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "PUBWIN", name: "Publication Window Project") }
  let(:future_only_project) { create(:project, code: "FUTURE", name: "Future Only Project") }

  def create_document_with_file(title:, slug:, published_from: nil, published_until: nil)
    document = create(:document, project:, title:, slug:, visibility_policy: :restricted_external)
    version = create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      status: :published,
      published_from:,
      published_until:
    )
    document.update!(latest_version: version)
    create(:document_permission, document:, company:, access_level: :download)
    file = create(
      :document_file,
      document_version: version,
      file_name: "#{slug}.pdf",
      content_type: "application/pdf",
      storage_key: "spec/#{slug}.pdf",
      file_size: 8,
      scan_status: :scan_clean
    )
    FileUtils.mkdir_p(file.absolute_path.dirname)
    File.binwrite(file.absolute_path, "%PDF-1.4")
    [document, version, file]
  end

  before do
    create(:project_membership, project:, user: external_user)
    create(:project_membership, project: future_only_project, user: external_user)
  end

  after do
    FileUtils.rm_rf(Rails.root.join("storage", "document_files", "spec"))
  end

  it "hides not-started and expired documents from external project/document views" do
    visible_document, visible_version, = create_document_with_file(title: "Visible", slug: "visible")
    create_document_with_file(title: "Future", slug: "future", published_from: 1.day.from_now)
    create_document_with_file(title: "Expired", slug: "expired", published_until: 1.day.ago)

    sign_in_as(external_user)

    get project_path(project)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Visible")
    expect(response.body).not_to include("Future")
    expect(response.body).not_to include("Expired")

    get project_documents_path(project)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Visible")
    expect(response.body).not_to include("Future")
    expect(response.body).not_to include("Expired")

    get project_document_path(project, visible_document.slug)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(visible_version.version_label)

    get project_document_path(project, "future")
    expect(response).to have_http_status(:forbidden)

    get project_document_path(project, "expired")
    expect(response).to have_http_status(:forbidden)
  end

  it "hides projects that do not currently have any externally visible documents" do
    create_document_with_file(title: "Visible", slug: "visible")

    future_document = create(:document, project: future_only_project, title: "Future", slug: "future-only", visibility_policy: :restricted_external)
    future_version = create(:document_version, document: future_document, version_label: "v1.0.0", status: :published, published_from: 1.day.from_now)
    future_document.update!(latest_version: future_version)
    create(:document_permission, document: future_document, company:, access_level: :view)

    sign_in_as(external_user)
    get projects_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Publication Window Project")
    expect(response.body).not_to include("Future Only Project")
  end

  it "blocks external downloads and AI export for versions outside the publication window" do
    visible_document, = create_document_with_file(title: "Visible", slug: "visible")
    future_document, future_version, future_file = create_document_with_file(title: "Future", slug: "future", published_from: 1.day.from_now)

    sign_in_as(external_user)

    get document_file_path(future_file)
    expect(response).to have_http_status(:forbidden)

    get document_version_archive_path(future_version)
    expect(response).to have_http_status(:forbidden)

    get project_ai_context_path(project, format: :json)
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body.fetch("documents").map { _1.fetch("public_id") }).to eq([visible_document.public_id])
    expect(body.fetch("documents").map { _1.fetch("slug") }).not_to include(future_document.slug)
  end
end
