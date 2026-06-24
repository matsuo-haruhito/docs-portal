require "csv"
require "rails_helper"

RSpec.describe "Admin access log current page CSV export", type: :request do
  let(:admin_company) { create(:company, domain: "audit.example.com", name: "Audit Company") }
  let(:admin_user) { create(:user, :internal, company: admin_company) }
  let(:project) { create(:project, code: "CSVPG", name: "CSV Page Project") }
  let(:document) { create(:document, project:, title: "CSV Page Evidence", slug: "csv-page-evidence") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0") }

  def create_access_log!(target_name:, project: self.project, document: self.document, document_version: version, accessed_at: Time.current)
    AccessLog.create!(
      user: admin_user,
      company: admin_company,
      project:,
      document:,
      document_version:,
      action_type: :view,
      target_type: "page",
      target_name:,
      ip_address: "127.0.0.1",
      user_agent: "RSpec",
      accessed_at:
    )
  end

  def csv_target_names
    CSV.parse(response.body, headers: true).map { _1["対象名"] }
  end

  it "keeps the default CSV export on latest rows even when a page parameter is present" do
    base_time = Time.zone.parse("2026-05-01 00:00:00 UTC")

    201.times do |index|
      create_access_log!(target_name: "default-scope-entry-#{index}", accessed_at: base_time + index.minutes)
    end

    sign_in_as(admin_user)

    get admin_access_logs_path(format: :csv, project_id: project.id, page: 2)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(csv_target_names.size).to eq(Admin::AccessLogsController::ACCESS_LOGS_PER_PAGE)
    expect(csv_target_names.first).to eq("default-scope-entry-200")
    expect(csv_target_names.last).to eq("default-scope-entry-1")
    expect(csv_target_names).not_to include("default-scope-entry-0")
  end

  it "exports the current page rows only when the current page scope is explicit" do
    base_time = Time.zone.parse("2026-05-01 00:00:00 UTC")

    202.times do |index|
      create_access_log!(target_name: "current-page-entry-#{index}", accessed_at: base_time + index.minutes)
    end
    create_access_log!(target_name: "outside-filter-entry", project: create(:project), document: nil, document_version: nil, accessed_at: base_time + 1.day)

    sign_in_as(admin_user)

    get admin_access_logs_path(
      format: :csv,
      csv_scope: Admin::AccessLogsController::CSV_SCOPE_CURRENT_PAGE,
      project_id: project.id,
      document_q: "CSV Page Evidence",
      page: 2
    )

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(csv_target_names).to eq(["current-page-entry-1", "current-page-entry-0"])
    expect(csv_target_names).not_to include("outside-filter-entry")
  end

  it "bounds invalid current page CSV requests to the first page without expanding the row limit" do
    base_time = Time.zone.parse("2026-05-01 00:00:00 UTC")

    205.times do |index|
      create_access_log!(target_name: "bounded-current-page-entry-#{index}", accessed_at: base_time + index.seconds)
    end

    sign_in_as(admin_user)

    get admin_access_logs_path(
      format: :csv,
      csv_scope: Admin::AccessLogsController::CSV_SCOPE_CURRENT_PAGE,
      page: "999999",
      limit: "1000"
    )

    expect(response).to have_http_status(:ok)
    expect(csv_target_names.size).to eq(Admin::AccessLogsController::ACCESS_LOGS_PER_PAGE)
    expect(csv_target_names.first).to eq("bounded-current-page-entry-204")
    expect(csv_target_names.last).to eq("bounded-current-page-entry-5")
    expect(csv_target_names).not_to include("bounded-current-page-entry-4", "bounded-current-page-entry-0")
  end

  it "describes latest rows and current page rows as separate metadata scopes" do
    sign_in_as(admin_user)

    get admin_access_logs_path(format: :json, page: 2)

    expect(response).to have_http_status(:ok)
    latest_metadata = JSON.parse(response.body)
    expect(latest_metadata).to include(
      "export_scope" => "current_filter_latest_rows",
      "row_limit" => Admin::AccessLogsController::ACCESS_LOGS_PER_PAGE
    )
    expect(latest_metadata).not_to include("page")
    expect(latest_metadata.fetch("description")).to include("表示中ページではなく")
    expect(latest_metadata.fetch("summary")).to include("最新#{Admin::AccessLogsController::ACCESS_LOGS_PER_PAGE}件")

    get admin_access_logs_path(
      format: :json,
      csv_scope: Admin::AccessLogsController::CSV_SCOPE_CURRENT_PAGE,
      page: 2,
      q: "current-page"
    )

    expect(response).to have_http_status(:ok)
    current_page_metadata = JSON.parse(response.body)
    expect(current_page_metadata).to include(
      "export_scope" => "current_filter_current_page_rows",
      "row_limit" => Admin::AccessLogsController::ACCESS_LOGS_PER_PAGE,
      "page" => 2
    )
    expect(current_page_metadata.fetch("description")).to include("現在の絞り込み条件とページ")
    expect(current_page_metadata.fetch("summary")).to include("2ページ目の最大#{Admin::AccessLogsController::ACCESS_LOGS_PER_PAGE}件")
    expect(current_page_metadata.fetch("filters")).to include("q" => "current-page")
  end
end
