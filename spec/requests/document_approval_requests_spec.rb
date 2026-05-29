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

  it "shows detail to internal users and supports OK / Cancel" do
    approval_request = create(:document_approval_request, document:, requester:, title: "確認お願いします")
    return_to_path = project_document_document_approval_requests_path(project, document, status: :pending)

    sign_in_as(internal_user)

    get document_approval_request_path(approval_request, return_to: return_to_path)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("OK")
    expect(response.body).to include("対応待ち")
    expect(parsed_html.at_css(%(a[href="#{return_to_path}"]))).to be_present

    patch document_approval_request_path(approval_request, return_to: return_to_path)
    expect(response).to redirect_to(document_approval_request_path(approval_request, return_to: return_to_path))
    expect(approval_request.reload).to be_approved
    expect(approval_request.acted_by).to eq(internal_user)

    get document_approval_request_path(approval_request, return_to: return_to_path)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("OK済み")

    another_request = create(:document_approval_request, document:, requester:, title: "今回は進めない")
    post cancel_document_approval_request_path(another_request, return_to: return_to_path)
    expect(response).to redirect_to(document_approval_request_path(another_request, return_to: return_to_path))
    expect(another_request.reload).to be_cancelled

    get document_approval_request_path(another_request, return_to: return_to_path)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Cancel済み")
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
