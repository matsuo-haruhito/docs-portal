require "rails_helper"

RSpec.describe "Admin access requests", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:, name: "Client User", email_address: "client@example.com") }
  let(:project) { create(:project, code: "REQ", name: "Request Project") }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def filter_form
    parsed_html.at_css("form[action='#{admin_access_requests_path}']")
  end

  before do
    create(:project_membership, project:, user: requester)
  end

  it "shows access requests to internal admins with filter controls" do
    access_request = create(:access_request, requester:, requestable: document, requested_access_level: :download)

    sign_in_as(admin_user)

    get admin_access_requests_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("アクセス申請")
    expect(page_text).to include(access_request.reason)
    expect(page_text).to include("Manual")
    expect(page_text).to include("表示中: 1件")
    expect(page_text).to include("表示中内訳: 承認待ち: 1 / 承認済み: 0 / 却下: 0")
    expect(filter_form).to be_present
    expect(filter_form.at_css("select[name='status']")).to be_present
    expect(filter_form.at_css("input[name='q']")).to be_present
  end

  it "filters requests by status and keeps pending actions visible" do
    pending_request = create(:access_request, requester:, requestable: document, requested_access_level: :download, reason: "Pending review")
    create(:access_request,
      requester:,
      requestable: project,
      requested_access_level: :view,
      status: :approved,
      approver: admin_user,
      approved_at: Time.zone.local(2026, 5, 1, 12, 0, 0),
      reason: "Approved already")
    create(:access_request,
      requester:,
      requestable: project,
      requested_access_level: :view,
      status: :rejected,
      approver: admin_user,
      rejected_at: Time.zone.local(2026, 5, 1, 13, 0, 0),
      rejection_reason: "No access",
      reason: "Rejected already")

    sign_in_as(admin_user)

    get admin_access_requests_path, params: { status: "pending" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("状態: 承認待ち")
    expect(page_text).to include("Pending review")
    expect(page_text).not_to include("Approved already")
    expect(page_text).not_to include("Rejected already")
    expect(page_text).to include("表示中内訳: 承認待ち: 1 / 承認済み: 0 / 却下: 0")
    expect(parsed_html.css("tbody tr").size).to eq(1)

    action_forms = parsed_html.css("form[action='#{admin_access_request_path(pending_request)}']")
    expect(action_forms.size).to eq(2)
    expect(page_text).to include("承認")
    expect(page_text).to include("却下")
    expect(action_forms.last.to_html).to include("承認条件を満たしていないため却下しました")
    expect(action_forms.last.to_html).not_to include("Not approved")
  end

  it "filters requests by requester or target search terms" do
    create(:access_request, requester:, requestable: document, requested_access_level: :download, reason: "Need Manual access")

    other_requester = create(:user, :external, company:, name: "Other User", email_address: "other@example.com")
    other_project = create(:project, code: "OPS", name: "Operations")
    create(:access_request, requester: other_requester, requestable: other_project, requested_access_level: :view, reason: "Ops access")

    sign_in_as(admin_user)

    get admin_access_requests_path, params: { q: "manual" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Need Manual access")
    expect(page_text).not_to include("Ops access")
    expect(page_text).to include("表示中内訳: 承認待ち: 1 / 承認済み: 0 / 却下: 0")
    expect(parsed_html.css("tbody tr").size).to eq(1)
    expect(filter_form.at_css("input[name='q']")["value"]).to eq("manual")
  end

  it "shows a filtered empty state when no requests match" do
    create(:access_request, requester:, requestable: document, requested_access_level: :download)

    sign_in_as(admin_user)

    get admin_access_requests_path, params: { q: "does-not-match" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致する申請はありません。")
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

    patch admin_access_request_path(access_request), params: { decision: "reject", rejection_reason: "承認条件を満たしていないため却下しました" }

    expect(response).to redirect_to(admin_access_requests_path)
    expect(access_request.reload).to be_rejected
    expect(access_request.rejection_reason).to eq("承認条件を満たしていないため却下しました")
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
