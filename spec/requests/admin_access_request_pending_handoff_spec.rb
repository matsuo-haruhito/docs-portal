require "rails_helper"

RSpec.describe "Admin access request pending handoff", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:, name: "Client User", email_address: "client@example.com") }
  let(:project) { create(:project, code: "REQ", name: "Request Project") }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external) }

  def json_response
    JSON.parse(response.body)
  end

  before do
    create(:project_membership, project:, user: requester)
  end

  it "returns pending handoff candidates for the current filter without changing requests" do
    matching_request = create(:access_request,
      requester:,
      requestable: document,
      requested_access_level: :download,
      reason: "Need manual download because the reviewer must confirm a narrow operational handoff boundary " + ("x" * 120))
    create(:access_request,
      requester:,
      requestable: document,
      requested_access_level: :download,
      status: :approved,
      approver: admin_user,
      approved_at: Time.zone.local(2026, 5, 1, 12, 0, 0),
      reason: "Approved manual download")
    create(:access_request, requester:, requestable: project, requested_access_level: :view, reason: "Other pending project")

    sign_in_as(admin_user)

    expect do
      get pending_handoff_admin_access_requests_path(format: :json), params: {
        q: "manual",
        requested_access_level: "download",
        requestable_type: "Document"
      }
    end.not_to change { AccessRequest.pluck(:id, :status, :approver_id, :approved_at, :rejected_at, :rejection_reason) }

    expect(response).to have_http_status(:ok)
    payload = json_response
    candidate = payload.fetch("candidates").sole

    expect(payload.fetch("current_filter")).to include(
      "q" => "manual",
      "requested_access_level" => "download",
      "requestable_type" => "Document"
    )
    expect(payload.fetch("status")).to eq("pending")
    expect(payload.fetch("total_count")).to eq(1)
    expect(payload.fetch("limit")).to eq(Admin::AccessRequestsController::PENDING_HANDOFF_LIMIT)
    expect(payload.fetch("truncated")).to be(false)
    expect(payload.fetch("note")).to include("read-only handoff")
    expect(candidate).to include(
      "public_id" => matching_request.public_id,
      "requester" => "Client User / client@example.com",
      "requestable_type" => "Document",
      "requestable_label" => "Manual",
      "requestable_context" => "REQ",
      "requested_access_level" => "download",
      "status" => "pending"
    )
    expect(candidate.fetch("reason_preview").length).to be <= Admin::AccessRequestsController::REASON_PREVIEW_LENGTH
    expect(candidate.fetch("admin_review_path")).to eq(admin_access_requests_path(status: "pending", q: matching_request.public_id))
    expect(payload.to_s).not_to include("Approved manual download", "Other pending project")
  end

  it "returns an explicit zero-candidate note when the current filter has no pending handoff targets" do
    create(:access_request,
      requester:,
      requestable: document,
      requested_access_level: :download,
      status: :approved,
      approver: admin_user,
      approved_at: Time.zone.local(2026, 5, 1, 12, 0, 0),
      reason: "Approved manual download")

    sign_in_as(admin_user)

    get pending_handoff_admin_access_requests_path(format: :json), params: { status: "approved", q: "manual" }

    expect(response).to have_http_status(:ok)
    payload = json_response
    expect(payload.fetch("current_filter")).to include("status" => "approved", "q" => "manual")
    expect(payload.fetch("total_count")).to eq(0)
    expect(payload.fetch("candidates")).to eq([])
    expect(payload.fetch("truncated")).to be(false)
    expect(payload.fetch("note")).to include("現在条件で pending handoff 対象はありません")
    expect(payload.fetch("note")).to include("正常保証")
  end

  it "bounds candidates and reports truncation" do
    51.times do |index|
      create(:access_request,
        requester:,
        requestable: document,
        requested_access_level: :download,
        reason: "Pending bulk handoff #{index}",
        created_at: Time.zone.local(2026, 5, 1, 12, index, 0))
    end

    sign_in_as(admin_user)

    get pending_handoff_admin_access_requests_path(format: :json), params: { requested_access_level: "download" }

    expect(response).to have_http_status(:ok)
    payload = json_response
    expect(payload.fetch("total_count")).to eq(51)
    expect(payload.fetch("limit")).to eq(50)
    expect(payload.fetch("truncated")).to be(true)
    expect(payload.fetch("candidates").size).to eq(50)
  end

  it "forbids external users" do
    create(:access_request, requester:, requestable: project, requested_access_level: :view)

    sign_in_as(external_user)

    get pending_handoff_admin_access_requests_path(format: :json)

    expect(response).to have_http_status(:forbidden)
  end
end
