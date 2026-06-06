require "rails_helper"

RSpec.describe "Document approval request user filter empty states", type: :request do
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:, name: "依頼 太郎") }
  let(:other_requester) { create(:user, :external, company:, name: "別の依頼者") }
  let(:approver) { create(:user, :internal, name: "確認 花子") }
  let(:other_approver) { create(:user, :internal, name: "別の確認者") }
  let(:internal_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "APR-FILTER", name: "Approval Filter Project") }
  let(:document) { create(:document, project:, title: "確認資料", slug: "approval-filter-doc", visibility_policy: :restricted_external) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.gsub(/[[:space:]]+/, " ").strip
  end

  before do
    create(:project_membership, project:, user: requester)
    create(:project_membership, project:, user: other_requester)
    create(:document_permission, document:, company:, access_level: :view)

    create(
      :document_approval_request,
      document:,
      requester:,
      approver:,
      title: "担当者filter確認依頼"
    )

    sign_in_as(internal_user)
  end

  it "shows a filtered empty state for requester-only filters" do
    get document_approval_requests_path, params: { requester_id: other_requester.id }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索条件: 依頼者指定 / 表示 0件")
    expect(page_text).to include("条件に一致する確認依頼はありません。検索語や状態を見直してください。")
    expect(page_text).to include("担当者条件を指定している場合は担当者絞り込みも見直してください。")
    expect(page_text).not_to include("担当者filter確認依頼")

    clear_user_filter_link = parsed_html.css("a[href]").find { |link| link.text.squish == "担当者絞り込みを解除" }
    expect(clear_user_filter_link).to be_present
    expect(clear_user_filter_link["href"]).to eq(document_approval_requests_path)
  end

  it "shows a filtered empty state for approver-only filters" do
    get document_approval_requests_path, params: { approver_id: other_approver.id }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索条件: 確認相手指定 / 表示 0件")
    expect(page_text).to include("条件に一致する確認依頼はありません。検索語や状態を見直してください。")
    expect(page_text).to include("担当者条件を指定している場合は担当者絞り込みも見直してください。")
    expect(page_text).not_to include("担当者filter確認依頼")

    clear_user_filter_link = parsed_html.css("a[href]").find { |link| link.text.squish == "担当者絞り込みを解除" }
    expect(clear_user_filter_link).to be_present
    expect(clear_user_filter_link["href"]).to eq(document_approval_requests_path)
  end
end
