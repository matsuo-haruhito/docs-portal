require "rails_helper"

RSpec.describe "Document approval request user filter search", type: :request do
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:, name: "Client Requester", email_address: "client-requester@example.com") }
  let(:internal_user) { create(:user, :internal, name: "Internal Admin", email_address: "admin@example.com") }
  let(:project) { create(:project, code: "APR", name: "Approval Project") }
  let(:document) { create(:document, project:, title: "確認資料", slug: "approval-doc", visibility_policy: :restricted_external) }

  def json_response
    JSON.parse(response.body)
  end

  before do
    create(:project_membership, project:, user: requester)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "returns bounded requester and approver options from the global approval request relation" do
    approver = create(:user, :internal, name: "Review Owner", email_address: "review-owner@example.com")
    unrelated_user = create(:user, :internal, name: "Review Outsider", email_address: "review-outsider@example.com")
    create(:document_approval_request, document:, requester:, approver:, title: "確認お願いします")

    sign_in_as(internal_user)

    get requester_search_document_approval_requests_path(format: :json), params: { q: "Client" }
    expect(response).to have_http_status(:ok)
    expect(json_response.fetch("options")).to contain_exactly(
      include("value" => requester.id, "text" => "Client Requester / client-requester@example.com")
    )

    get approver_search_document_approval_requests_path(format: :json), params: { q: "review" }
    expect(response).to have_http_status(:ok)
    expect(json_response.fetch("options")).to contain_exactly(
      include("value" => approver.id, "text" => "Review Owner / review-owner@example.com")
    )
    expect(response.body).not_to include(unrelated_user.email_address)
  end

  it "bounds search results and restores selected users outside the first candidate page" do
    22.times do |index|
      role_user = create(:user, :external, company:, name: format("Listed Requester %02d", index), email_address: "listed-requester-#{index}@example.com")
      create(:project_membership, project:, user: role_user)
      create(:document_approval_request, document:, requester: role_user, title: "Listed request #{index}")
    end
    selected_requester = create(:user, :external, company:, name: "Selected Requester", email_address: "selected-requester@example.com")
    create(:project_membership, project:, user: selected_requester)
    create(:document_approval_request, document:, requester: selected_requester, title: "Selected request")

    sign_in_as(internal_user)

    get requester_search_document_approval_requests_path(format: :json), params: { q: "Listed Requester" }
    expect(response).to have_http_status(:ok)
    expect(json_response.fetch("options").size).to eq(DocumentApprovalRequestsController::USER_FILTER_SEARCH_LIMIT)

    get selected_requester_document_approval_requests_path(format: :json), params: { id: selected_requester.id }
    expect(response).to have_http_status(:ok)
    expect(json_response.fetch("option")).to include(
      "value" => selected_requester.id,
      "text" => "Selected Requester / selected-requester@example.com"
    )
  end

  it "keeps nested document requester and approver candidates scoped to the nested document" do
    nested_approver = create(:user, :internal, name: "Nested Approver", email_address: "nested-approver@example.com")
    other_requester = create(:user, :external, company:, name: "Other Requester", email_address: "other-requester@example.com")
    other_approver = create(:user, :internal, name: "Other Approver", email_address: "other-approver@example.com")
    other_document = create(:document, project:, title: "別資料", slug: "other-approval-doc", visibility_policy: :restricted_external)
    create(:document_permission, document: other_document, company:, access_level: :view)
    create(:project_membership, project:, user: other_requester)
    create(:document_approval_request, document:, requester:, approver: nested_approver, title: "Nested request")
    create(:document_approval_request, document: other_document, requester: other_requester, approver: other_approver, title: "Other request")

    sign_in_as(internal_user)

    get requester_search_project_document_document_approval_requests_path(project, document, format: :json), params: { q: "Requester" }
    expect(response).to have_http_status(:ok)
    requester_options = json_response.fetch("options")
    expect(requester_options).to contain_exactly(include("value" => requester.id))
    expect(response.body).not_to include(other_requester.email_address)

    get approver_search_project_document_document_approval_requests_path(project, document, format: :json), params: { q: "Approver" }
    expect(response).to have_http_status(:ok)
    approver_options = json_response.fetch("options")
    expect(approver_options).to contain_exactly(include("value" => nested_approver.id))
    expect(response.body).not_to include(other_approver.email_address)
  end

  it "returns nil selected options for users outside the role relation and forbids external users" do
    outsider = create(:user, :external, company:, name: "Outside User", email_address: "outside@example.com")
    create(:document_approval_request, document:, requester:, title: "確認お願いします")

    sign_in_as(internal_user)

    get selected_requester_document_approval_requests_path(format: :json), params: { id: outsider.id }
    expect(response).to have_http_status(:ok)
    expect(json_response.fetch("option")).to be_nil

    sign_in_as(requester)
    get requester_search_document_approval_requests_path(format: :json), params: { q: "Client" }
    expect(response).to have_http_status(:forbidden)
  end
end
