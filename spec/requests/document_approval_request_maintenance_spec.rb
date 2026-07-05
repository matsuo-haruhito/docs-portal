require "rails_helper"

RSpec.describe "Document approval request maintenance mode", type: :request do
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:) }
  let(:internal_user) { create(:user, :internal) }
  let(:approver) { create(:user, :internal, name: "確認担当") }
  let(:project) { create(:project, code: "APR-MAINT", name: "Approval Maintenance Project") }
  let(:document) { create(:document, project:, title: "確認資料", slug: "approval-maintenance-doc", visibility_policy: :restricted_external) }
  let(:return_to_path) { project_document_document_approval_requests_path(project, document, status: :pending) }

  def with_read_only_maintenance(value)
    previous = ENV.fetch(DocumentApprovalRequestsController::READ_ONLY_MAINTENANCE_ENV, nil)
    ENV[DocumentApprovalRequestsController::READ_ONLY_MAINTENANCE_ENV] = value
    yield
  ensure
    if previous.nil?
      ENV.delete(DocumentApprovalRequestsController::READ_ONLY_MAINTENANCE_ENV)
    else
      ENV[DocumentApprovalRequestsController::READ_ONLY_MAINTENANCE_ENV] = previous
    end
  end

  before do
    create(:project_membership, project:, user: requester)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "does not create document approval requests while read-only maintenance is enabled" do
    sign_in_as(requester)

    expect do
      with_read_only_maintenance("1") do
        post project_document_document_approval_requests_path(project, document), params: {
          document_approval_request: {
            title: "確認お願いします",
            body: "公開前に見てください",
            approver_id: approver.id
          }
        }
      end
    end.not_to change(DocumentApprovalRequest, :count)

    expect(response).to redirect_to(project_document_path(project, document.slug))
    expect(flash[:alert]).to include("メンテナンス中のため確認依頼の新規作成は停止しています")
  end

  it "does not approve or cancel pending requests while read-only maintenance is enabled" do
    approval_request = create(:document_approval_request, document:, requester:, approver:, title: "OK前の確認依頼")
    internal_cancel_request = create(:document_approval_request, document:, requester:, approver:, title: "内部Cancel前の確認依頼")
    requester_cancel_request = create(:document_approval_request, document:, requester:, approver:, title: "依頼者Cancel前の確認依頼")

    sign_in_as(internal_user)

    with_read_only_maintenance("1") do
      expect do
        patch document_approval_request_path(approval_request, return_to: return_to_path)
      end.not_to change { approval_request.reload.attributes.slice("status", "acted_by_id", "approved_at", "cancelled_at") }
    end
    expect(response).to redirect_to(document_approval_request_path(approval_request, return_to: return_to_path))
    expect(flash[:alert]).to include("メンテナンス中のため確認依頼のOK / Cancelは停止しています")

    with_read_only_maintenance("1") do
      expect do
        post cancel_document_approval_request_path(internal_cancel_request, return_to: return_to_path)
      end.not_to change { internal_cancel_request.reload.attributes.slice("status", "acted_by_id", "approved_at", "cancelled_at") }
    end
    expect(response).to redirect_to(document_approval_request_path(internal_cancel_request, return_to: return_to_path))
    expect(flash[:alert]).to include("メンテナンス中のため確認依頼のOK / Cancelは停止しています")

    sign_in_as(requester)

    with_read_only_maintenance("1") do
      expect do
        post cancel_document_approval_request_path(requester_cancel_request)
      end.not_to change { requester_cancel_request.reload.attributes.slice("status", "acted_by_id", "approved_at", "cancelled_at") }
    end
    expect(response).to redirect_to(document_approval_request_path(requester_cancel_request, return_to: project_document_path(project, document.slug)))
    expect(flash[:alert]).to include("メンテナンス中のため確認依頼のOK / Cancelは停止しています")
  end

  it "keeps approval request indexes and detail readable during read-only maintenance" do
    approval_request = create(:document_approval_request, document:, requester:, approver:, title: "確認お願いします")

    sign_in_as(internal_user)

    with_read_only_maintenance("1") do
      get document_approval_requests_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(approval_request.title)

      get project_document_document_approval_requests_path(project, document), params: { status: :pending, approver_id: approver.id }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(approval_request.title)

      get document_approval_request_path(approval_request)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(approval_request.title)
    end
  end

  it "keeps the existing create, OK, and Cancel flow when read-only maintenance is disabled" do
    sign_in_as(requester)

    expect do
      with_read_only_maintenance("0") do
        post project_document_document_approval_requests_path(project, document), params: {
          document_approval_request: {
            title: "確認お願いします",
            body: "公開前に見てください",
            approver_id: approver.id
          }
        }
      end
    end.to change(DocumentApprovalRequest, :count).by(1)

    created_request = DocumentApprovalRequest.order(:id).last
    expect(response).to redirect_to(document_approval_request_path(created_request, return_to: project_document_path(project, document.slug)))
    expect(created_request.requester).to eq(requester)
    expect(created_request.approver).to eq(approver)
    expect(created_request).to be_pending

    approval_request = create(:document_approval_request, document:, requester:, approver:, title: "OKする確認依頼")
    internal_cancel_request = create(:document_approval_request, document:, requester:, approver:, title: "内部Cancelする確認依頼")
    requester_cancel_request = create(:document_approval_request, document:, requester:, approver:, title: "依頼者Cancelする確認依頼")

    sign_in_as(internal_user)

    with_read_only_maintenance("0") do
      patch document_approval_request_path(approval_request, return_to: return_to_path)
    end
    expect(response).to redirect_to(document_approval_request_path(approval_request, return_to: return_to_path))
    expect(approval_request.reload).to be_approved
    expect(approval_request.acted_by).to eq(internal_user)

    with_read_only_maintenance("0") do
      post cancel_document_approval_request_path(internal_cancel_request, return_to: return_to_path)
    end
    expect(response).to redirect_to(document_approval_request_path(internal_cancel_request, return_to: return_to_path))
    expect(internal_cancel_request.reload).to be_cancelled
    expect(internal_cancel_request.acted_by).to eq(internal_user)

    sign_in_as(requester)

    with_read_only_maintenance("0") do
      post cancel_document_approval_request_path(requester_cancel_request)
    end
    expect(response).to redirect_to(document_approval_request_path(requester_cancel_request, return_to: project_document_path(project, document.slug)))
    expect(requester_cancel_request.reload).to be_cancelled
    expect(requester_cancel_request.acted_by).to eq(requester)
  end
end
