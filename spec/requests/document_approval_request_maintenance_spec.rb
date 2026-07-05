require "rails_helper"

RSpec.describe "Document approval request maintenance mode", type: :request do
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:) }
  let(:internal_user) { create(:user, :internal) }
  let(:approver) { create(:user, :internal, name: "確認担当") }
  let(:project) { create(:project, code: "APR-MAINT", name: "Approval Maintenance Project") }
  let(:document) { create(:document, project:, title: "確認資料", slug: "approval-maintenance-doc", visibility_policy: :restricted_external) }

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

  it "keeps the existing create flow when read-only maintenance is disabled" do
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

    approval_request = DocumentApprovalRequest.order(:id).last
    expect(response).to redirect_to(document_approval_request_path(approval_request, return_to: project_document_path(project, document.slug)))
    expect(approval_request.requester).to eq(requester)
    expect(approval_request.approver).to eq(approver)
    expect(approval_request).to be_pending
  end
end
