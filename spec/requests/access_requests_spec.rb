require "rails_helper"

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

    post cancel_access_request_path(own_request)

    expect(response).to redirect_to(access_requests_path)
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
    expect(response.body).not_to include(">取消<")

    get access_requests_path(status: :invalid)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(pending_request.reason)
    expect(page_text).to include(approved_request.reason)
    expect(page_text).to include(rejected_request.reason)
    expect(page_text).to include(cancelled_request.reason)
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

  def page_text
    Nokogiri::HTML.parse(response.body).text.squish
  end
end
