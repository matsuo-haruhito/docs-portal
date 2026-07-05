require "rails_helper"

RSpec.describe "Access request maintenance mode", type: :request do
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:, name: "Client User", email_address: "client@example.com") }
  let(:other_requester) { create(:user, :external, company:) }
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "REQ-MAINT", name: "Access Request Maintenance") }
  let(:document) { create(:document, project:, title: "Maintenance Manual", slug: "maintenance-manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }
  let(:file) { create(:document_file, document_version: version, file_name: "maintenance.pdf", content_type: "application/pdf", file_size: 10) }

  def with_read_only_maintenance(value)
    previous = ENV.fetch(AccessRequestsController::READ_ONLY_MAINTENANCE_ENV, nil)
    ENV[AccessRequestsController::READ_ONLY_MAINTENANCE_ENV] = value
    yield
  ensure
    if previous.nil?
      ENV.delete(AccessRequestsController::READ_ONLY_MAINTENANCE_ENV)
    else
      ENV[AccessRequestsController::READ_ONLY_MAINTENANCE_ENV] = previous
    end
  end

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: requester)
    create(:project_membership, project:, user: other_requester)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "does not create or refresh pending access requests during read-only maintenance" do
    existing_request = create(:access_request, requester:, requestable: file, requested_access_level: :download, reason: "Original reason")
    sign_in_as(requester)

    expect do
      with_read_only_maintenance("1") do
        post access_requests_path, params: {
          requestable_type: "DocumentFile",
          requestable_public_id: file.public_id,
          requested_access_level: "download"
        }
      end
    end.not_to change(AccessRequest, :count)

    expect(response).to redirect_to(access_requests_path)
    expect(flash[:alert]).to include("メンテナンス中のためアクセス申請の送信と取消は停止しています")
    expect(existing_request.reload.reason).to eq("Original reason")
    expect(existing_request).to be_pending
  end

  it "does not cancel pending access requests during read-only maintenance" do
    access_request = create(:access_request, requester:, requestable: file, requested_access_level: :download, reason: "Need file")
    sign_in_as(requester)

    with_read_only_maintenance("true") do
      post cancel_access_request_path(access_request), params: {
        q: "Need",
        status: "pending",
        requested_access_level: "download",
        requestable_type: "DocumentFile",
        page: "2"
      }
    end

    expect(response).to redirect_to(access_requests_path(
      q: "Need",
      status: "pending",
      requested_access_level: "download",
      requestable_type: "DocumentFile",
      page: 2
    ))
    expect(flash[:alert]).to include("メンテナンス中のためアクセス申請の送信と取消は停止しています")
    expect(access_request.reload).to be_pending
    expect(access_request.cancelled_at).to be_nil
  end

  it "keeps access request create and cancel flows working when read-only maintenance is disabled" do
    access_request = create(:access_request, requester:, requestable: file, requested_access_level: :view)
    sign_in_as(requester)

    expect do
      with_read_only_maintenance("0") do
        post access_requests_path, params: {
          requestable_type: "DocumentFile",
          requestable_public_id: file.public_id,
          requested_access_level: "download"
        }
      end
    end.to change(AccessRequest, :count).by(1)

    expect(response).to redirect_to(access_requests_path)
    expect(AccessRequest.order(:id).last).to be_pending

    with_read_only_maintenance("0") do
      post cancel_access_request_path(access_request)
    end

    expect(response).to redirect_to(access_requests_path)
    expect(access_request.reload).to be_cancelled
  end

  it "keeps the requester list readable during read-only maintenance" do
    access_request = create(:access_request, requester:, requestable: file, requested_access_level: :download, reason: "Need maintenance file")
    create(:access_request, requester: other_requester, requestable: document, requested_access_level: :download, reason: "Other requester")
    sign_in_as(requester)

    with_read_only_maintenance("1") do
      get access_requests_path, params: { q: "maintenance", status: "pending", requested_access_level: "download", requestable_type: "DocumentFile" }
    end

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(access_request.reason)
    expect(response.body).not_to include("Other requester")
  end

  it "does not approve access requests or grant permissions during read-only maintenance" do
    access_request = create(:access_request, requester:, requestable: document, requested_access_level: :download)
    sign_in_as(admin_user)

    expect do
      with_read_only_maintenance("1") do
        patch admin_access_request_path(access_request), params: { decision: "approve" }
      end
    end.not_to change { DocumentPermission.where(document:, user: requester).count }

    expect(response).to redirect_to(admin_access_requests_path)
    expect(flash[:alert]).to include("メンテナンス中のためアクセス申請の承認と却下は停止しています")
    expect(access_request.reload).to be_pending
    expect(access_request.approver).to be_nil
    expect(access_request.approved_at).to be_nil
  end

  it "does not reject access requests during read-only maintenance" do
    access_request = create(:access_request, requester:, requestable: project, requested_access_level: :view)
    sign_in_as(admin_user)

    with_read_only_maintenance("true") do
      patch admin_access_request_path(access_request), params: {
        decision: "reject",
        rejection_reason_preset: "permission_shortage",
        status: "pending",
        q: "Client User"
      }
    end

    expect(response).to redirect_to(admin_access_requests_path(status: "pending", q: "Client User"))
    expect(flash[:alert]).to include("メンテナンス中のためアクセス申請の承認と却下は停止しています")
    expect(access_request.reload).to be_pending
    expect(access_request.rejection_reason).to be_blank
    expect(access_request.rejected_at).to be_nil
  end

  it "keeps admin indexes, detail, and pending handoff readable during read-only maintenance" do
    access_request = create(:access_request, requester:, requestable: document, requested_access_level: :download, reason: "Need admin review")
    sign_in_as(admin_user)

    with_read_only_maintenance("1") do
      get admin_access_requests_path, params: { status: "pending", q: "admin review" }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(access_request.reason)

      get admin_access_request_path(access_request)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(access_request.reason)

      get pending_handoff_admin_access_requests_path(format: :json), params: { q: "admin review" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("status")).to eq("pending")
      expect(response.parsed_body.fetch("candidates").first.fetch("public_id")).to eq(access_request.public_id)
    end
  end

  it "keeps admin approval and rejection working when read-only maintenance is disabled" do
    approval_request = create(:access_request, requester:, requestable: document, requested_access_level: :download)
    rejection_request = create(:access_request, requester:, requestable: project, requested_access_level: :view)
    sign_in_as(admin_user)

    expect do
      with_read_only_maintenance("0") do
        patch admin_access_request_path(approval_request), params: { decision: "approve" }
      end
    end.to change { DocumentPermission.where(document:, user: requester).count }.by(1)

    expect(response).to redirect_to(admin_access_requests_path)
    expect(approval_request.reload).to be_approved

    with_read_only_maintenance("0") do
      patch admin_access_request_path(rejection_request), params: { decision: "reject", rejection_reason_preset: "permission_shortage" }
    end

    expect(response).to redirect_to(admin_access_requests_path)
    expect(rejection_request.reload).to be_rejected
    expect(rejection_request.rejection_reason).to eq("権限不足")
  end
end
