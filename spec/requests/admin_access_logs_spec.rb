require "csv"
require "rails_helper"
require "uri"

RSpec.describe "Admin access logs", type: :request do
  let(:admin_company) { create(:company, domain: "audit.example.com", name: "Audit Company") }
  let(:admin_user) { create(:user, :internal, company: admin_company) }
  let(:external_user) { create(:user, :external) }
  let(:project) { create(:project, code: "AUDIT", name: "Audit Project") }
  let(:document) { create(:document, project:, title: "Audit Document", slug: "audit-document") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def heading_texts
    parsed_html.css("h1, h2, h3").map { _1.text.squish }.reject(&:empty?)
  end

  def table_preference_column_keys
    parsed_html.css("[data-rails-table-preferences-column-key]").map do |node|
      node["data-rails-table-preferences-column-key"]
    end
  end

  def log_rows
    parsed_html.css("table tbody tr")
  end

  def log_target_names
    log_rows.filter_map do |row|
      row.at_css("td:nth-child(3) code")&.text&.squish
    end
  end

  def pagination_link(label)
    parsed_html.css("nav.pagination a").find { |link| link.text.squish == label }
  end

  def pagination_query(label)
    link = pagination_link(label)
    return {} unless link

    Rack::Utils.parse_nested_query(URI.parse(link["href"]).query)
  end

  def csv_export_query
    link = parsed_html.css("a[href]").find { |node| node.text.squish.include?("CSV export") }
    return {} unless link

    Rack::Utils.parse_nested_query(URI.parse(link["href"]).query)
  end

  def row_column_texts(column_key)
    log_rows.map do |row|
      cell = row.at_css(%(td[data-rails-table-preferences-column-key="#{column_key}"]))
      next unless cell

      cell.xpath(".//text()").filter_map do |node|
        text = node.text.squish
        text.presence
      end.join(" ")
    end
  end

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

  it "shows access logs to internal admins" do
    create_access_log!(action_type: :download, target_type: "zip", target_name: "audit.zip")

    sign_in_as(admin_user)

    get admin_access_logs_path

    expect(response).to have_http_status(:ok)
    expect(heading_texts).to include("監査ログ")
    expect(page_text).to include("Audit Project")
    expect(page_text).to include("Audit Document")
    expect(page_text).to include("表示中: 1件 / 最新200件までを表示")
    expect(page_text).to include("監査ログ一覧の表示設定")
    expect(log_target_names).to eq(["audit.zip"])
    expect(row_column_texts("company")).to eq(["Audit Company audit.example.com"])
    expect(row_column_texts("project")).to eq(["Audit Project AUDIT"])
  end

  it "shows an empty state when no access logs exist yet" do
    sign_in_as(admin_user)

    get admin_access_logs_path

    expect(response).to have_http_status(:ok)
    expect(heading_texts).to include("監査ログ")
    expect(page_text).to include("まだ監査ログはありません。")
    expect(page_text).to include("操作が記録されると、最新200件をここで確認できます。")
    expect(page_text).not_to include("監査ログ一覧の表示設定")
    expect(table_preference_column_keys).to be_empty
  end

  it "shows a filtered empty state when no access logs match the current filters" do
    sign_in_as(admin_user)

    get admin_access_logs_path, params: { document_q: "does-not-match" }

    expect(response).to have_http_status(:ok)
    expect(heading_texts).to include("監査ログ")
    expect(page_text).to include("条件に一致する監査ログはありません。")
    expect(page_text).to include("絞り込み条件を見直すか、「条件をクリア」で最新200件を確認してください。")
    expect(page_text).not_to include("監査ログ一覧の表示設定")
    expect(table_preference_column_keys).to be_empty
  end

  it "filters access logs by action type and target type" do
    create_access_log!(action_type: :download, target_type: "zip", target_name: "audit.zip")
    create_access_log!(action_type: :view, target_type: "page", target_name: "index.html")

    sign_in_as(admin_user)

    get admin_access_logs_path(action_type: "download", target_type: "zip")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["audit.zip"])
  end

  it "ignores unknown target type filters" do
    base_time = Time.zone.parse("2026-05-01 00:00:00 UTC")
    create_access_log!(action_type: :download, target_type: "zip", target_name: "audit.zip", accessed_at: base_time)
    create_access_log!(action_type: :view, target_type: "page", target_name: "index.html", accessed_at: base_time + 1.second)

    sign_in_as(admin_user)

    get admin_access_logs_path(target_type: "unknown")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["index.html", "audit.zip"])
    expect(parsed_html.at_css('select[name="target_type"] option[value="unknown"][selected]')).to be_nil
    expect(page_text).to include("表示中: 2件 / 最新200件までを表示")
    expect(page_text).not_to include("絞り込み中")
  end

  it "shows and filters AI context export access logs by target type" do
    create_access_log!(action_type: :download, target_type: "ai_context", target_name: "mode=full")
    create_access_log!(action_type: :view, target_type: "page", target_name: "project page")

    sign_in_as(admin_user)

    get admin_access_logs_path(target_type: "ai_context")

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css('select[name="target_type"] option[value="ai_context"][selected]').text).to eq("AI context export")
    expect(page_text).to include("AI context export")
    expect(log_target_names).to eq(["mode=full"])
  end

  it "filters AI context export access logs by mode" do
    create_access_log!(
      action_type: :download,
      target_type: "ai_context",
      target_name: "mode=compact;scope=selected;selected_count=2;exported_count=2"
    )
    create_access_log!(
      action_type: :download,
      target_type: "ai_context",
      target_name: "mode=full;scope=selected;selected_count=2;exported_count=2"
    )
    create_access_log!(
      action_type: :download,
      target_type: "page",
      target_name: "mode=compact;scope=selected;selected_count=2;exported_count=2"
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(target_type: "ai_context", ai_context_mode: "compact")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["mode=compact;scope=selected;selected_count=2;exported_count=2"])
    selected_option = parsed_html.at_css('select[name="ai_context_mode"] option[value="compact"][selected]')
    expect(selected_option.text).to eq("コンパクト")
    expect(selected_option["value"]).to eq("compact")
    expect(page_text).to include("AI出力モード: コンパクト")
    expect(page_text).not_to include("AI出力モード: compact")
  end

  it "filters AI context export access logs by scope with existing filters" do
    create_access_log!(
      action_type: :download,
      target_type: "ai_context",
      target_name: "mode=full;scope=selected;selected_count=2;exported_count=2"
    )
    create_access_log!(
      action_type: :view,
      target_type: "ai_context",
      target_name: "mode=compact;scope=selected;selected_count=1;exported_count=1"
    )
    create_access_log!(
      action_type: :download,
      target_type: "ai_context",
      target_name: "mode=full;scope=all;selected_count=0;exported_count=9"
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(target_type: "ai_context", ai_context_scope: "selected", action_type: "download")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["mode=full;scope=selected;selected_count=2;exported_count=2"])
    expect(parsed_html.at_css('select[name="ai_context_scope"] option[value="selected"][selected]').text).to eq("選択")
    expect(page_text).to include("AI出力範囲: 選択")
  end

  it "ignores invalid AI context mode and scope filters" do
    create_access_log!(
      action_type: :download,
      target_type: "ai_context",
      target_name: "mode=compact;scope=selected;selected_count=2;exported_count=2"
    )
    create_access_log!(
      action_type: :download,
      target_type: "ai_context",
      target_name: "mode=full;scope=all;selected_count=0;exported_count=9"
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(target_type: "ai_context", ai_context_mode: "expanded", ai_context_scope: "partial")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to contain_exactly(
      "mode=compact;scope=selected;selected_count=2;exported_count=2",
      "mode=full;scope=all;selected_count=0;exported_count=9"
    )
    expect(parsed_html.at_css('select[name="ai_context_mode"] option[value="expanded"][selected]')).to be_nil
    expect(parsed_html.at_css('select[name="ai_context_scope"] option[value="partial"][selected]')).to be_nil
    expect(page_text).not_to include("AI context mode:")
    expect(page_text).not_to include("AI context scope:")
    expect(page_text).not_to include("AI出力モード:")
    expect(page_text).not_to include("AI出力範囲:")
  end

  it "does not apply AI context filters to other target types" do
    create_access_log!(
      action_type: :download,
      target_type: "zip",
      target_name: "mode=compact;scope=selected;selected_count=2;exported_count=2"
    )
    create_access_log!(
      action_type: :download,
      target_type: "ai_context",
      target_name: "mode=compact;scope=selected;selected_count=2;exported_count=2"
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(target_type: "zip", ai_context_mode: "compact", ai_context_scope: "selected")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["mode=compact;scope=selected;selected_count=2;exported_count=2"])
    expect(parsed_html.at_css('select[name="ai_context_mode"] option[value="compact"][selected]')).to be_nil
    expect(parsed_html.at_css('select[name="ai_context_scope"] option[value="selected"][selected]')).to be_nil
    expect(page_text).not_to include("AI context mode:")
    expect(page_text).not_to include("AI context scope:")
    expect(page_text).not_to include("AI出力モード:")
    expect(page_text).not_to include("AI出力範囲:")
  end
end
