require "csv"
require "rails_helper"

RSpec.describe "Admin access log export boundaries", type: :request do
  let(:admin_company) { create(:company, domain: "audit.example.com", name: "Audit Company") }
  let(:admin_user) { create(:user, :internal, company: admin_company) }
  let(:project) { create(:project, code: "AUDIT", name: "Audit Project") }
  let(:document) { create(:document, project:, title: "Audit Document", slug: "audit-document") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0") }

  def create_access_log!(action_type:, target_type:, target_name:, user: admin_user, company: admin_user.company, project: self.project, document: self.document, document_version: version, accessed_at: Time.current, ip_address: "127.0.0.1")
    AccessLog.create!(
      user:,
      company:,
      project:,
      document:,
      document_version:,
      action_type:,
      target_type:,
      target_name:,
      ip_address:,
      user_agent: "RSpec",
      accessed_at:
    )
  end

  it "exports metadata JSON with current filters, ignored dates, row limit, and summary" do
    base_time = Time.zone.parse("2026-05-10 12:00:00 UTC")
    other_project = create(:project, code: "OTHER", name: "Other Project")
    other_document = create(:document, project: other_project, title: "Other Document", slug: "other-document")
    other_version = create(:document_version, document: other_document, version_label: "v2.0.0")

    create_access_log!(
      action_type: :download,
      target_type: "zip",
      target_name: "metadata-target.zip",
      accessed_at: base_time,
      ip_address: "203.0.113.10"
    )
    create_access_log!(
      action_type: :download,
      target_type: "zip",
      target_name: "metadata-target-other-project.zip",
      project: other_project,
      document: other_document,
      document_version: other_version,
      accessed_at: base_time
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(
      format: :json,
      action_type: "download",
      target_type: "zip",
      project_id: project.id,
      q: "metadata-target",
      from: "not-a-date",
      to: "2026-05-10"
    )

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")

    metadata = JSON.parse(response.body)

    expect(metadata).to include(
      "report_type" => "access_logs",
      "row_limit" => Admin::AccessLogsController::ACCESS_LOGS_PER_PAGE,
      "export_scope" => "current_filter_latest_rows",
      "ignored_filters" => ["from"]
    )
    expect(metadata.fetch("filters")).to include(
      "action_type" => "download",
      "target_type" => "zip",
      "project_id" => project.id.to_s,
      "project" => { "code" => "AUDIT", "name" => "Audit Project" },
      "q" => "metadata-target",
      "to" => "2026-05-10"
    )
    expect(metadata.fetch("filters")).not_to have_key("from")
    expect(metadata.fetch("summary")).to include("監査ログ", "最新200件", "条件: action_type, target_type, project_id, q, to")
    expect(metadata.fetch("summary")).to include("無効な日付条件を除外: from")
  end

  it "exports parsed AI context CSV columns only for complete numeric target names" do
    base_time = Time.zone.parse("2026-05-10 12:00:00 UTC")

    create_access_log!(
      action_type: :download,
      target_type: "ai_context",
      target_name: "mode=full;scope=selected;selected_count=2;exported_count=2",
      accessed_at: base_time + 2.seconds
    )
    create_access_log!(
      action_type: :download,
      target_type: "ai_context",
      target_name: "mode=compact;scope=all;selected_count=two;exported_count=9",
      accessed_at: base_time + 1.second
    )
    create_access_log!(
      action_type: :download,
      target_type: "page",
      target_name: "mode=full;scope=selected;selected_count=2;exported_count=2",
      accessed_at: base_time
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(format: :csv, action_type: "download")

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")

    rows = CSV.parse(response.body, headers: true)

    expect(rows.map { [_1["対象種別"], _1["対象名"]] }).to eq([
      ["ai_context", "mode=full;scope=selected;selected_count=2;exported_count=2"],
      ["ai_context", "mode=compact;scope=all;selected_count=two;exported_count=9"],
      ["page", "mode=full;scope=selected;selected_count=2;exported_count=2"]
    ])

    parsed_row = rows.find { _1["対象種別"] == "ai_context" && _1["対象名"].include?("mode=full") }
    expect(parsed_row.values_at(
      "AI context mode",
      "AI context scope",
      "AI context selected_count",
      "AI context exported_count"
    )).to eq(%w[full selected 2 2])

    malformed_row = rows.find { _1["対象種別"] == "ai_context" && _1["対象名"].include?("selected_count=two") }
    expect(malformed_row.values_at(
      "AI context mode",
      "AI context scope",
      "AI context selected_count",
      "AI context exported_count"
    )).to all(be_blank)

    non_ai_row = rows.find { _1["対象種別"] == "page" }
    expect(non_ai_row.values_at(
      "AI context mode",
      "AI context scope",
      "AI context selected_count",
      "AI context exported_count"
    )).to all(be_blank)
  end
end
