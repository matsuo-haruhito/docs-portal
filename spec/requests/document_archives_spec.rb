require "rails_helper"

RSpec.describe "Document archives", type: :request do
  let(:internal_user) { create(:user, :internal) }
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "ARC01", name: "Archive Project") }
  let(:document) { create(:document, project:, title: "Archive Me", slug: "archive-me", visibility_policy: :restricted_external) }
  let!(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "hides archived documents from normal internal and external routes" do
    document.archive!(actor: internal_user)

    sign_in_as(internal_user)
    get project_documents_path(project)
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Archive Me")

    get project_document_path(project, document.slug)
    expect(response).to have_http_status(:forbidden)

    sign_in_as(external_user)
    get project_documents_path(project)
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Archive Me")
  end
end
