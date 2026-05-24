require "rails_helper"

RSpec.describe "Archived document restore visibility", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:company) { create(:company, domain: "client.example.com", name: "Client") }
  let(:external_user) { create(:user, :external, company:, email_address: "viewer@example.com") }
  let(:project) { create(:project, code: "ARCH01", name: "Archive Regression Project") }
  let(:document) do
    create(
      :document,
      project:,
      title: "運用ガイド",
      slug: "operations-guide",
      visibility_policy: :restricted_external
    )
  end
  let!(:published_version) do
    create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      status: :published
    )
  end

  def page_text
    Nokogiri::HTML(response.body).text
  end

  def result_titles
    html = Nokogiri::HTML(response.body)
    html.css("main table tbody tr td:first-child").map { _1.text.strip }
  end

  def archive_document!
    sign_in_as(admin_user)

    patch archive_admin_document_path(document)

    expect(response).to redirect_to(admin_documents_path)
    expect(document.reload).to be_archived
  end

  def restore_document!
    sign_in_as(admin_user)

    patch restore_admin_document_path(document)

    expect(response).to redirect_to(admin_documents_path)
    expect(document.reload).not_to be_archived
  end

  before do
    document.update!(latest_version: published_version)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "hides archived documents from external portal routes until restored" do
    sign_in_as(external_user)

    get project_path(project)
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("運用ガイド")

    get project_documents_path(project)
    expect(response).to have_http_status(:ok)
    expect(result_titles).to include("運用ガイド")

    get project_document_tree_path(project, format: :turbo_stream)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("運用ガイド")

    get project_document_path(project, document.slug)
    expect(response).to have_http_status(:ok)

    get document_version_path(published_version)
    expect(response).to have_http_status(:ok)

    archive_document!

    sign_in_as(external_user)

    get project_path(project)
    expect(response).to have_http_status(:ok)
    expect(page_text).not_to include("運用ガイド")

    get project_documents_path(project)
    expect(response).to have_http_status(:ok)
    expect(result_titles).not_to include("運用ガイド")

    get project_document_tree_path(project, format: :turbo_stream)
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("運用ガイド")

    get project_document_path(project, document.slug)
    expect(response).to have_http_status(:forbidden)

    get document_version_path(published_version)
    expect(response).to have_http_status(:forbidden)

    restore_document!

    sign_in_as(external_user)

    get project_path(project)
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("運用ガイド")

    get project_documents_path(project)
    expect(response).to have_http_status(:ok)
    expect(result_titles).to include("運用ガイド")

    get project_document_tree_path(project, format: :turbo_stream)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("運用ガイド")

    get project_document_path(project, document.slug)
    expect(response).to have_http_status(:ok)

    get document_version_path(published_version)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("v1.0.0")
  end

  it "also removes archived documents from internal portal routes until restored" do
    sign_in_as(admin_user)

    get project_documents_path(project)
    expect(response).to have_http_status(:ok)
    expect(result_titles).to include("運用ガイド")

    get project_document_path(project, document.slug)
    expect(response).to have_http_status(:ok)

    get document_version_path(published_version)
    expect(response).to have_http_status(:ok)

    archive_document!

    sign_in_as(admin_user)

    get project_documents_path(project)
    expect(response).to have_http_status(:ok)
    expect(result_titles).not_to include("運用ガイド")

    get project_document_path(project, document.slug)
    expect(response).to have_http_status(:forbidden)

    get document_version_path(published_version)
    expect(response).to have_http_status(:forbidden)

    restore_document!

    sign_in_as(admin_user)

    get project_documents_path(project)
    expect(response).to have_http_status(:ok)
    expect(result_titles).to include("運用ガイド")

    get project_document_path(project, document.slug)
    expect(response).to have_http_status(:ok)

    get document_version_path(published_version)
    expect(response).to have_http_status(:ok)
  end
end
