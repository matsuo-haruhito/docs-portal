require "csv"
require "rails_helper"

RSpec.describe "Admin access log AI context target fallback", type: :request do
  let(:admin_company) { create(:company, domain: "ai-audit.example.com", name: "AI Audit Company") }
  let(:admin_user) { create(:user, :internal, company: admin_company) }
  let(:project) { create(:project, code: "AICTX", name: "AI Context Project") }
  let(:document) { create(:document, project:, title: "AI Context Document", slug: "ai-context-document") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def target_cell_texts
    parsed_html.css('td[data-rails-table-preferences-column-key="target"]').map do |cell|
      cell.text.squish
    end
  end

  def create_access_log!(target_type:, target_name:, accessed_at:, action_type: :download)
    AccessLog.create!(
      user: admin_user,
      company: admin_company,
      project:,
      document:,
      document_version: version,
      action_type:,
      target_type:,
      target_name:,
      ip_address: "127.0.0.1",
      user_agent: "RSpec",
      accessed_at:
    )
  end

  it "shows parsed badges for valid AI context targets and preview-only fallback for malformed targets" do
    valid_target = "mode=compact;scope=selected;selected_count=2;exported_count=2"
    malformed_target = "mode=compact;scope=selected;selected_count=two;exported_count=2"
    non_ai_target = "mode=compact;scope=selected;selected_count=9;exported_count=9"
    create_access_log!(
      target_type: "ai_context",
      target_name: valid_target,
      accessed_at: Time.zone.parse("2026-06-01 10:02:00 UTC")
    )
    create_access_log!(
      target_type: "ai_context",
      target_name: malformed_target,
      accessed_at: Time.zone.parse("2026-06-01 10:01:00 UTC")
    )
    create_access_log!(
      target_type: "zip",
      target_name: non_ai_target,
      accessed_at: Time.zone.parse("2026-06-01 10:00:00 UTC")
    )

    sign_in_as(admin_user)

    get admin_access_logs_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("AI出力モード: コンパクト")
    expect(page_text).to include("AI出力範囲: 選択")
    expect(page_text).to include("選択数: 2件")
    expect(page_text).to include("出力数: 2件")
    expect(page_text).to include("監査用 target_name preview")
    expect(page_text).to include(valid_target, malformed_target, non_ai_target)

    malformed_cell = target_cell_texts.find { _1.include?(malformed_target) }
    expect(malformed_cell).to include("AI context export")
    expect(malformed_cell).not_to include("選択数:", "出力数:")

    non_ai_cell = target_cell_texts.find { _1.include?(non_ai_target) }
    expect(non_ai_cell).not_to include("AI context export", "監査用 target_name preview", "選択数:", "出力数:")
  end

  it "exports AI context CSV columns only for parseable AI context targets" do
    valid_target = "mode=full;scope=all;selected_count=0;exported_count=8"
    malformed_target = "mode=full;scope=all;selected_count=none;exported_count=8"
    non_ai_target = "non-ai page target"
    create_access_log!(
      target_type: "ai_context",
      target_name: valid_target,
      accessed_at: Time.zone.parse("2026-06-01 10:02:00 UTC")
    )
    create_access_log!(
      target_type: "ai_context",
      target_name: malformed_target,
      accessed_at: Time.zone.parse("2026-06-01 10:01:00 UTC")
    )
    create_access_log!(
      target_type: "page",
      target_name: non_ai_target,
      accessed_at: Time.zone.parse("2026-06-01 10:00:00 UTC")
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(format: :csv)

    expect(response).to have_http_status(:ok)
    rows = CSV.parse(response.body, headers: true)
    valid_row = rows.find { _1["対象名"] == valid_target }
    malformed_row = rows.find { _1["対象名"] == malformed_target }
    non_ai_row = rows.find { _1["対象名"] == non_ai_target }

    expect(valid_row["AI context mode"]).to eq("full")
    expect(valid_row["AI context scope"]).to eq("all")
    expect(valid_row["AI context selected_count"]).to eq("0")
    expect(valid_row["AI context exported_count"]).to eq("8")

    ["AI context mode", "AI context scope", "AI context selected_count", "AI context exported_count"].each do |header|
      expect(malformed_row[header]).to eq("")
      expect(non_ai_row[header]).to eq("")
    end
  end
end
