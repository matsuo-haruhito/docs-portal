require "rails_helper"

RSpec.describe "Document sets", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, code: "SET1", name: "Sets Project") }
  let(:external_user) { create(:user, :external, company:) }
  let(:visible_document) { create(:document, project:, title: "公開仕様", slug: "public-doc", visibility_policy: :restricted_external) }
  let(:hidden_document) { create(:document, project:, title: "社内限定", slug: "private-doc", visibility_policy: :internal_only) }
  let(:no_version_document) { create(:document, project:, title: "版未作成", slug: "missing-version-doc", visibility_policy: :restricted_external) }
  let!(:visible_version) { create(:document_version, document: visible_document, version_label: "v1.0.0") }
  let!(:hidden_version) { create(:document_version, document: hidden_document, version_label: "v1.0.0") }
  let!(:visible_permission) { create(:document_permission, document: visible_document, company:, access_level: :view) }
  let!(:no_version_permission) { create(:document_permission, document: no_version_document, company:, access_level: :view) }

  before do
    create(:project_membership, project:, user: external_user)
  end

  it "shows only readable items to external users in a document set detail" do
    document_set = create(:document_set, project:, name: "顧客共有セット", visibility_policy: :restricted_external)
    create(:document_set_item, document_set:, document: hidden_document, document_version: hidden_version, sort_order: 1)
    create(:document_set_item, document_set:, document: visible_document, document_version: visible_version, sort_order: 2)
    create(:document_set_item, document_set:, document: no_version_document, sort_order: 3)

    sign_in_as(external_user)
    get project_document_set_path(project, document_set)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("顧客共有セット")
    expect(response.body).to include("公開仕様")
    expect(response.body).to include("版未作成")
    expect(response.body).not_to include("社内限定")
    expect(response.body).to include("固定版")
    expect(response.body).to include("現在の利用者に表示できる文書を対象に、外部送付の下書きを準備します。")
    expect(response.body).to include("文書ごとの使用版を確認してください。")
    expect(response.body).to include("利用可能な版なし")
    expect(response.body).to include(new_project_document_set_document_delivery_log_path(project, document_set))
  end

  it "explains the delivery preparation cue when the document set has no visible items" do
    document_set = create(:document_set, project:, name: "空の共有セット", visibility_policy: :restricted_external)

    sign_in_as(external_user)
    get project_document_set_path(project, document_set)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("外部送付を準備")
    expect(response.body).to include(new_project_document_set_document_delivery_log_path(project, document_set))
    expect(response.body).to include("表示できる文書はありません。")
    expect(response.body).to include("このセットには現在の利用者に表示できる文書がありません。")
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
