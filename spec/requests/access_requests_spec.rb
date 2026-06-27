require "rails_helper"
require "cgi"

RSpec.describe "Access requests", type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, :external, company:) }
  let(:other_user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "REQ", name: "Request Project") }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }
  let(:file) { create(:document_file, document_version: version, file_name: "manual.pdf", content_type: "application/pdf", file_size: 10) }

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user:)
    create(:project_membership, project:, user: other_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "creates a download access request for a visible document file" do
    sign_in_as(user)

    expect do
      post access_requests_path, params: {
        requestable_type: "DocumentFile",
        requestable_public_id: file.public_id,
        requested_access_level: "download"
      }
    end.to change(AccessRequest, :count).by(1)

    expect(response).to redirect_to(access_requests_path)
    request = AccessRequest.order(:id).last
    expect(request.requester).to eq(user)
    expect(request.requestable).to eq(file)
    expect(request).to be_pending
    expect(request.reason).to include("manual.pdf")
  end

  it "stores and displays japanese default reasons for project, document, and file requests" do
    sign_in_as(user)

    post access_requests_path, params: {
      requestable_type: "Project",
      requestable_public_id: project.code,
      requested_access_level: "manage"
    }
    expect(AccessRequest.order(:id).last.reason).to eq("案件「Request Project」に管理権限が必要です。")

    post access_requests_path, params: {
      requestable_type: "Document",
      requestable_public_id: document.public_id,
      requested_access_level: "download"
    }
    expect(AccessRequest.order(:id).last.reason).to eq("文書「Manual」にダウンロード権限が必要です。")

    post access_requests_path, params: {
      requestable_type: "DocumentFile",
      requestable_public_id: file.public_id,
      requested_access_level: "download"
    }
    expect(AccessRequest.order(:id).last.reason).to eq("ファイル「manual.pdf」にダウンロード権限が必要です。")

    get access_requests_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("案件「Request Project」に管理権限が必要です。")
    expect(response.body).to include("文書「Manual」にダウンロード権限が必要です。")
    expect(response.body).to include("ファイル「manual.pdf」にダウンロード権限が必要です。")
    expect(response.body).not_to include("Need ")
  end

  it "does not duplicate the same pending request" do
    sign_in_as(user)
    create(:access_request, requester: user, requestable: file, requested_access_level: :download)

    expect do
      post access_requests_path, params: {
        requestable_type: "DocumentFile",
        requestable_public_id: file.public_id,
        requested_access_level: "download"
      }
    end.not_to change(AccessRequest, :count)

    expect(response).to redirect_to(access_requests_path)
  end

  it "lists and cancels only the current user's requests" do
    own_request = create(:access_request, requester: user, requestable: file, requested_access_level: :download)
    other_request = create(:access_request, requester: other_user, requestable: document, requested_access_level: :download, reason: "Other user request")

    sign_in_as(user)

    get access_requests_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("manual.pdf")
    expect(response.body).not_to include(other_request.reason)

    post cancel_access_request_path(other_request)

    expect(response).to have_http_status(:not_found)
    expect(other_request.reload).to be_pending

    post cancel_access_request_path(own_request)

    expect(response).to redirect_to(access_requests_path)
    expect(own_request.reload).to be_cancelled
  end

  it "preserves only supported filters when cancelling from a filtered list" do
    own_request = create(:access_request, requester: user, requestable: file, requested_access_level: :download, reason: "Need manual file")
    create(:access_request, requester: user, requestable: document, requested_access_level: :download, reason: "Need manual document")

    sign_in_as(user)

    get access_requests_path, params: {
      q: "manual",
      status: :pending,
      requested_access_level: :download,
      requestable_type: "DocumentFile",
      return_to: "https://example.invalid/access_requests",
      unsupported: "keep-me-out"
    }

    expect(response).to have_http_status(:ok)
    cancel_form = parsed_html.at_css(%(form[action="#{cancel_access_request_path(own_request)}"]))
    expect(cancel_form).to be_present
    expect(cancel_form.at_css('input[name="q"]')["value"]).to eq("manual")
    expect(cancel_form.at_css('input[name="status"]')["value"]).to eq("pending")
    expect(cancel_form.at_css('input[name="requested_access_level"]')["value"]).to eq("download")
    expect(cancel_form.at_css('input[name="requestable_type"]')["value"]).to eq("DocumentFile")
    expect(cancel_form.at_css('input[name="return_to"]')).to be_nil
    expect(cancel_form.at_css('input[name="unsupported"]')).to be_nil
    expect(page_text).to include("取消後は現在の条件のままアクセス申請一覧へ戻ります。")

    post cancel_access_request_path(own_request), params: {
      q: " manual ",
      status: "pending",
      requested_access_level: "download",
      requestable_type: "DocumentFile",
      return_to: "https://example.invalid/access_requests",
      unsupported: "keep-me-out"
    }

    expect(response).to redirect_to(access_requests_path(q: "manual", status: "pending", requested_access_level: "download", requestable_type: "DocumentFile"))
    expect(own_request.reload).to be_cancelled
  end

  it "filters the current user's requests by status" do
    approver = create(:user, :internal)
    pending_request = create(:access_request, requester: user, requestable: file, requested_access_level: :download, reason: "Pending reason")
    approved_request = create(:access_request, requester: user, requestable: document, requested_access_level: :download, status: :approved, approver:, approved_at: Time.current, reason: "Approved reason")
    rejected_request = create(:access_request, requester: user, requestable: project, requested_access_level: :manage, status: :rejected, approver:, rejected_at: Time.current, rejection_reason: "NG", reason: "Rejected reason")
    cancelled_request = create(:access_request, requester: user, requestable: file, requested_access_level: :view, status: :cancelled, cancelled_at: Time.current, reason: "Cancelled reason")
    create(:access_request, requester: other_user, requestable: file, requested_access_level: :download, status: :approved, approver:, approved_at: Time.current, reason: "Other user approved reason")

    sign_in_as(user)

    get access_requests_path(status: :pending)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("申請中 1件 / 承認済み 1件 / 却下 1件 / 取消済み 1件")
    expect(page_text).to include(pending_request.reason)
    expect(page_text).to include("この行の対象・要求権限・理由を確認してから取消してください。")
    expect(page_text).to include("取消後は現在の条件のままアクセス申請一覧へ戻ります。")
    expect(response.body).to include("data-turbo-confirm")
    expect(response.body).to include("このアクセス申請を取り消します。対象・要求権限・理由を確認しましたか？")
    expect(page_text).not_to include(approved_request.reason)
    expect(page_text).not_to include(rejected_request.reason)
    expect(page_text).not_to include(cancelled_request.reason)
    expect(page_text).not_to include("Other user approved reason")
    expect(response.body).to include(">取消<")

    get access_requests_path(status: :approved)

    expect(response).to have_http_status(:ok)
    expect(page_text).not_to include(pending_request.reason)
    expect(page_text).to include(approved_request.reason)
    expect(page_text).not_to include(rejected_request.reason)
    expect(page_text).not_to include(cancelled_request.reason)
    expect(page_text).not_to include("この行の対象・要求権限・理由を確認してから取消してください。")
    expect(response.body).not_to include(">取消<")

    get access_requests_path(status: :invalid)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(pending_request.reason)
    expect(page_text).to include(approved_request.reason)
    expect(page_text).to include(rejected_request.reason)
    expect(page_text).to include(cancelled_request.reason)
  end

  it "searches the current user's requests by target text and reason with status filters" do
    approver = create(:user, :internal)
    pending_request = create(:access_request, requester: user, requestable: file, requested_access_level: :download, reason: "Need file approval")
    approved_request = create(:access_request, requester: user, requestable: document, requested_access_level: :download, status: :approved, approver:, approved_at: Time.current, reason: "Policy review needed")
    cancelled_request = create(:access_request, requester: user, requestable: project, requested_access_level: :manage, status: :cancelled, cancelled_at: Time.current, reason: "Old project request")
    create(:access_request, requester: other_user, requestable: document, requested_access_level: :download, status: :approved, approver:, approved_at: Time.current, reason: "Policy review needed from other user")

    sign_in_as(user)

    get access_requests_path, params: { q: "policy", status: :approved }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("申請中 0件 / 承認済み 1件 / 却下 0件 / 取消済み 0件")
    expect(page_text).to include(approved_request.reason)
    expect(page_text).not_to include(pending_request.reason)
    expect(page_text).not_to include(cancelled_request.reason)
    expect(page_text).not_to include("Policy review needed from other user")
    expect(page_text).to include("条件をクリア")
    expect(CGI.unescapeHTML(response.body)).to include(access_requests_path(q: "policy", status: :pending))

    get access_requests_path, params: { q: "missing target" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索: missing target に一致するアクセス申請はありません。")
    expect(page_text).not_to include("送信済みのアクセス申請はありません。")
  end

  it "shows filter-specific recovery links for filtered empty results" do
    create(:access_request, requester: user, requestable: file, requested_access_level: :download, reason: "Existing request")

    sign_in_as(user)

    get access_requests_path, params: {
      q: "missing target",
      status: :pending,
      requested_access_level: :download,
      requestable_type: "DocumentFile"
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中条件: 状態: 申請中 / 検索: missing target / 要求権限: ダウンロード / 対象種別: ファイル")
    expect(page_text).to include("状態: 申請中 / 検索: missing target / 要求権限: ダウンロード / 対象種別: ファイル に一致するアクセス申請はありません。")
    expect(page_text).to include("条件を外すと、送信済み申請全体を確認できます。")
    expect(page_text).to include("条件を1つずつ外す場合は、下のリンクから選べます。")
    expect(page_text).to include("検索を解除")
    expect(page_text).to include("状態をすべてに戻す")
    expect(page_text).to include("要求権限をすべてに戻す")
    expect(page_text).to include("対象種別をすべてに戻す")
    expect(page_text).to include("すべての申請を見る")

    html = CGI.unescapeHTML(response.body)
    expect(html).to include(access_requests_path(requested_access_level: "download", requestable_type: "DocumentFile", status: "pending"))
    expect(html).to include(access_requests_path(q: "missing target", requested_access_level: "download", requestable_type: "DocumentFile"))
    expect(html).to include(access_requests_path(q: "missing target", requestable_type: "DocumentFile", status: "pending"))
    expect(html).to include(access_requests_path(q: "missing target", requested_access_level: "download", status: "pending"))
    expect(html).to include(access_requests_path)
    expect(page_text).not_to include("送信済みのアクセス申請はありません。")
  end

  it "guards the request search targets described by the index copy" do
    project_target = create(:project, code: "REQPRJ", name: "Project Search Alpha")
    document_project = create(:project, code: "REQDOC", name: "Document Search Project")
    file_project = create(:project, code: "REQFILE", name: "File Search Project")
    reason_project = create(:project, code: "REQRSN", name: "Reason Search Project")
    search_document = create(:document, project: document_project, title: "Quarterly Policy Manual", slug: "quarterly-policy-manual", visibility_policy: :restricted_external)
    file_document = create(:document, project: file_project, title: "Attachment Matrix Guide", slug: "attachment-matrix-guide", visibility_policy: :restricted_external)
    file_version = create(:document_version, document: file_document, version_label: "v2.0.0", status: :published)
    search_file = create(:document_file, document_version: file_version, file_name: "approval-matrix.xlsx", content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", file_size: 20)

    file_document.update!(latest_version: file_version)

    project_request = create(:access_request, requester: user, requestable: project_target, requested_access_level: :manage, reason: "Project target request")
    document_request = create(:access_request, requester: user, requestable: search_document, requested_access_level: :download, reason: "Document target request")
    file_request = create(:access_request, requester: user, requestable: search_file, requested_access_level: :download, reason: "File target request")
    reason_request = create(:access_request, requester: user, requestable: reason_project, requested_access_level: :manage, reason: "Reason phrase target")
    other_request = create(:access_request, requester: other_user, requestable: project_target, requested_access_level: :manage, reason: "Reason phrase target from other user")

    sign_in_as(user)

    search_examples = {
      project_target.code.downcase => project_request,
      "Project Search Alpha" => project_request,
      project_target.public_id => project_request,
      "Quarterly Policy Manual" => document_request,
      search_document.public_id => document_request,
      document_project.code.downcase => document_request,
      "approval-matrix.xlsx" => file_request,
      search_file.public_id => file_request,
      "Attachment Matrix Guide" => file_request,
      file_project.code.downcase => file_request,
      "Reason phrase" => reason_request
    }

    search_examples.each do |query, expected_request|
      get access_requests_path, params: { q: query }

      aggregate_failures "query #{query}" do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("対象名・案件コード・ID・ファイル名・理由で検索")
        expect(page_text).to include("案件コード・対象ID・ファイル名・理由で検索できます。")
        expect(page_text).to include("表示中条件: 検索: #{query}")
        expect(page_text).to include(expected_request.reason)
        ([project_request, document_request, file_request, reason_request] - [expected_request]).each do |excluded_request|
          expect(page_text).not_to include(excluded_request.reason)
        end
        expect(page_text).not_to include(other_request.reason)
      end
    end

    get access_requests_path, params: { q: "not-found-access-request" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索: not-found-access-request に一致するアクセス申請はありません。")
    expect(page_text).to include("条件を外すと、送信済み申請全体を確認できます。")
    expect(page_text).not_to include(project_request.reason)
    expect(page_text).not_to include(document_request.reason)
    expect(page_text).not_to include(file_request.reason)
    expect(page_text).not_to include(reason_request.reason)
  end

  it "normalizes oversized search queries before filtering and rendering links" do
    approver = create(:user, :internal)
    truncated_query = "review-" + ("x" * (AccessRequestsController::ACCESS_REQUEST_QUERY_MAX_LENGTH - "review-".length))
    long_query = "  #{truncated_query}ignored-tail  "
    matching_request = create(:access_request, requester: user, requestable: file, requested_access_level: :download, reason: "#{truncated_query} matched reason")
    create(:access_request, requester: user, requestable: document, requested_access_level: :download, status: :approved, approver:, approved_at: Time.current, reason: "ignored-tail only")

    sign_in_as(user)

    get access_requests_path, params: {
      q: long_query,
      status: :pending,
      requested_access_level: :download,
      requestable_type: "DocumentFile"
    }

    expect(response).to have_http_status(:ok)
    query_field = Nokogiri::HTML.parse(response.body).at_css('input[name="q"]')
    expect(query_field["value"]).to eq(truncated_query)
    expect(query_field["maxlength"]).to eq(AccessRequestsController::ACCESS_REQUEST_QUERY_MAX_LENGTH.to_s)
    expect(page_text).to include("表示中条件: 状態: 申請中 / 検索: #{truncated_query} / 要求権限: ダウンロード / 対象種別: ファイル")
    expect(page_text).to include(matching_request.reason)
    expect(page_text).not_to include("ignored-tail only")
    expect(CGI.unescapeHTML(response.body)).to include(access_requests_path(q: truncated_query, requested_access_level: "download", requestable_type: "DocumentFile", status: :approved))
  end

  it "filters the current user's requests by access level and requestable type" do
    approver = create(:user, :internal)
    pending_file_request = create(:access_request, requester: user, requestable: file, requested_access_level: :download, reason: "Need manual file")
    approved_file_request = create(:access_request, requester: user, requestable: file, requested_access_level: :download, status: :approved, approver:, approved_at: Time.current, reason: "Approved manual file")
    approved_document_request = create(:access_request, requester: user, requestable: document, requested_access_level: :download, status: :approved, approver:, approved_at: Time.current, reason: "Manual policy review")
    manage_project_request = create(:access_request, requester: user, requestable: project, requested_access_level: :manage, reason: "Manage project request")
    view_file_request = create(:access_request, requester: user, requestable: file, requested_access_level: :view, reason: "View file request")
    create(:access_request, requester: other_user, requestable: file, requested_access_level: :download, reason: "Other user manual file")
    create(:access_request, requester: other_user, requestable: file, requested_access_level: :download, status: :approved, approver:, approved_at: Time.current, reason: "Other user approved manual file")

    sign_in_as(user)

    get access_requests_path, params: {
      q: "manual",
      status: :pending,
      requested_access_level: :download,
      requestable_type: "DocumentFile"
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("申請中 1件 / 承認済み 1件 / 却下 0件 / 取消済み 0件")
    expect(page_text).to include("表示中条件: 状態: 申請中 / 検索: manual / 要求権限: ダウンロード / 対象種別: ファイル")
    expect(page_text).to include(pending_file_request.reason)
    expect(page_text).not_to include(approved_file_request.reason)
    expect(page_text).not_to include(approved_document_request.reason)
    expect(page_text).not_to include(manage_project_request.reason)
    expect(page_text).not_to include(view_file_request.reason)
    expect(page_text).not_to include("Other user manual file")
    expect(page_text).not_to include("Other user approved manual file")
    expect(CGI.unescapeHTML(response.body)).to include(access_requests_path(q: "manual", requested_access_level: "download", requestable_type: "DocumentFile", status: :approved))
    expect(page_text).to include("条件をクリア")

    get access_requests_path, params: {
      requested_access_level: :invalid,
      requestable_type: "Secret",
      status: :invalid
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("申請中 3件 / 承認済み 2件 / 却下 0件 / 取消済み 0件")
    expect(page_text).to include(pending_file_request.reason)
    expect(page_text).to include(approved_file_request.reason)
    expect(page_text).to include(approved_document_request.reason)
    expect(page_text).to include(manage_project_request.reason)
    expect(page_text).to include(view_file_request.reason)
    expect(page_text).not_to include("Other user manual file")
    expect(page_text).not_to include("Other user approved manual file")
  end

  it "bounds query result rows while keeping filtered status counts readable" do
    sign_in_as(user)

    101.times do |index|
      create(
        :access_request,
        requester: user,
        requestable: file,
        requested_access_level: :download,
        status: :cancelled,
        cancelled_at: Time.current,
        reason: format("bounded request %03d", index + 1)
      )
    end

    get access_requests_path, params: {
      q: "bounded",
      status: :cancelled,
      requested_access_level: :download,
      requestable_type: "DocumentFile"
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("申請中 0件 / 承認済み 0件 / 却下 0件 / 取消済み 101件")
    expect(page_text).to include("表示件数: 101件中100件を新しい順で表示しています。")
    expect(page_text).to include("条件を追加すると目的の申請を探しやすくなります。")
    expect(parsed_html.css("tbody tr").size).to eq(AccessRequestsController::ACCESS_REQUEST_LIST_LIMIT)
    expect(page_text).to include("bounded request 101")
    expect(page_text).not_to include("bounded request 001")
  end

  it "shows localized labels for requestable type, access level, and status on the index" do
    localized_project = create(:project, code: "LOC", name: "案件A")
    localized_document = create(:document, project: localized_project, title: "利用規約", slug: "terms", visibility_policy: :restricted_external)
    localized_version = create(:document_version, document: localized_document, version_label: "v1.0.0", status: :published)
    localized_file = create(:document_file, document_version: localized_version, file_name: "案内.pdf", content_type: "application/pdf", file_size: 10)
    approver = create(:user, :internal)

    localized_document.update!(latest_version: localized_version)
    create(:project_membership, project: localized_project, user:)
    create(:document_permission, document: localized_document, company:, access_level: :view)

    create(:access_request, requester: user, requestable: localized_project, requested_access_level: :manage, reason: "案件の管理が必要です。")
    create(:access_request, requester: user, requestable: localized_document, requested_access_level: :download, status: :approved, approver:, approved_at: Time.current, reason: "文書確認のためです。")
    create(:access_request, requester: user, requestable: localized_file, requested_access_level: :view, status: :rejected, approver:, rejected_at: Time.current, rejection_reason: "対象外です。", reason: "内容確認のためです。")
    create(:access_request, requester: user, requestable: file, requested_access_level: :download, status: :cancelled, cancelled_at: Time.current, reason: "取り下げました。")

    sign_in_as(user)

    get access_requests_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("案件")
    expect(page_text).to include("文書")
    expect(page_text).to include("ファイル")
    expect(page_text).to include("管理")
    expect(page_text).to include("ダウンロード")
    expect(page_text).to include("閲覧")
    expect(page_text).to include("申請中")
    expect(page_text).to include("承認済み")
    expect(page_text).to include("却下")
    expect(page_text).to include("取消済み")
    expect(page_text).to include("取消")
    expect(page_text).not_to include("Project")
    expect(page_text).not_to include("Document")
    expect(page_text).not_to include("DocumentFile")
    expect(page_text).not_to include("manage")
    expect(page_text).not_to include("download")
    expect(page_text).not_to include("pending")
    expect(page_text).not_to include("approved")
    expect(page_text).not_to include("rejected")
    expect(page_text).not_to include("cancelled")
  end

  it "shows request buttons on the version page when download is not allowed" do
    sign_in_as(user)

    get document_version_path(version)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("ダウンロード権限を申請")
    expect(response.body).to include("申請")
  end

  def parsed_html
    Nokogiri::HTML.parse(response.body)
  end

  def page_text
    parsed_html.text.squish
  end
end
