require "rails_helper"

RSpec.describe "Document approval requests", type: :request do
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:) }
  let(:internal_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "APR", name: "Approval Project") }
  let(:document) { create(:document, project:, title: "確認資料", slug: "approval-doc", visibility_policy: :restricted_external) }

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
    expect(response).to redirect_to(document_approval_request_path(approval_request))
    expect(approval_request.requester).to eq(requester)
    expect(approval_request.document).to eq(document)
    expect(approval_request).to be_pending
  end

  it "shows index/detail to internal users and supports OK / Cancel" do
    approval_request = create(:document_approval_request, document:, requester:, title: "確認お願いします")

    sign_in_as(internal_user)

    get project_document_document_approval_requests_path(project, document)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("確認お願いします")

    get document_approval_request_path(approval_request)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("OK")

    patch document_approval_request_path(approval_request)
    expect(response).to redirect_to(document_approval_request_path(approval_request))
    expect(approval_request.reload).to be_approved
    expect(approval_request.acted_by).to eq(internal_user)

    another_request = create(:document_approval_request, document:, requester:, title: "今回は進めない")
    post cancel_document_approval_request_path(another_request)
    expect(response).to redirect_to(document_approval_request_path(another_request))
    expect(another_request.reload).to be_cancelled
  end
end
