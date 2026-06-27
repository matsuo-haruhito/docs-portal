require "rails_helper"
require "uri"

RSpec.describe "Admin access log export actions", type: :request do
  let(:admin_company) { create(:company, domain: "audit-export.example.com", name: "Audit Export Company") }
  let(:admin_user) { create(:user, :internal, company: admin_company) }
  let(:project) { create(:project, code: "EXPORT", name: "Export Project") }
  let(:document) { create(:document, project:, title: "Export Evidence", slug: "export-evidence") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def export_link(label)
    parsed_html.css("section.card a[href]").find { |node| node.text.squish == label }
  end

  def export_link_query(label)
    link = export_link(label)
    return {} unless link

    Rack::Utils.parse_nested_query(URI.parse(link["href"]).query)
  end

  it "explains CSV and metadata JSON roles while keeping current filter params" do
    base_time = Time.zone.parse("2026-05-10 12:00:00 UTC")

    201.times do |index|
      AccessLog.create!(
        user: admin_user,
        company: admin_company,
        project:,
        document:,
        document_version: version,
        action_type: :download,
        target_type: "zip",
        target_name: "handoff-export-#{index}.zip",
        ip_address: "127.0.0.1",
        user_agent: "RSpec",
        accessed_at: base_time + index.minutes
      )
    end

    sign_in_as(admin_user)

    get admin_access_logs_path(
      action_type: "download",
      target_type: "zip",
      project_id: project.id,
      q: "handoff-export",
      from: "2026-05-10",
      to: "2026-05-10",
      page: 2
    )

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("CSV export")
    expect(page_text).to include("metadata確認")
    expect(page_text).to include("CSV は監査ログ行データを固定列で出力します。条件一致の最新200件と、いま開いている表示中ページを使い分けてください。")
    expect(page_text).to include("CSV export は現在の絞り込み条件に一致する最新200件を、監査用途の固定列で出力します。")
    expect(page_text).to include("metadata JSON は監査ログ行データではなく、条件・scope・page・summary を確認する補助出力です。")
    expect(page_text).to include("ページ移動中でも、CSV export は表示中ページではなく条件一致の最新200件が対象です。")

    csv_link = export_link("現在の条件でCSV export（最新200件）")
    current_page_csv_link = export_link("表示中ページをCSV export（最大200件）")
    metadata_link = export_link("CSV条件metadata JSON")
    current_page_metadata_link = export_link("表示中ページmetadata JSON")
    csv_query = export_link_query("現在の条件でCSV export（最新200件）")
    current_page_csv_query = export_link_query("表示中ページをCSV export（最大200件）")
    metadata_query = export_link_query("CSV条件metadata JSON")
    current_page_metadata_query = export_link_query("表示中ページmetadata JSON")

    expected_filters = {
      "action_type" => "download",
      "target_type" => "zip",
      "project_id" => project.id.to_s,
      "q" => "handoff-export",
      "from" => "2026-05-10",
      "to" => "2026-05-10"
    }

    expect(URI.parse(csv_link["href"]).path).to end_with(".csv")
    expect(URI.parse(current_page_csv_link["href"]).path).to end_with(".csv")
    expect(URI.parse(metadata_link["href"]).path).to end_with(".json")
    expect(URI.parse(current_page_metadata_link["href"]).path).to end_with(".json")
    expect(csv_query).to include(expected_filters)
    expect(metadata_query).to include(expected_filters)
    expect(csv_query).not_to include("page", "csv_scope")
    expect(metadata_query).not_to include("page", "csv_scope")
    expect(current_page_csv_query).to include(
      expected_filters.merge(
        "page" => "2",
        "csv_scope" => Admin::AccessLogsController::CSV_SCOPE_CURRENT_PAGE
      )
    )
    expect(current_page_metadata_query).to include(
      expected_filters.merge(
        "page" => "2",
        "csv_scope" => Admin::AccessLogsController::CSV_SCOPE_CURRENT_PAGE
      )
    )
  end

  it "keeps inactive AI context filters out of CSV and metadata links" do
    AccessLog.create!(
      user: admin_user,
      company: admin_company,
      project:,
      document:,
      document_version: version,
      action_type: :download,
      target_type: "zip",
      target_name: "inactive-ai-filter.zip",
      ip_address: "127.0.0.1",
      user_agent: "RSpec",
      accessed_at: Time.zone.parse("2026-05-10 12:00:00 UTC")
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(
      action_type: "download",
      target_type: "zip",
      ai_context_mode: "compact",
      ai_context_scope: "selected",
      q: "inactive-ai-filter"
    )

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("対象外")
    expect(page_text).to include("AI出力モード・範囲は今回の有効な条件から外れます")

    [
      export_link_query("現在の条件でCSV export（最新200件）"),
      export_link_query("表示中ページをCSV export（最大200件）"),
      export_link_query("CSV条件metadata JSON"),
      export_link_query("表示中ページmetadata JSON")
    ].each do |query|
      expect(query).to include(
        "action_type" => "download",
        "target_type" => "zip",
        "q" => "inactive-ai-filter"
      )
      expect(query).not_to include("ai_context_mode", "ai_context_scope")
    end
  end
end
