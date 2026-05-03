require "rails_helper"
require "securerandom"

RSpec.describe "Document tree view", type: :request do
  let(:user) { create(:user) }
  let(:project) { create(:project, code: "PJ#{SecureRandom.hex(4)}", name: "Project #{SecureRandom.hex(2)}") }
  let!(:document) do
    create(
      :document,
      project:,
      title: "配車管理API仕様書",
      slug: "dispatch-api-spec"
    )
  end

  before do
    create(:document_version, document:, version_label: "v1.0.0")
  end

  it "renders project and document tree navigation on document detail" do
    sign_in_as(user)
    get project_document_path(project, document.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("文書ツリー")
    expect(response.body).to include("#{project.code} #{project.name}")
    expect(response.body).to include("配車管理API仕様書")
    expect(response.body).to include("tree-view-table")
  end

  it "renders tree navigation on project detail and documents index" do
    sign_in_as(user)

    get project_path(project)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("文書ツリー")
    expect(response.body).to include("tree-view-table")

    get project_documents_path(project)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("文書ツリー")
    expect(response.body).to include("tree-view-table")
  end
end
