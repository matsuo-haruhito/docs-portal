require "rails_helper"

RSpec.describe "Document sets", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, code: "SET1", name: "Sets Project") }
  let(:external_user) { create(:user, :external, company:) }
  let(:visible_document) { create(:document, project:, title: "公開仕様", slug: "public-doc", visibility_policy: :restricted_external) }
  let(:hidden_document) { create(:document, project:, title: "社内限定", slug: "private-doc", visibility_policy: :internal_only) }
  let!(:visible_version) { create(:document_version, document: visible_document, version_label: "v1.0.0") }
  let!(:hidden_version) { create(:document_version, document: hidden_document, version_label: "v1.0.0") }
  let!(:visible_permission) { create(:document_permission, document: visible_document, company:, access_level: :view) }

  before do
    create(:project_membership, project:, user: external_user)
  end

  it "shows only readable items to external users in a document set detail" do
    document_set = create(:document_set, project:, name: "顧客共有セット", visibility_policy: :restricted_external)
    create(:document_set_item, document_set:, document: hidden_document, document_version: hidden_version, sort_order: 1)
    create(:document_set_item, document_set:, document: visible_document, document_version: visible_version, sort_order: 2)

    sign_in_as(external_user)
    get project_document_set_path(project, document_set)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("顧客共有セット")
    expect(response.body).to include("公開仕様")
    expect(response.body).not_to include("社内限定")
    expect(response.body).to include("固定版")
  end

  it "hides internal-only document sets from external users in the list" do
    create(:document_set, project:, name: "社外共有", visibility_policy: :restricted_external)
    create(:document_set, project:, name: "社内専用", visibility_policy: :internal_only)

    sign_in_as(external_user)
    get project_document_sets_path(project)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("社外共有")
    expect(response.body).not_to include("社内専用")
  end
end
