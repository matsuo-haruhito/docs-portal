require "rails_helper"

RSpec.describe "Admin access requests", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:, name: "Client User", email_address: "client@example.com") }
  let(:project) { create(:project, code: "REQ", name: "Request Project") }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def filter_form
    parsed_html.at_css("form[action='#{admin_access_requests_path}']")
  end

  def result_table_text
    parsed_html.css("tbody").text.squish
  end

  def link_href(text)
    parsed_html.css("a[href]").find { |link| link.text.squish == text }&.[]("href")
  end

  before do
    create(:project_membership, project:, user: requester)
  end

  it "shows access requests to internal admins with filter controls" do
    access_request = create(:access_request, requester:, requestable: document, requested_access_level: :download)

    sign_in_as(admin_user)

    get admin_access_requests_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("アクセス申請")
    expect(page_text).to include(access_request.reason)
    expect(page_text).to include("Manual")
    expect(page_text).to include("検索結果: 1件")
    expect(page_text).to include("表示中: 1-1件")
    expect(page_text).to include("要求権限: すべて")
    expect(page_text).to include("対象種別: すべて")
    expect(page_text).to include("検索結果内訳: 承認待ち: 1 / 承認済み: 0 / 却下: 0")
    expect(filter_form).to be_present
    expect(filter_form.at_css("select[name='status']")).to be_present
    expect(filter_form.at_css("select[name='requested_access_level']")).to be_present
    expect(filter_form.at_css("select[name='requestable_type']")).to be_present
    query_input = filter_form.at_css("input[name='q']")
    expect(query_input).to be_present
    expect(query_input["maxlength"]).to eq(Admin::AccessRequestsController::ACCESS_REQUEST_QUERY_MAX_LENGTH.to_s)
  end

  it "marks pending manage requests without changing pending actions" do
    manage_request = create(:access_request, requester:, requestable: project, requested_access_level: :manage, reason: "Need project management")
    create(:access_request, requester:, requestable: document, requested_access_level: :download, reason: "Need manual download")

    sign_in_as(admin_user)

    get admin_access_requests_path, params: { status: "pending" }

    expect(response).to have_http_status(:ok)
    rows = parsed_html.css("tbody tr")
    manage_row = rows.find { |row| row.text.include?("Need project management") }
    download_row = rows.find { |row| row.text.include?("Need manual download") }

    expect(manage_row.text.squish).to include("管理権限申請")
    expect(manage_row.text.squish).to include("現行の承認処理では管理者 role を付与しません")
    expect(download_row.text.squish).not_to include("管理権限申請")
    expect(download_row.text.squish).not_to include("現行の承認処理では管理者 role を付与しません")
    expect(manage_row.css("form[action='#{admin_access_request_path(manage_request)}']").size).to eq(2)
  end

  it "filters requests by status and keeps pending actions visible" do
    pending_request = create(:access_request, requester:, requestable: document, requested_access_level: :download, reason: "Pending review")
    create(:access_request,
      requester:,
      requestable: project,
      requested_access_level: :view,
      status: :approved,
      approver: admin_user,
      approved_at: Time.zone.local(2026, 5, 1, 12, 0, 0),
      reason: "Approved already")
    create(:access_request,
      requester:,
      requestable: project,
      requested_access_level: :view,
      status: :rejected,
      approver: admin_user,
      rejected_at: Time.zone.local(2026, 5, 1, 13, 0, 0),
      rejection_reason: "No access",
      reason: "Rejected already")

    sign_in_as(admin_user)

    get admin_access_requests_path, params: { status: "pending" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("状態: 承認待ち")
    expect(page_text).to include("Pending review")
    expect(page_text).not_to include("Approved already")
    expect(page_text).not_to include("Rejected already")
    expect(page_text).to include("検索結果内訳: 承認待ち: 1 / 承認済み: 0 / 却下: 0")
    expect(parsed_html.css("tbody tr").size).to eq(1)

    action_forms = parsed_html.css("form[action='#{admin_access_request_path(pending_request)}']")
    reject_form = action_forms.last

    expect(action_forms.size).to eq(2)
    expect(page_text).to include("承認")
    expect(page_text).to include("却下")
    expect(reject_form.at_css("select[name='rejection_reason_preset'] option[selected]")["value"]).to eq("approval_mismatch")
    expect(reject_form.at_css("select[name='rejection_reason_preset']").text.squish).to include("権限不足 対象誤り 情報不足 承認条件不一致")
    expect(reject_form.at_css("textarea[name='rejection_reason_note']")).to be_present
    expect(reject_form.text.squish).to include("定型候補は入力補助です")
    expect(reject_form.to_html).not_to include("Not approved")
  end

  it "filters requests by requested access level" do
    download_request = create(:access_request, requester:, requestable: document, requested_access_level: :download, reason: "Need manual download")
    create(:access_request, requester:, requestable: project, requested_access_level: :view, reason: "Need project view")

    sign_in_as(admin_user)

    get admin_access_requests_path, params: { requested_access_level: "download" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("要求権限: ダウンロード")
    expect(page_text).to include("Need manual download")
    expect(page_text).not_to include("Need project view")
    expect(filter_form.at_css("select[name='requested_access_level'] option[selected]")["value"]).to eq("download")
    expect(parsed_html.css("form[action='#{admin_access_request_path(download_request)}']").last.to_html).to include("requested_access_level")
  end

  it "filters requests by requestable type" do
    document_file = create(:document_file, document_version: create(:document_version, document:), file_name: "manual.pdf")
    create(:access_request, requester:, requestable: document_file, requested_access_level: :download, reason: "Need attachment")
    create(:access_request, requester:, requestable: document, requested_access_level: :download, reason: "Need document")

    sign_in_as(admin_user)

    get admin_access_requests_path, params: { requestable_type: "DocumentFile" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("対象種別: 添付ファイル")
    expect(page_text).to include("Need attachment")
    expect(page_text).not_to include("Need document")
    expect(filter_form.at_css("select[name='requestable_type'] option[selected]")["value"]).to eq("DocumentFile")
  end

  it "combines status, query, requested access level, and requestable type filters" do
    document_file = create(:document_file, document_version: create(:document_version, document:), file_name: "manual.pdf")
    matching_request = create(:access_request, requester:, requestable: document_file, requested_access_level: :download, reason: "Pending manual file")
    create(:access_request, requester:, requestable: document_file, requested_access_level: :view, reason: "Pending manual view")
    create(:access_request, requester:, requestable: document, requested_access_level: :download, reason: "Pending manual document")
    create(:access_request,
      requester:,
      requestable: document_file,
      requested_access_level: :download,
      status: :approved,
      approver: admin_user,
      approved_at: Time.zone.local(2026, 5, 1, 12, 0, 0),
      reason: "Approved manual file")

    sign_in_as(admin_user)

    get admin_access_requests_path, params: {
      status: "pending",
      q: "manual",
      requested_access_level: "download",
      requestable_type: "DocumentFile"
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("状態: 承認待ち")
    expect(page_text).to include("要求権限: ダウンロード")
    expect(page_text).to include("対象種別: 添付ファイル")
    expect(page_text).to include("Pending manual file")
    expect(page_text).not_to include("Pending manual view")
    expect(page_text).not_to include("Pending manual document")
    expect(page_text).not_to include("Approved manual file")
    expect(page_text).to include("検索結果内訳: 承認待ち: 1 / 承認済み: 0 / 却下: 0")
    expect(parsed_html.css("tbody tr").size).to eq(1)
    expect(parsed_html.css("form[action='#{admin_access_request_path(matching_request)}']").size).to eq(2)
  end

  it "paginates filtered access requests while preserving filters in page links and actions" do
    matching_requests = Array.new(3) do |index|
      paged_document = create(:document,
        project:,
        title: "Paged Manual #{index}",
        slug: "paged-manual-#{index}",
        visibility_policy: :restricted_external)
      create(:access_request,
        requester:,
        requestable: paged_document,
        requested_access_level: :download,
        reason: "Paged access request #{index}",
        created_at: Time.zone.local(2026, 5, 1, 12, index, 0))
    end
    create(:access_request, requester:, requestable: project, requested_access_level: :view, reason: "Other access request")

    sign_in_as(admin_user)

    get admin_access_requests_path, params: { q: "paged access", requested_access_level: "download", per_page: 2 }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索結果: 3件")
    expect(page_text).to include("表示中: 1-2件")
    expect(page_text).to include("検索結果内訳: 承認待ち: 3 / 承認済み: 0 / 却下: 0")
    expect(result_table_text).to include("Paged access request 2", "Paged access request 1")
    expect(result_table_text).not_to include("Paged access request 0", "Other access request")
    expect(link_href("次へ")).to include("q=paged+access", "requested_access_level=download", "per_page=2", "page=2")

    get admin_access_requests_path, params: { q: "paged access", requested_access_level: "download", per_page: 2, page: 2 }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 3-3件")
    expect(result_table_text).to include("Paged access request 0")
    expect(result_table_text).not_to include("Paged access request 1")
    expect(link_href("前へ")).to include("q=paged+access", "requested_access_level=download", "per_page=2", "page=1")
    reject_form = parsed_html.css("form[action='#{admin_access_request_path(matching_requests.first)}']").last
    expect(reject_form.at_css("input[name='page']")["value"]).to eq("2")
    expect(reject_form.at_css("input[name='per_page']")["value"]).to eq("2")

    get admin_access_requests_path, params: { q: "paged access", requested_access_level: "download", per_page: 0, page: -1 }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 1-3件")
  end

  it "ignores unsupported requested access level and requestable type filters" do
    create(:access_request, requester:, requestable: document, requested_access_level: :download, reason: "Need Manual access")

    sign_in_as(admin_user)

    get admin_access_requests_path, params: { requested_access_level: "owner", requestable_type: "User" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Need Manual access")
    expect(page_text).to include("要求権限: すべて")
    expect(page_text).to include("対象種別: すべて")
    expect(filter_form.at_css("select[name='requested_access_level'] option[value='owner']")).to be_nil
    expect(filter_form.at_css("select[name='requestable_type'] option[value='User']")).to be_nil
  end

  it "filters requests by requester or target search terms" do
    create(:access_request, requester:, requestable: document, requested_access_level: :download, reason: "Need Manual access")

    other_requester = create(:user, :external, company:, name: "Other User", email_address: "other@example.com")
    other_project = create(:project, code: "OPS", name: "Operations")
    create(:access_request, requester: other_requester, requestable: other_project, requested_access_level: :view, reason: "Ops access")

    sign_in_as(admin_user)

    get admin_access_requests_path, params: { q: "manual" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Need Manual access")
    expect(page_text).not_to include("Ops access")
    expect(page_text).to include("検索結果内訳: 承認待ち: 1 / 承認済み: 0 / 却下: 0")
    expect(parsed_html.css("tbody tr").size).to eq(1)
    expect(filter_form.at_css("input[name='q']")["value"]).to eq("manual")
  end

  it "normalizes long query filters before rendering input and empty state" do
    create(:access_request, requester:, requestable: document, requested_access_level: :download)
    long_query = "manual" + ("x" * 120)
    normalized_query = long_query.slice(0, Admin::AccessRequestsController::ACCESS_REQUEST_QUERY_MAX_LENGTH)

    sign_in_as(admin_user)

    get admin_access_requests_path, params: { q: "  #{long_query}  " }

    expect(response).to have_http_status(:ok)
    query_input = filter_form.at_css("input[name='q']")
    expect(query_input["value"]).to eq(normalized_query)
    expect(query_input["maxlength"]).to eq(Admin::AccessRequestsController::ACCESS_REQUEST_QUERY_MAX_LENGTH.to_s)
    expect(page_text).to include("条件に一致する申請はありません。")
    expect(page_text).to include("検索: #{normalized_query}")
    expect(page_text).not_to include(long_query)
  end

  it "treats whitespace-only query as unset" do
    create(:access_request, requester:, requestable: document, requested_access_level: :download, reason: "Visible request")

    sign_in_as(admin_user)

    get admin_access_requests_path, params: { q: "   " }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Visible request")
    expect(page_text).not_to include("検索: ")
    expect(filter_form.at_css("input[name='q']")["value"]).to be_nil
  end

  it "combines status and query search before loading access requests" do
    pending_match = create(:access_request,
      requester:,
      requestable: document,
      requested_access_level: :download,
      reason: "Pending manual access")
    create(:access_request,
      requester:,
      requestable: document,
      requested_access_level: :view,
      status: :approved,
      approver: admin_user,
      approved_at: Time.zone.local(2026, 5, 1, 12, 0, 0),
      reason: "Approved manual access")
    other_project = create(:project, code: "OPS", name: "Operations")
    create(:access_request, requester:, requestable: other_project, requested_access_level: :view, reason: "Pending ops access")

    sign_in_as(admin_user)

    get admin_access_requests_path, params: { status: "pending", q: "manual" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("状態: 承認待ち")
    expect(page_text).to include("Pending manual access")
    expect(page_text).not_to include("Approved manual access")
    expect(page_text).not_to include("Pending ops access")
    expect(page_text).to include("検索結果内訳: 承認待ち: 1 / 承認済み: 0 / 却下: 0")
    expect(parsed_html.css("tbody tr").size).to eq(1)
    expect(parsed_html.css("form[action='#{admin_access_request_path(pending_match)}']").size).to eq(2)
  end

  it "shows active filters in the filtered empty state" do
    create(:access_request, requester:, requestable: document, requested_access_level: :download)

    sign_in_as(admin_user)

    get admin_access_requests_path, params: {
      status: "rejected",
      q: "does-not-match",
      requested_access_level: "manage",
      requestable_type: "Project"
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致する申請はありません。")
    expect(page_text).to include("状態: 却下")
    expect(page_text).to include("要求権限: 管理")
    expect(page_text).to include("対象種別: 案件")
    expect(page_text).to include("検索: does-not-match")
    expect(page_text).not_to include("状態: rejected")
  end

  it "does not show unset filters in the query-only filtered empty state" do
    create(:access_request, requester:, requestable: document, requested_access_level: :download)

    sign_in_as(admin_user)

    get admin_access_requests_path, params: { q: "does-not-match" }

    empty_state_text = parsed_html.css("p.muted").find { |node| node.text.include?("条件に一致する申請はありません。") }.text.squish

    expect(response).to have_http_status(:ok)
    expect(empty_state_text).to include("条件に一致する申請はありません。")
    expect(empty_state_text).to include("検索: does-not-match")
    expect(empty_state_text).not_to include("状態:")
    expect(empty_state_text).not_to include("状態: すべて")
    expect(empty_state_text).not_to include("要求権限:")
    expect(empty_state_text).not_to include("対象種別:")
  end

  it "approves a pending request" do
    access_request = create(:access_request, requester:, requestable: document, requested_access_level: :download)

    sign_in_as(admin_user)

    expect do
      patch admin_access_request_path(access_request), params: { decision: "approve" }
    end.to change { DocumentPermission.where(document:, user: requester).count }.by(1)

    expect(response).to redirect_to(admin_access_requests_path)
    expect(access_request.reload).to be_approved
    expect(access_request.approver).to eq(admin_user)
  end

  it "keeps permitted filters and page context after approval while dropping unsupported return params" do
    access_request = create(:access_request, requester:, requestable: document, requested_access_level: :download)

    sign_in_as(admin_user)

    expect do
      patch admin_access_request_path(access_request), params: {
        decision: "approve",
        status: "pending",
        q: " Manual ",
        page: "2",
        per_page: "2",
        requested_access_level: "download",
        requestable_type: "Document"
      }
    end.to change { DocumentPermission.where(document:, user: requester).count }.by(1)

    expect(response).to redirect_to(admin_access_requests_path(
      status: "pending",
      q: "Manual",
      requested_access_level: "download",
      requestable_type: "Document",
      page: 2,
      per_page: 2
    ))
    expect(access_request.reload).to be_approved
  end

  it "normalizes long query filters after approval and rejection" do
    approval_request = create(:access_request, requester:, requestable: document, requested_access_level: :download)
    rejection_request = create(:access_request, requester:, requestable: project, requested_access_level: :view)
    long_query = "Client User" + ("x" * 120)
    normalized_query = long_query.slice(0, Admin::AccessRequestsController::ACCESS_REQUEST_QUERY_MAX_LENGTH)

    sign_in_as(admin_user)

    patch admin_access_request_path(approval_request), params: {
      decision: "approve",
      status: "pending",
      q: "  #{long_query}  ",
      requested_access_level: "download",
      requestable_type: "Document"
    }

    expect(response).to redirect_to(admin_access_requests_path(
      status: "pending",
      q: normalized_query,
      requested_access_level: "download",
      requestable_type: "Document"
    ))
    expect(approval_request.reload).to be_approved

    patch admin_access_request_path(rejection_request), params: {
      decision: "reject",
      rejection_reason_preset: "approval_mismatch",
      status: "pending",
      q: long_query,
      requested_access_level: "view",
      requestable_type: "Project"
    }

    expect(response).to redirect_to(admin_access_requests_path(
      status: "pending",
      q: normalized_query,
      requested_access_level: "view",
      requestable_type: "Project"
    ))
    expect(rejection_request.reload).to be_rejected
  end

  it "rejects a pending request with a custom reason" do
    access_request = create(:access_request, requester:, requestable: project, requested_access_level: :view)
    custom_reason = "申請対象を確認できないため却下します <script>alert(1)</script>"

    sign_in_as(admin_user)

    patch admin_access_request_path(access_request), params: { decision: "reject", rejection_reason: custom_reason }

    expect(response).to redirect_to(admin_access_requests_path)
    expect(access_request.reload).to be_rejected
    expect(access_request.rejection_reason).to eq(custom_reason)
  end

  it "rejects a pending request with a preset reason" do
    access_request = create(:access_request, requester:, requestable: project, requested_access_level: :view)

    sign_in_as(admin_user)

    patch admin_access_request_path(access_request), params: { decision: "reject", rejection_reason_preset: "permission_shortage" }

    expect(response).to redirect_to(admin_access_requests_path)
    expect(access_request.reload).to be_rejected
    expect(access_request.rejection_reason).to eq("権限不足")
  end

  it "rejects a pending request with a preset reason and note" do
    access_request = create(:access_request, requester:, requestable: project, requested_access_level: :view)

    sign_in_as(admin_user)

    patch admin_access_request_path(access_request), params: {
      decision: "reject",
      rejection_reason_preset: "insufficient_information",
      rejection_reason_note: "申請対象の案件を確認してください"
    }

    expect(response).to redirect_to(admin_access_requests_path)
    expect(access_request.reload).to be_rejected
    expect(access_request.rejection_reason).to eq("情報不足：申請対象の案件を確認してください")
  end

  it "keeps permitted filters after rejection" do
    access_request = create(:access_request, requester:, requestable: project, requested_access_level: :view)

    sign_in_as(admin_user)

    patch admin_access_request_path(access_request), params: {
      decision: "reject",
      rejection_reason_preset: "approval_mismatch",
      status: "pending",
      q: "Client User",
      requested_access_level: "view",
      requestable_type: "Project"
    }

    expect(response).to redirect_to(admin_access_requests_path(
      status: "pending",
      q: "Client User",
      requested_access_level: "view",
      requestable_type: "Project"
    ))
    expect(access_request.reload).to be_rejected
    expect(access_request.rejection_reason).to eq("承認条件不一致")
  end

  it "does not carry invalid filters, page params, or blank query after actions" do
    access_request = create(:access_request, requester:, requestable: document, requested_access_level: :download)

    sign_in_as(admin_user)

    patch admin_access_request_path(access_request), params: {
      decision: "approve",
      status: "all",
      q: "   ",
      page: "-1",
      per_page: "0",
      requested_access_level: "owner",
      requestable_type: "User"
    }

    expect(response).to redirect_to(admin_access_requests_path)
    expect(access_request.reload).to be_approved
  end

  it "returns bad request when rejection reason is blank" do
    access_request = create(:access_request, requester:, requestable: project, requested_access_level: :view)

    sign_in_as(admin_user)

    patch admin_access_request_path(access_request), params: { decision: "reject", rejection_reason: "  " }

    expect(response).to have_http_status(:bad_request)
    expect(access_request.reload).to be_pending
    expect(access_request.rejection_reason).to be_blank
  end

  it "returns bad request when rejection preset is unsupported and note is blank" do
    access_request = create(:access_request, requester:, requestable: project, requested_access_level: :view)

    sign_in_as(admin_user)

    patch admin_access_request_path(access_request), params: {
      decision: "reject",
      rejection_reason_preset: "policy_specific",
      rejection_reason_note: "  "
    }

    expect(response).to have_http_status(:bad_request)
    expect(access_request.reload).to be_pending
    expect(access_request.rejection_reason).to be_blank
  end

  it "forbids external users" do
    access_request = create(:access_request, requester:, requestable: project, requested_access_level: :view)

    sign_in_as(external_user)

    get admin_access_requests_path
    expect(response).to have_http_status(:forbidden)

    patch admin_access_request_path(access_request), params: { decision: "approve" }
    expect(response).to have_http_status(:forbidden)
  end
end
