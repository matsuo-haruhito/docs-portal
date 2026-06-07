require "rails_helper"

RSpec.describe "Document approval request filter summary", type: :request do
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:, name: "依頼 太郎") }
  let(:approver) { create(:user, :internal, name: "確認 花子") }
  let(:internal_user) { create(:user, :internal, name: "一覧 管理者") }
  let(:project) { create(:project, code: "APR", name: "Approval Project") }
  let(:document) { create(:document, project:, title: "公開前確認資料", slug: "approval-filter-doc", visibility_policy: :restricted_external) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.gsub(/[[:space:]]+/, " ").strip
  end

  def create_request!(title:, requester: self.requester, approver: self.approver, status: :pending, body: "契約条項を確認してください")
    attributes = {
      document:,
      requester:,
      approver:,
      title:,
      body:,
      status:
    }

    if status == :approved
      attributes[:acted_by] = internal_user
      attributes[:approved_at] = 1.hour.ago
      attributes[:cancelled_at] = nil
    elsif status == :cancelled
      attributes[:acted_by] = requester
      attributes[:cancelled_at] = 1.hour.ago
      attributes[:approved_at] = nil
    end

    create(:document_approval_request, **attributes)
  end

  before do
    create(:project_membership, project:, user: requester)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "shows readable active filter labels without changing clear link behavior" do
    matching_request = create_request!(title: "契約レビュー依頼")
    create_request!(title: "契約レビューOK", status: :approved)

    sign_in_as(internal_user)

    get document_approval_requests_path, params: {
      status: :pending,
      q: "契約",
      requester_id: requester.id,
      approver_id: approver.id
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(matching_request.title)
    expect(page_text).to include("表示中条件: 状態: 対応待ち / 検索語: 契約 / 依頼者: 依頼 太郎 / 確認相手: 確認 花子")
    expect(page_text).to include("状態ボタンの件数は一覧全体の件数です。下の表示件数と各セクション件数は、選択中の状態・検索語・担当者条件を反映しています。")
    expect(page_text).to include("検索を解除は検索語だけを外し、担当者絞り込みを解除は依頼者・確認相手だけを外します。状態タブが選択されている場合は維持されます。")
    expect(page_text).to include("検索条件: 契約 / 依頼者指定 / 確認相手指定 / 表示 1件")
    expect(page_text).to include("表示設定は列の見せ方だけを変えます。検索条件や状態別件数を変える場合は、上の検索フォームと状態ボタンを使ってください。")

    clear_search_link = parsed_html.css("a[href]").find { |link| link.text.squish == "検索を解除" }
    expect(clear_search_link).to be_present
    clear_search_params = Rack::Utils.parse_nested_query(URI.parse(clear_search_link["href"]).query)
    expect(clear_search_params).to include(
      "status" => "pending",
      "requester_id" => requester.id.to_s,
      "approver_id" => approver.id.to_s
    )
    expect(clear_search_params).not_to have_key("q")

    clear_user_filter_link = parsed_html.css("a[href]").find { |link| link.text.squish == "担当者絞り込みを解除" }
    expect(clear_user_filter_link).to be_present
    clear_user_filter_params = Rack::Utils.parse_nested_query(URI.parse(clear_user_filter_link["href"]).query)
    expect(clear_user_filter_params).to include(
      "status" => "pending",
      "q" => "契約"
    )
    expect(clear_user_filter_params).not_to have_key("requester_id")
    expect(clear_user_filter_params).not_to have_key("approver_id")
  end

  it "keeps the filtered empty state aligned with the active filter summary" do
    create_request!(title: "OK済み確認", status: :approved, body: "公開前確認")

    sign_in_as(internal_user)

    get document_approval_requests_path, params: { status: :pending, q: "該当なし" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中条件: 状態: 対応待ち / 検索語: 該当なし")
    expect(page_text).to include("状態ボタンの件数は一覧全体の件数です。下の表示件数と各セクション件数は、選択中の状態・検索語・担当者条件を反映しています。")
    expect(page_text).to include("検索条件: 該当なし / 表示 0件")
    expect(page_text).to include("条件に一致する確認依頼はありません。検索語や状態を見直してください。")
    expect(page_text).not_to include("表示設定は列の見せ方だけを変えます。")
  end
end
