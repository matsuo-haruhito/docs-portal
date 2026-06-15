require "rails_helper"

RSpec.describe "Document approval request empty state links", type: :request do
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:, name: "依頼 太郎") }
  let(:other_requester) { create(:user, :external, company:, name: "別の依頼者") }
  let(:approver) { create(:user, :internal, name: "確認 花子") }
  let(:internal_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "APR", name: "Approval Project") }
  let(:document) { create(:document, project:, title: "確認資料", slug: "approval-doc", visibility_policy: :restricted_external) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def link_named(text)
    parsed_html.css("a[href]").find { |link| link.text.squish == text }
  end

  before do
    create(:project_membership, project:, user: requester)
    create(:project_membership, project:, user: other_requester)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "shows focused reset links near the global filtered empty state" do
    create(:document_approval_request, document:, requester: other_requester, approver:, title: "別条件の確認依頼")

    sign_in_as(internal_user)

    get document_approval_requests_path, params: {
      status: :pending,
      q: "該当なし",
      requester_id: requester.id,
      approver_id: approver.id
    }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("条件に一致する確認依頼はありません。")

    expect(link_named("すべての確認依頼を見る")["href"]).to eq(document_approval_requests_path)
    expect(link_named("検索を解除")["href"]).to eq(
      document_approval_requests_path(status: :pending, requester_id: requester.id, approver_id: approver.id)
    )
    expect(link_named("担当者絞り込みを解除")["href"]).to eq(
      document_approval_requests_path(status: :pending, q: "該当なし")
    )
  end

  it "keeps nested document reset links on the nested list path" do
    create(:document_approval_request, document:, requester:, approver:, title: "対象外の確認依頼")

    sign_in_as(internal_user)

    get project_document_document_approval_requests_path(project, document), params: {
      status: :approved,
      q: "該当なし"
    }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("条件に一致する確認依頼はありません。")

    expect(link_named("すべての確認依頼を見る")["href"]).to eq(
      project_document_document_approval_requests_path(project, document)
    )
    expect(link_named("検索を解除")["href"]).to eq(
      project_document_document_approval_requests_path(project, document, status: :approved)
    )
    expect(link_named("担当者絞り込みを解除")).to be_nil
  end
end
