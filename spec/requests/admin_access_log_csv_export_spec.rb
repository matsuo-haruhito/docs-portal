require "rails_helper"
require "csv"
require "uri"

RSpec.describe "Admin access log CSV export", type: :request do
  let(:admin_company) { create(:company, domain: "audit.example.com", name: "Audit Company") }
  let(:admin_user) { create(:user, :internal, company: admin_company, name: "Audit Admin", email_address: "admin@example.com") }
  let(:external_user) { create(:user, :external) }
  let(:company_master_admin) { create(:user, :external, :company_master_admin) }
  let(:project) { create(:project, code: "AUDIT", name: "Audit Project") }
  let(:document) { create(:document, project:, title: "Audit Document", slug: "audit-document") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def csv_rows
    CSV.parse(response.body, headers: true)
  end

  def export_link
    parsed_html.css("a[href]").find { |link| link.text.squish.include?("CSV export") }
  end

  def export_link_params
    Rack::Utils.parse_nested_query(URI.parse(export_link["href"]).query)
  end

  def create_access_log!(action_type:, target_type:, target_name:, user: admin_user, company: admin_company, project: self.project, document: self.document, document_version: version, accessed_at: Time.current, ip_address: "127.0.0.1")
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

  it "shows a CSV export link that keeps the active filters and explains the fixed 200 row boundary" do
    sign_in_as(admin_user)

    get admin_access_logs_path(target_type: "zip", q: "audit.zip", from: "2026-06-01")

    expect(response).to have_http_status(:ok)
    expect(export_link).to be_present
    expect(URI.parse(export_link["href"]).path).to eq(admin_access_logs_path(format: :csv))
    expect(export_link_params).to include(
      "target_type" => "zip",
      "q" => "audit.zip",
      "from" => "2026-06-01"
    )
    expect(parsed_html.text.squish).to include("CSV export は現在の絞り込み条件に一致する最新200件を、監査用途の固定列で出力します。")
    expect(parsed_html.text.squish).to include("画面の表示列設定とは独立しています。")
  end

  it "exports the latest filtered access logs as fixed audit CSV columns" do
    create_access_log!(
      action_type: :download,
      target_type: "ai_context",
      target_name: "mode=full;scope=selected;selected_count=2;exported_count=2",
      accessed_at: Time.zone.parse("2026-06-01 10:00:00 UTC"),
      ip_address: "192.0.2.10"
    )
    create_access_log!(
      action_type: :download,
      target_type: "ai_context",
      target_name: "mode=compact;scope=selected;selected_count=2;exported_count=2",
      accessed_at: Time.zone.parse("2026-06-01 11:00:00 UTC")
    )
    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "mode=full;scope=selected;selected_count=2;exported_count=2",
      accessed_at: Time.zone.parse("2026-06-01 12:00:00 UTC")
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(
      format: :csv,
      action_type: "download",
      target_type: "ai_context",
      project_id: project.id,
      company_id: admin_company.id,
      user_id: admin_user.id,
      q: "mode=full",
      document_q: "Audit Document",
      from: "2026-06-01",
      to: "2026-06-02",
      ai_context_mode: "full",
      ai_context_scope: "selected"
    )

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(response.headers["Content-Disposition"]).to include("access-logs-")
    expect(csv_rows.headers).to eq(Admin::AccessLogsController::CSV_HEADERS)
    expect(csv_rows.size).to eq(1)
    expect(csv_rows.first.to_h).to include(
      "操作" => "download",
      "対象種別" => "ai_context",
      "対象名" => "mode=full;scope=selected;selected_count=2;exported_count=2",
      "AI context mode" => "full",
      "AI context scope" => "selected",
      "AI context selected_count" => "2",
      "AI context exported_count" => "2",
      "ユーザー名" => "Audit Admin",
      "ユーザーEmail" => "admin@example.com",
      "会社" => "Audit Company",
      "案件コード" => "AUDIT",
      "案件名" => "Audit Project",
      "文書名" => "Audit Document",
      "文書URL識別子" => "audit-document",
      "版" => "v1.0.0",
      "IPアドレス" => "192.0.2.10"
    )
  end

  it "limits CSV export to the latest 200 matching rows" do
    base_time = Time.zone.parse("2026-06-01 00:00:00 UTC")

    201.times do |index|
      create_access_log!(
        action_type: :view,
        target_type: "zip",
        target_name: "entry-#{index}",
        accessed_at: base_time + index.seconds
      )
    end

    sign_in_as(admin_user)

    get admin_access_logs_path(format: :csv, target_type: "zip")

    expect(response).to have_http_status(:ok)
    expect(csv_rows.size).to eq(200)
    expect(csv_rows.first["対象名"]).to eq("entry-200")
    expect(csv_rows[-1]["対象名"]).to eq("entry-1")
    expect(csv_rows.map { _1["対象名"] }).not_to include("entry-0")
  end

  it "forbids CSV export for users outside the internal admin boundary" do
    sign_in_as(external_user)

    get admin_access_logs_path(format: :csv)

    expect(response).to have_http_status(:forbidden)

    sign_in_as(company_master_admin)

    get admin_access_logs_path(format: :csv)

    expect(response).to have_http_status(:forbidden)
  end
end
