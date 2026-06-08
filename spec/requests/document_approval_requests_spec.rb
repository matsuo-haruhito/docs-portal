require "rails_helper"

RSpec.describe "Document approval requests", type: :request do
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:) }
  let(:internal_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "APR", name: "Approval Project") }
  let(:document) { create(:document, project:, title: "確認資料", slug: "approval-doc", visibility_policy: :restricted_external) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.gsub(/[[:space:]]+/, " ").strip
  end

  before do
    create(:project_membership, project:, user: requester)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "creates an approval request from document detail" do
    sign_in_as(requester)

    expect do
      post project_document_document_approval_requests_path(project, document), params: {
        document_approval_request: {
          title: "確認お願いします",
          body: "公開前に見てください"
        }
      }
    end.to change(DocumentApprovalRequest, :count).by(1)

    approval_request = DocumentApprovalRequest.order(:id).last
    expect(response).to redirect_to(document_approval_request_path(approval_request, return_to: project_document_path(project, document.slug)))
    expect(approval_request.requester).to eq(requester)
    expect(approval_request.document).to eq(document)
    expect(approval_request).to be_pending
  end

  it "shows pending requests before processed ones and supports status filtering" do
    pending_request = create(:document_approval_request, document:, requester:, title: "確認お願いします")
    approved_request = create(
      :document_approval_request,
      document:,
      requester:,
      title: "確認完了",
      status: :approved,
      acted_by: internal_user,
      approved_at: 1.hour.ago,
      cancelled_at: nil
    )
    cancelled_request = create(
      :document_approval_request,
      document:,
      requester:,
      title: "今回は進めない",
      status: :cancelled,
      acted_by: requester,
      cancelled_at: 30.minutes.ago,
      approved_at: nil
    )

    sign_in_as(internal_user)

    get project_document_document_approval_requests_path(project, document)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("対応待ち")
    expect(response.body).to include("処理済み")
    expect(response.body).to include("対応待ち (1)")
    expect(response.body).to include("OK済み (1)")
    expect(response.body).to include("Cancel済み (1)")
    expect(response.body).to include(pending_request.title)
    expect(response.body).to include(approved_request.title)
    expect(response.body).to include(cancelled_request.title)

    get project_document_document_approval_requests_path(project, document), params: { status: :pending }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(pending_request.title)
    expect(response.body).not_to include(approved_request.title)
    expect(response.body).not_to include(cancelled_request.title)
    detail_link = parsed_html.at_css(%(a[href="#{document_approval_request_path(pending_request, return_to: project_document_document_approval_requests_path(project, document, status: :pending))}"]))
    expect(detail_link).to be_present

    get document_approval_requests_path, params: { status: :approved }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(approved_request.title)
    expect(response.body).not_to include(pending_request.title)
    expect(response.body).not_to include(cancelled_request.title)
  end

  it "searches requests by query and keeps status filters" do
    matching_request = create(
      :document_approval_request,
      document:,
      requester:,
      title: "契約レビュー依頼",
      body: "公開前に契約条項を確認してください"
    )
    approved_match = create(
      :document_approval_request,
      document:,
      requester:,
      title: "契約レビュー完了",
      status: :approved,
      acted_by: internal_user,
      approved_at: 1.hour.ago,
      cancelled_at: nil
    )
    non_matching_request = create(:document_approval_request, document:, requester:, title: "請求書レビュー")

    sign_in_as(internal_user)

    get document_approval_requests_path, params: { q: "契約" }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(matching_request.title)
    expect(response.body).to include(approved_match.title)
    expect(response.body).not_to include(non_matching_request.title)
    expect(response.body).to include("検索条件: 契約")
    expect(parsed_html.at_css(%(a[href="#{document_approval_requests_path(q: "契約", status: :pending)}"]))).to be_present

    get document_approval_requests_path, params: { status: :approved, q: "契約" }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(approved_match.title)
    expect(response.body).not_to include(matching_request.title)
    expect(response.body).not_to include(non_matching_request.title)

    get document_approval_requests_path, params: { q: "   " }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(matching_request.title)
    expect(response.body).to include(non_matching_request.title)
  end

  it "bounds overlong queries without changing global or nested search targets" do
    bounded_query = "q" * DocumentApprovalRequestsController::QUERY_MAX_LENGTH
    too_long_query = "  #{bounded_query}ignored  "
    matching_request = create(:document_approval_request, document:, requester:, title: "#{bounded_query} global")
    non_matching_request = create(:document_approval_request, document:, requester:, title: "ignored-only request")
    other_document = create(:document, project:, title: "Other approval", slug: "other-approval-doc", visibility_policy: :restricted_external)
    create(:document_permission, document: other_document, company:, access_level: :view)
    nested_request = create(:document_approval_request, document:, requester:, title: "#{bounded_query} nested")
    other_document_request = create(:document_approval_request, document: other_document, requester:, title: "#{bounded_query} other document")

    sign_in_as(internal_user)

    get document_approval_requests_path, params: { q: too_long_query }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(matching_request.title)
    expect(response.body).to include(nested_request.title)
    expect(response.body).to include(other_document_request.title)
    expect(response.body).not_to include(non_matching_request.title)
    expect(page_text).to include("検索条件: #{bounded_query}")

    get project_document_document_approval_requests_path(project, document), params: { q: too_long_query }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(matching_request.title)
    expect(response.body).to include(nested_request.title)
    expect(response.body).not_to include(other_document_request.title)
    expect(response.body).not_to include(non_matching_request.title)
    expect(page_text).to include("検索条件: #{bounded_query}")
  end

  it "filters the global index by requester and approver while keeping query, status, and return_to" do
    other_requester = create(:user, :external, company:, name: "別の依頼者")
    matching_approver = create(:user, :internal, name: "確認 花子")
    other_approver = create(:user, :internal, name: "別の確認者")
    create(:project_membership, project:, user: other_requester)

    matching_request = create(
      :document_approval_request,
      document:,
      requester:,
      approver: matching_approver,
      title: "契約レビュー依頼",
      body: "契約条項を確認してください"
    )
    other_requester_request = create(
      :document_approval_request,
      document:,
      requester: other_requester,
      approver: matching_approver,
      title: "契約レビュー 別依頼者",
      body: "契約条項を確認してください"
    )
    other_approver_request = create(
      :document_approval_request,
      document:,
      requester:,
      approver: other_approver,
      title: "契約レビュー 別確認者",
      body: "契約条項を確認してください"
    )
    approved_match = create(
      :document_approval_request,
      document:,
      requester:,
      approver: matching_approver,
      title: "契約レビュー OK済み",
      body: "契約条項を確認してください",
      status: :approved,
      acted_by: matching_approver,
      approved_at: 1.hour.ago,
      cancelled_at: nil
    )

    sign_in_as(internal_user)

    get document_approval_requests_path, params: { requester_id: requester.id }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(matching_request.title)
    expect(response.body).to include(other_approver_request.title)
    expect(response.body).to include(approved_match.title)
    expect(response.body).not_to include(other_requester_request.title)
    expect(parsed_html.at_css(%(select[name="requester_id"] option[value="#{requester.id}"][selected]))).to be_present

    get document_approval_requests_path, params: { approver_id: matching_approver.id }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(matching_request.title)
    expect(response.body).to include(other_requester_request.title)
    expect(response.body).to include(approved_match.title)
    expect(response.body).not_to include(other_approver_request.title)
    expect(parsed_html.at_css(%(select[name="approver_id"] option[value="#{matching_approver.id}"][selected]))).to be_present

    get document_approval_requests_path, params: {
      status: :pending,
      q: "契約",
      requester_id: requester.id,
      approver_id: matching_approver.id
    }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(matching_request.title)
    expect(response.body).not_to include(other_requester_request.title)
    expect(response.body).not_to include(other_approver_request.title)
    expect(response.body).not_to include(approved_match.title)
    expect(page_text).to include("検索条件: 契約 / 依頼者指定 / 確認相手指定 / 表示 1件")

    status_link = parsed_html.css("a[href]").find { |link| link.text.squish.start_with?("OK済み") }
    expect(status_link).to be_present
    status_params = Rack::Utils.parse_nested_query(URI.parse(status_link["href"]).query)
    expect(status_params).to include(
      "q" => "契約",
      "requester_id" => requester.id.to_s,
      "approver_id" => matching_approver.id.to_s,
      "status" => "approved"
    )

    detail_link = parsed_html.css(%(a[href^="#{document_approval_request_path(matching_request)}"])).find { |link| link.text == matching_request.title }
    expect(detail_link).to be_present
    detail_params = Rack::Utils.parse_nested_query(URI.parse(detail_link["href"]).query)
    return_to = URI.parse(detail_params.fetch("return_to"))
    return_to_params = Rack::Utils.parse_nested_query(return_to.query)
    expect(return_to.path).to eq(document_approval_requests_path)
    expect(return_to_params).to include(
      "status" => "pending",
      "q" => "契約",
      "requester_id" => requester.id.to_s,
      "approver_id" => matching_approver.id.to_s
    )

    patch document_approval_request_path(matching_request, return_to: detail_params.fetch("return_to"))
    expect(response).to redirect_to(document_approval_request_path(matching_request, return_to: detail_params.fetch("return_to")))
  end

  it "handles invalid requester and approver filters without failing" do
    approval_request = create(:document_approval_request, document:, requester:, title: "通常の確認依頼")
    missing_user_id = User.maximum(:id).to_i + 10_000

    sign_in_as(internal_user)

    get document_approval_requests_path, params: { requester_id: "not-a-user", approver_id: "also-invalid" }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(approval_request.title)
    expect(response.body).not_to include("not-a-user")
    expect(response.body).not_to include("also-invalid")

    get document_approval_requests_path, params: { requester_id: missing_user_id }
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(approval_request.title)
    expect(page_text).to include("確認依頼はありません。")
  end

  it "distinguishes unregistered and filtered empty states without changing clear search links" do
    sign_in_as(internal_user)

    get document_approval_requests_path
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("確認依頼はありません。")
    expect(page_text).not_to include("条件に一致する確認依頼はありません。検索語や状態を見直してください。")

    approved_request = create(
      :document_approval_request,
      document:,
      requester:,
      title: "承認済みの確認依頼",
      status: :approved,
      acted_by: internal_user,
      approved_at: 1.hour.ago,
      cancelled_at: nil
    )

    get document_approval_requests_path, params: { status: :pending }
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(approved_request.title)
    expect(page_text).to include("条件に一致する確認依頼はありません。検索語や状態を見直してください。")
    expect(parsed_html.at_css(%(a[href="#{document_approval_requests_path(status: :approved)}"]))).to be_present

    get document_approval_requests_path, params: { q: "該当なし" }
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(approved_request.title)
    expect(page_text).to include("検索条件: 該当なし / 表示 0件")
    expect(page_text).to include("条件に一致する確認依頼はありません。検索語や状態を見直してください。")
    clear_search_link = parsed_html.css("a[href]").find { |link| link.text.squish == "検索を解除" }
    expect(clear_search_link).to be_present
    expect(clear_search_link["href"]).to eq(document_approval_requests_path)
  end

  it "searches within the nested document scope and preserves query in return_to" do
    approver = create(:user, :internal, name: "確認担当")
    nested_request = create(:document_approval_request, document:, requester:, approver:, title: "契約対象内レビュー")
    other_document = create(:document, project:, title: "契約対象外資料", slug: "other-approval-doc", visibility_policy: :restricted_external)
    create(:document_permission, document: other_document, company:, access_level: :view)
    other_request = create(:document_approval_request, document: other_document, requester:, approver:, title: "契約対象外レビュー")

    sign_in_as(internal_user)

    get project_document_document_approval_requests_path(project, document), params: { status: :pending, q: "契約", requester_id: requester.id, approver_id: approver.id }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(nested_request.title)
    expect(response.body).not_to include(other_request.title)

    detail_link = parsed_html.css(%(a[href^="#{document_approval_request_path(nested_request)}"])).find { |link| link.text == nested_request.title }
    expect(detail_link).to be_present
    detail_params = Rack::Utils.parse_nested_query(URI.parse(detail_link["href"]).query)
    return_to = URI.parse(detail_params.fetch("return_to"))
    return_to_params = Rack::Utils.parse_nested_query(return_to.query)
    expect(return_to.path).to eq(project_document_document_approval_requests_path(project, document))
    expect(return_to_params).to include(
      "status" => "pending",
      "q" => "契約",
      "requester_id" => requester.id.to_s,
      "approver_id" => approver.id.to_s
    )
  end

  it "shows detail to internal users and supports OK / Cancel" do
    approval_request = create(:document_approval_request, document:, requester:, title: "確認お願いします")
    return_to_path = project_document_document_approval_requests_path(project, document, status: :pending)

    sign_in_as(internal_user)

    get document_approval_request_path(approval_request, return_to: return_to_path)
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("OKする")
    expect(page_text).to include("内容を確認済みにし、この確認依頼を OK済みにします。")
    expect(page_text).to include("Cancelする")
    expect(page_text).to include("この確認依頼を取り下げます。理由入力や通知の追加はここでは行いません。")
    expect(page_text).to include("一覧の絞り込みや戻り先を保ったまま戻ります。")
    expect(response.body).to include("OK")
    expect(response.body).to include("対応待ち")
    expect(parsed_html.at_css(%(a[href="#{return_to_path}"]))).to be_present

    patch document_approval_request_path(approval_request, return_to: return_to_path)
    expect(response).to redirect_to(document_approval_request_path(approval_request, return_to: return_to_path))
    expect(approval_request.reload).to be_approved
    expect(approval_request.acted_by).to eq(internal_user)

    get document_approval_request_path(approval_request, return_to: return_to_path)
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("OK済み")
    expect(page_text).to include("対応済み")
    expect(page_text).to include("対応者")
    expect(page_text).to include(internal_user.name)
    expect(page_text).not_to include("OKする")
    expect(page_text).not_to include("Cancelする")

    another_request = create(:document_approval_request, document:, requester:, title: "今回は進めない")
    post cancel_document_approval_request_path(another_request, return_to: return_to_path)
    expect(response).to redirect_to(document_approval_request_path(another_request, return_to: return_to_path))
    expect(another_request.reload).to be_cancelled

    get document_approval_request_path(another_request, return_to: return_to_path)
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Cancel済み")
    expect(page_text).to include("対応済み")
    expect(page_text).not_to include("OKする")
    expect(page_text).not_to include("Cancelする")
  end

  it "forbids OK and Cancel for processed requests without changing their status" do
    approved_request = create(
      :document_approval_request,
      document:,
      requester:,
      title: "確認完了",
      status: :approved,
      acted_by: internal_user,
      approved_at: 1.hour.ago,
      cancelled_at: nil
    )
    cancelled_request = create(
      :document_approval_request,
      document:,
      requester:,
      title: "今回は進めない",
      status: :cancelled,
      acted_by: requester,
      cancelled_at: 30.minutes.ago,
      approved_at: nil
    )

    sign_in_as(internal_user)

    expect do
      patch document_approval_request_path(approved_request)
    end.not_to change { approved_request.reload.status }
    expect(response).to have_http_status(:forbidden)

    expect do
      patch document_approval_request_path(cancelled_request)
    end.not_to change { cancelled_request.reload.status }
    expect(response).to have_http_status(:forbidden)

    expect do
      post cancel_document_approval_request_path(approved_request)
    end.not_to change { approved_request.reload.status }
    expect(response).to have_http_status(:forbidden)

    expect do
      post cancel_document_approval_request_path(cancelled_request)
    end.not_to change { cancelled_request.reload.status }
    expect(response).to have_http_status(:forbidden)
  end

  it "lets requesters view and cancel only their own pending requests" do
    own_request = create(:document_approval_request, document:, requester:, title: "自分の確認依頼")
    peer_user = create(:user, :external, company:)
    create(:project_membership, project:, user: peer_user)
    other_request = create(:document_approval_request, document:, requester: peer_user, title: "別ユーザーの確認依頼")

    sign_in_as(requester)

    get document_approval_request_path(own_request)
    expect(response).to have_http_status(:ok)
    expect(page_text).to include(own_request.title)
    expect(page_text).to include("Cancelする")
    expect(page_text).to include("この確認依頼を取り下げます。理由入力や通知の追加はここでは行いません。")
    expect(page_text).not_to include("OKする")

    post cancel_document_approval_request_path(own_request)
    expect(response).to redirect_to(document_approval_request_path(own_request, return_to: project_document_path(project, document.slug)))
    expect(own_request.reload).to be_cancelled
    expect(own_request.acted_by).to eq(requester)

    get document_approval_request_path(other_request)
    expect(response).to have_http_status(:forbidden)

    expect do
      post cancel_document_approval_request_path(other_request)
    end.not_to change { other_request.reload.status }
    expect(response).to have_http_status(:forbidden)
  end

  it "forbids users without document access from viewing or acting on requests" do
    approval_request = create(:document_approval_request, document:, requester:, title: "確認お願いします")
    outsider = create(:user, :external, company: create(:company))

    sign_in_as(outsider)

    get document_approval_request_path(approval_request)
    expect(response).to have_http_status(:forbidden)

    expect do
      patch document_approval_request_path(approval_request)
    end.not_to change { approval_request.reload.status }
    expect(response).to have_http_status(:forbidden)

    expect do
      post cancel_document_approval_request_path(approval_request)
    end.not_to change { approval_request.reload.status }
    expect(response).to have_http_status(:forbidden)
  end

  it "falls back to document detail for requester users without a safe return_to" do
    approval_request = create(:document_approval_request, document:, requester:, title: "確認お願いします")
    document_detail_path = project_document_path(project, document.slug)

    sign_in_as(requester)

    get document_approval_request_path(approval_request)
    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css(%(a[href="#{document_detail_path}"]))).to be_present
    expect(parsed_html.at_css(%(a[href="#{document_approval_requests_path}"]))).to be_nil

    another_request = create(:document_approval_request, document:, requester:, title: "今回は進めない")
    post cancel_document_approval_request_path(another_request, return_to: "//example.com")
    expect(response).to redirect_to(document_approval_request_path(another_request, return_to: document_detail_path))
    expect(another_request.reload).to be_cancelled
  end

  it "falls back to the index path for protocol-relative return_to values" do
    approval_request = create(:document_approval_request, document:, requester:, title: "確認お願いします")
    invalid_return_to = "//example.com"

    sign_in_as(internal_user)

    get document_approval_request_path(approval_request, return_to: invalid_return_to)
    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css(%(a[href="#{document_approval_requests_path}"]))).to be_present

    patch document_approval_request_path(approval_request, return_to: invalid_return_to)
    expect(response).to redirect_to(document_approval_request_path(approval_request, return_to: document_approval_requests_path))

    another_request = create(:document_approval_request, document:, requester:, title: "今回は進めない")
    post cancel_document_approval_request_path(another_request, return_to: invalid_return_to)
    expect(response).to redirect_to(document_approval_request_path(another_request, return_to: document_approval_requests_path))
  end
end
