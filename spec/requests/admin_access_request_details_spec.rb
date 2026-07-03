require "rails_helper"

RSpec.describe "Admin access request details", type: :request do
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

  def link_href(text)
    parsed_html.css("a[href]").find { |link| link.text.squish == text }&.[]("href")
  end

  before do
    create(:project_membership, project:, user: requester)
  end

  it "links filtered list rows to the detail screen with a safe return path" do
    access_request = create(:access_request, requester:, requestable: document, requested_access_level: :download, reason: "Need Manual access")

    sign_in_as(admin_user)

    get admin_access_requests_path, params: { status: "pending", q: "Manual" }

    expect(response).to have_http_status(:ok)
    detail_link = parsed_html.css("a[href]").find { |link| link.text.squish == "詳細" }
    expect(detail_link).to be_present
    expect(detail_link["href"]).to include(admin_access_request_path(access_request))
    expect(detail_link["href"]).to include("return_to=")
  end

  it "shows pending request details and the existing approve/reject actions" do
    access_request = create(:access_request, requester:, requestable: document, requested_access_level: :download, reason: "Need Manual access")
    return_path = admin_access_requests_path(status: "pending", q: "Manual")

    sign_in_as(admin_user)

    get admin_access_request_path(access_request), params: { return_to: return_path }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("アクセス申請詳細")
    expect(page_text).to include(access_request.public_id)
    expect(page_text).to include("Client User / client@example.com")
    expect(page_text).to include("文書")
    expect(page_text).to include("Manual")
    expect(page_text).to include("REQ")
    expect(page_text).to include("ダウンロード")
    expect(page_text).to include("Need Manual access")
    expect(link_href("一覧へ戻る")).to eq(return_path)

    action_forms = parsed_html.css("form[action='#{admin_access_request_path(access_request)}']")
    expect(action_forms.size).to eq(2)
    expect(page_text).to include("承認")
    expect(page_text).to include("却下")
    expect(action_forms.to_html).to include("return_to")
  end

  it "approves from detail and redirects to a safe return path" do
    access_request = create(:access_request, requester:, requestable: document, requested_access_level: :download)
    return_path = admin_access_requests_path(status: "pending", q: "Manual")

    sign_in_as(admin_user)

    expect do
      patch admin_access_request_path(access_request), params: { decision: "approve", return_to: return_path }
    end.to change { DocumentPermission.where(document:, user: requester).count }.by(1)

    expect(response).to redirect_to(return_path)
    expect(access_request.reload).to be_approved
    expect(access_request.approver).to eq(admin_user)
  end

  it "rejects from detail and redirects to a safe return path" do
    access_request = create(:access_request, requester:, requestable: project, requested_access_level: :view)
    return_path = admin_access_requests_path(status: "pending", requestable_type: "Project")

    sign_in_as(admin_user)

    patch admin_access_request_path(access_request), params: {
      decision: "reject",
      rejection_reason_preset: "insufficient_information",
      rejection_reason_note: "申請理由を追記してください",
      return_to: return_path
    }

    expect(response).to redirect_to(return_path)
    expect(access_request.reload).to be_rejected
    expect(access_request.rejection_reason).to eq("情報不足：申請理由を追記してください")
  end

  it "shows processed requests without decision actions and falls back from unsafe return paths" do
    access_request = create(:access_request,
      requester:,
      requestable: project,
      requested_access_level: :view,
      status: :approved,
      approver: admin_user,
      approved_at: Time.zone.local(2026, 5, 1, 12, 0, 0),
      reason: "Already approved")

    sign_in_as(admin_user)

    get admin_access_request_path(access_request), params: { return_to: "https://example.com/admin/access_requests" }

    expect(response).to have_http_status(:ok)
    expect(link_href("一覧へ戻る")).to eq(admin_access_requests_path)
    expect(page_text).to include("承認済み")
    expect(page_text).to include("承認日時")
    expect(page_text).to include("この申請は処理済みまたは取消済み")
    expect(parsed_html.css("form[action='#{admin_access_request_path(access_request)}']")).to be_empty
  end

  it "falls back from unsafe return paths after update" do
    access_request = create(:access_request, requester:, requestable: document, requested_access_level: :download)

    sign_in_as(admin_user)

    patch admin_access_request_path(access_request), params: {
      decision: "approve",
      return_to: "//example.com/admin/access_requests"
    }

    expect(response).to redirect_to(admin_access_requests_path)
    expect(access_request.reload).to be_approved
  end

  it "forbids external users from the detail screen" do
    access_request = create(:access_request, requester:, requestable: document, requested_access_level: :download)

    sign_in_as(external_user)

    get admin_access_request_path(access_request)

    expect(response).to have_http_status(:forbidden)
  end
end
