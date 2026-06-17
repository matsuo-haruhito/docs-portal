require "rails_helper"

RSpec.describe "Admin access request filter contract", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:, name: "Client User", email_address: "client@example.com") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def result_table_text
    parsed_html.css("tbody").text.squish
  end

  it "searches representative project, document, and document file target fields" do
    project_target = create(:project, code: "ALPHA-QA", name: "Alpha Requests")
    document_project = create(:project, code: "DOC-HOST", name: "Document Host")
    document_target = create(:document,
      project: document_project,
      title: "Safety Binder",
      slug: "safety-binder",
      visibility_policy: :restricted_external)
    file_project = create(:project, code: "FILE-HOST", name: "File Host")
    file_document = create(:document,
      project: file_project,
      title: "File Container",
      slug: "file-container",
      visibility_policy: :restricted_external)
    document_file = create(:document_file,
      document_version: create(:document_version, document: file_document),
      file_name: "signed-appendix.pdf",
      search_text: "OCR token lunar")

    create(:access_request, requester:, requestable: project_target, requested_access_level: :view, reason: "Project target request")
    create(:access_request, requester:, requestable: document_target, requested_access_level: :download, reason: "Document target request")
    create(:access_request, requester:, requestable: document_file, requested_access_level: :download, reason: "File target request")
    create(:access_request, requester:, requestable: create(:project, code: "OTHER", name: "Other Project"), requested_access_level: :view, reason: "Other request")

    sign_in_as(admin_user)

    get admin_access_requests_path, params: { q: "ALPHA-QA" }

    expect(response).to have_http_status(:ok)
    expect(result_table_text).to include("Project target request")
    expect(result_table_text).not_to include("Document target request", "File target request", "Other request")

    get admin_access_requests_path, params: { q: "safety-binder" }

    expect(response).to have_http_status(:ok)
    expect(result_table_text).to include("Document target request")
    expect(result_table_text).not_to include("Project target request", "File target request", "Other request")

    get admin_access_requests_path, params: { q: "lunar" }

    expect(response).to have_http_status(:ok)
    expect(result_table_text).to include("File target request")
    expect(result_table_text).not_to include("Project target request", "Document target request", "Other request")
  end

  it "counts statuses after applying query, access level, and target type filters" do
    matching_project = create(:project, code: "COUNT-QA", name: "Count Target")
    other_project = create(:project, code: "COUNT-OTHER", name: "Other Count Target")

    matching_pending = create(:access_request,
      requester:,
      requestable: matching_project,
      requested_access_level: :view,
      reason: "Count pending request")
    create(:access_request,
      requester:,
      requestable: matching_project,
      requested_access_level: :view,
      status: :approved,
      approver: admin_user,
      approved_at: Time.zone.local(2026, 6, 1, 12, 0, 0),
      reason: "Count approved request")
    create(:access_request,
      requester:,
      requestable: matching_project,
      requested_access_level: :download,
      reason: "Count download request")
    create(:access_request,
      requester:,
      requestable: other_project,
      requested_access_level: :view,
      status: :rejected,
      approver: admin_user,
      rejected_at: Time.zone.local(2026, 6, 1, 13, 0, 0),
      rejection_reason: "Out of scope",
      reason: "Other rejected request")

    sign_in_as(admin_user)

    get admin_access_requests_path, params: {
      q: "COUNT-QA",
      requested_access_level: "view",
      requestable_type: "Project"
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索結果: 2件")
    expect(page_text).to include("要求権限: 閲覧")
    expect(page_text).to include("対象種別: 案件")
    expect(page_text).to include("検索結果内訳: 承認待ち: 1 / 承認済み: 1 / 却下: 0")
    expect(result_table_text).to include("Count pending request", "Count approved request")
    expect(result_table_text).not_to include("Count download request", "Other rejected request")
    expect(parsed_html.css("form[action='#{admin_access_request_path(matching_pending)}']").size).to eq(2)
  end
end
