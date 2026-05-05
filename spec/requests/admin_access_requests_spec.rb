require "rails_helper"

RSpec.describe "Admin access requests", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "REQ", name: "Request Project") }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external) }

  before do
    create(:project_membership, project:, user: requester)
  end

  it "shows access requests to internal admins" do
    access_request = create(:access_request, requester:, requestable: document, requested_access_level: :download)

    sign_in_as(admin_user)

    get admin_access_requests_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("アクセス申請")
    expect(response.body).to include(access_request.reason)
    expect(response.body).to include("Manual")
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

  it "rejects a pending request" do
    access_request = create(:access_request, requester:, requestable: project, requested_access_level: :view)

    sign_in_as(admin_user)

    patch admin_access_request_path(access_request), params: { decision: "reject", rejection_reason: "Not approved" }

    expect(response).to redirect_to(admin_access_requests_path)
    expect(access_request.reload).to be_rejected
    expect(access_request.rejection_reason).to eq("Not approved")
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
