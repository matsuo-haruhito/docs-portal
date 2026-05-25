require "rails_helper"

RSpec.describe "AccessibleDocuments", type: :request do
  let(:company) { create(:company) }
  let(:project_a) { create(:project, name: "Alpha Project") }
  let(:project_b) { create(:project, name: "Beta Project") }
  let(:user) { create(:user, :external, company:) }

  def create_viewable_document(project:, title:, slug:)
    document = create(:document, project:, title:, slug:, visibility_policy: :restricted_external)
    create(:document_permission, document:, company:, access_level: :view)
    document
  end

  before do
    create(:project_membership, project: project_a, user:)
    create(:project_membership, project: project_b, user:)
  end

  it "shows readable documents across accessible projects" do
    alpha = create_viewable_document(project: project_a, title: "Alpha Manual", slug: "alpha-manual")
    beta = create_viewable_document(project: project_b, title: "Beta Guide", slug: "beta-guide")
    hidden = create(:document, project: project_b, title: "Hidden Manual", slug: "hidden-manual", visibility_policy: :internal_only)

    sign_in_as(user)
    get documents_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("閲覧可能文書")
    expect(response.body).to include(alpha.title, beta.title)
    expect(response.body).to include(project_a.name, project_b.name)
    expect(response.body).not_to include(hidden.title)
  end

  it "supports keyword filtering and pagination" do
    20.times do |index|
      create_viewable_document(project: project_a, title: "Reference #{index}", slug: "reference-#{index}")
    end
    target = create_viewable_document(project: project_b, title: "Approval Handbook", slug: "approval-handbook")
    other = create_viewable_document(project: project_b, title: "Billing Handbook", slug: "billing-handbook")

    sign_in_as(user)
    get documents_path, params: { q: "Approval" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(target.title)
    expect(response.body).not_to include(other.title)

    get documents_path, params: { page: 2 }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("ページ 2 / 2")
  end

  it "keeps internal-only documents available to internal users" do
    internal_user = create(:user, :internal)
    internal_project = create(:project, name: "Internal Project")
    internal_document = create(:document, project: internal_project, title: "Internal Handbook", slug: "internal-handbook", visibility_policy: :internal_only)
    create(:project_membership, project: internal_project, user: internal_user)

    sign_in_as(internal_user)
    get documents_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(internal_document.title)
  end
end
