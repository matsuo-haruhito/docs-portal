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

  it "filters access logs by project, company, and user" do
    matching_project = create(:project, code: "FILTER", name: "Filter Project")
    matching_company = create(:company, domain: "filter.example.com", name: "Filter Co")
    matching_user = create(:user, :internal, company: matching_company, email_address: "filter-user@example.com")
    other_project = create(:project, code: "OTHER", name: "Other Project")
    other_company = create(:company, domain: "other.example.com", name: "Other Co")
    other_company_user = create(:user, :internal, company: other_company, email_address: "other-company-user@example.com")
    other_user = create(:user, :internal, company: matching_company, email_address: "other-user@example.com")
    matching_document = create(:document, project: matching_project, title: "Filter Document", slug: "filter-document")
    matching_version = create(:document_version, document: matching_document, version_label: "v2.0.0")
    other_document = create(:document, project: other_project, title: "Other Document", slug: "other-document")
    other_version = create(:document_version, document: other_document, version_label: "v3.0.0")

    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "matching.html",
      user: matching_user,
      company: matching_company,
      project: matching_project,
      document: matching_document,
      document_version: matching_version
    )
    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "other-project.html",
      user: matching_user,
      company: matching_company,
      project: other_project,
      document: other_document,
      document_version: other_version
    )
    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "other-company.html",
      user: other_company_user,
      company: other_company,
      project: matching_project,
      document: matching_document,
      document_version: matching_version
    )
    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "other-user.html",
      user: other_user,
      company: matching_company,
      project: matching_project,
      document: matching_document,
      document_version: matching_version
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(
      project_id: matching_project.id,
      company_id: matching_company.id,
      user_id: matching_user.id
    )

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["matching.html"])
    expect(row_column_texts("company")).to eq(["Filter Co filter.example.com"])
    expect(row_column_texts("project")).to eq(["Filter Project FILTER"])
  end

  it "filters access logs by accessed date range with existing filters" do
    matching_project = create(:project, code: "RANGE", name: "Range Project")
    other_project = create(:project, code: "OTHER", name: "Other Project")
    matching_document = create(:document, project: matching_project, title: "Range Document", slug: "range-document")
    matching_version = create(:document_version, document: matching_document, version_label: "v2.0.0")
    other_document = create(:document, project: other_project, title: "Other Document", slug: "other-document")
    other_version = create(:document_version, document: other_document, version_label: "v3.0.0")

    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "before-range.html",
      project: matching_project,
      document: matching_document,
      document_version: matching_version,
      accessed_at: Time.zone.parse("2026-05-09 00:00:00 UTC")
    )
    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "range-match.html",
      project: matching_project,
      document: matching_document,
      document_version: matching_version,
      accessed_at: Time.zone.parse("2026-05-11 10:00:00 UTC")
    )
    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "range-other-project.html",
      project: other_project,
      document: other_document,
      document_version: other_version,
      accessed_at: Time.zone.parse("2026-05-11 12:00:00 UTC")
    )
    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "after-range.html",
      project: matching_project,
      document: matching_document,
      document_version: matching_version,
      accessed_at: Time.zone.parse("2026-05-13 00:00:00 UTC")
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(project_id: matching_project.id, from: "2026-05-10", to: "2026-05-12")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["range-match.html"])
    expect(page_text).to include("表示中: 1件 / 最新200件までを表示 / 絞り込み中")
    expect(page_text).to include("期間指定後も、条件に一致する監査ログを新しい順に最新200件まで表示します。")
  end

  it "ignores invalid accessed date filters without failing" do
    create_access_log!(action_type: :download, target_type: "zip", target_name: "audit.zip")

    sign_in_as(admin_user)

    get admin_access_logs_path(from: "not-a-date", to: "2026-99-99")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["audit.zip"])
    expect(page_text).to include("表示中: 1件 / 最新200件までを表示 / 絞り込み中")
  end

  it "renders only non-duplicated secondary identifiers in company and project rows" do
    domain_only_company = create(:company, name: nil, domain: "domain-only.example.com")
    plain_project = create(:project, code: "PLAIN", name: "Plain Project")
    plain_document = create(:document, project: plain_project, title: "Plain Document", slug: "plain-document")
    plain_version = create(:document_version, document: plain_document, version_label: "v2.1.0")

    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "plain.html",
      user: admin_user,
      company: domain_only_company,
      project: plain_project,
      document: plain_document,
      document_version: plain_version,
      accessed_at: Time.current + 1.second
    )
    create_access_log!(action_type: :download, target_type: "zip", target_name: "audit.zip")

    sign_in_as(admin_user)

    get admin_access_logs_path

    expect(response).to have_http_status(:ok)
    expect(row_column_texts("company")).to eq([
      "domain-only.example.com",
      "Audit Company audit.example.com"
    ])
    expect(row_column_texts("project")).to eq([
      "Plain Project PLAIN",
      "Audit Project AUDIT"
    ])
  end

  it "normalizes target and IP query filters before filtering and building links" do
    normalized_query = "x" * Admin::AccessLogsController::ACCESS_LOG_QUERY_MAX_LENGTH
    long_query = "  #{normalized_query}ignored-suffix  "
    base_time = Time.zone.parse("2026-05-01 00:00:00 UTC")

    201.times do |index|
      create_access_log!(
        action_type: :view,
        target_type: "page",
        target_name: "target-#{index}-#{normalized_query}",
        accessed_at: base_time + index.seconds
      )
    end
    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "ip-only-match",
      ip_address: "source-#{normalized_query}",
      accessed_at: base_time + 202.seconds
    )
    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "outside-query",
      accessed_at: base_time + 203.seconds
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(q: long_query)

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css(%(input[name="q"]))["value"]).to eq(normalized_query)
    expect(log_target_names).to include("ip-only-match")
    expect(log_target_names).not_to include("outside-query")
    expect(page_text).to include("対象名・IPアドレス: #{normalized_query}")
    expect(page_text).not_to include("ignored-suffix")
    expect(pagination_query("次の200件")).to include("q" => normalized_query, "page" => "2")
    expect(csv_export_query).to include("q" => normalized_query)
  end

  it "normalizes document query filters before filtering and building links" do
    normalized_query = "audit" * 20
    long_query = "  #{normalized_query}ignored-suffix  "
    base_time = Time.zone.parse("2026-05-01 00:00:00 UTC")
    title_match_document = create(:document, project:, title: "Quarterly #{normalized_query}", slug: "quarterly-audit")
    slug_match_document = create(:document, project:, title: "Operations Note", slug: "#{normalized_query}-slug")
    other_document = create(:document, project:, title: "Quarterly #{normalized_query[0, 99]}z", slug: "outside-document")

    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "title-document-match",
      document: title_match_document,
      document_version: create(:document_version, document: title_match_document, version_label: "v2.0.0"),
      accessed_at: base_time + 3.seconds
    )
    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "slug-document-match",
      document: slug_match_document,
      document_version: create(:document_version, document: slug_match_document, version_label: "v3.0.0"),
      accessed_at: base_time + 2.seconds
    )
    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "document-miss",
      document: other_document,
      document_version: create(:document_version, document: other_document, version_label: "v4.0.0"),
      accessed_at: base_time + 1.second
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(document_q: long_query)

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css(%(input[name="document_q"]))["value"]).to eq(normalized_query)
    expect(log_target_names).to eq(["title-document-match", "slug-document-match"])
    expect(page_text).to include("文書名・URL識別子: #{normalized_query}")
    expect(page_text).not_to include("ignored-suffix")
    expect(csv_export_query).to include("document_q" => normalized_query)
  end

  it "drops blank search query filters before applying active filter summaries" do
    create_access_log!(action_type: :view, target_type: "page", target_name: "blank-query-target")

    sign_in_as(admin_user)

    get admin_access_logs_path(q: "   ", document_q: "   ")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["blank-query-target"])
    expect(parsed_html.at_css(%(input[name="q"]))["value"]).to be_nil
    expect(parsed_html.at_css(%(input[name="document_q"]))["value"]).to be_nil
    expect(page_text).not_to include("絞り込み中")
    expect(page_text).not_to include("有効な条件:")
  end

  it "filters access logs by document title" do
    title_match_document = create(:document, project:, title: "Quarterly Audit Summary", slug: "q1-summary")
    title_match_version = create(:document_version, document: title_match_document, version_label: "v2.0.0")
    other_document = create(:document, project:, title: "Operations Note", slug: "ops-note")
    other_version = create(:document_version, document: other_document, version_label: "v3.0.0")

    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "title-match.html",
      document: title_match_document,
      document_version: title_match_version
    )
    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "title-miss.html",
      document: other_document,
      document_version: other_version
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(document_q: "Quarterly Audit")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["title-match.html"])
  end

  it "filters access logs by document slug" do
    slug_match_document = create(:document, project:, title: "Operations Note", slug: "security-audit-log")
    slug_match_version = create(:document_version, document: slug_match_document, version_label: "v4.0.0")
    other_document = create(:document, project:, title: "Security Audit Log", slug: "different-slug")
    other_version = create(:document_version, document: other_document, version_label: "v5.0.0")

    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "slug-match.html",
      document: slug_match_document,
      document_version: slug_match_version
    )
    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "slug-miss.html",
      document: other_document,
      document_version: other_version
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(document_q: "security-audit")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["slug-match.html"])
  end

  it "shows only the latest 200 access logs in recent order" do
    base_time = Time.zone.parse("2026-05-01 00:00:00 UTC")

    205.times do |index|
      create_access_log!(
        action_type: :view,
        target_type: "page",
        target_name: "entry-#{index}",
        accessed_at: base_time + index.seconds
      )
    end

    sign_in_as(admin_user)

    get admin_access_logs_path

    expect(response).to have_http_status(:ok)
    expect(log_target_names.size).to eq(200)
    expect(log_target_names.first).to eq("entry-204")
    expect(log_target_names.last).to eq("entry-5")
    expect(log_target_names).not_to include("entry-4", "entry-3", "entry-2", "entry-1", "entry-0")
    expect(pagination_link("前の200件")).to be_nil
    expect(pagination_query("次の200件")).to include("page" => "2")
  end

  it "shows older access logs on the second page" do
    base_time = Time.zone.parse("2026-05-01 00:00:00 UTC")

    205.times do |index|
      create_access_log!(
        action_type: :view,
        target_type: "page",
        target_name: "entry-#{index}",
        accessed_at: base_time + index.seconds
      )
    end

    sign_in_as(admin_user)

    get admin_access_logs_path(page: 2)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 5件 / 最新200件までを表示 / 2ページ目")
    expect(log_target_names).to eq(["entry-4", "entry-3", "entry-2", "entry-1", "entry-0"])
    expect(pagination_query("前の200件")).to include("page" => "1")
    expect(pagination_link("次の200件")).to be_nil
  end

  it "keeps active filters in pagination links" do
    base_time = Time.zone.parse("2026-05-01 00:00:00 UTC")
    pagination_project = create(:project, code: "PAGE", name: "Pagination Project")
    pagination_document = create(:document, project: pagination_project, title: "Pagination Evidence", slug: "pagination-evidence")
    pagination_version = create(:document_version, document: pagination_document, version_label: "v1.0.1")

    201.times do |index|
      create_access_log!(
        action_type: :view,
        target_type: "page",
        target_name: "filtered-entry-#{index}",
        project: pagination_project,
        document: pagination_document,
        document_version: pagination_version,
        accessed_at: base_time + index.minutes
      )
    end
    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "outside-filter.html",
      accessed_at: base_time + 1.day
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(
      project_id: pagination_project.id,
      document_q: "Pagination Evidence",
      from: "2026-05-01",
      to: "2026-05-02"
    )

    expect(response).to have_http_status(:ok)
    expect(log_target_names.size).to eq(200)
    expect(log_target_names.first).to eq("filtered-entry-200")
    expect(log_target_names.last).to eq("filtered-entry-1")
    expect(log_target_names).not_to include("filtered-entry-0", "outside-filter.html")
    expect(pagination_query("次の200件")).to include(
      "project_id" => pagination_project.id.to_s,
      "document_q" => "Pagination Evidence",
      "from" => "2026-05-01",
      "to" => "2026-05-02",
      "page" => "2"
    )
  end

  it "exports the latest 200 CSV rows using active filters independently from the current page" do
    base_time = Time.zone.parse("2026-05-01 00:00:00 UTC")
    csv_project = create(:project, code: "CSV", name: "CSV Project")
    csv_document = create(:document, project: csv_project, title: "CSV Evidence", slug: "csv-evidence")
    csv_version = create(:document_version, document: csv_document, version_label: "v1.0.2")

    201.times do |index|
      create_access_log!(
        action_type: :view,
        target_type: "page",
        target_name: "csv-entry-#{index}",
        project: csv_project,
        document: csv_document,
        document_version: csv_version,
        accessed_at: base_time + index.minutes
      )
    end
    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "csv-outside-filter.html",
      accessed_at: base_time + 1.day
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(format: :csv, project_id: csv_project.id, document_q: "CSV Evidence", page: 2)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(response.headers["Content-Disposition"]).to include("access-logs-#{Date.current.iso8601}.csv")

    rows = CSV.parse(response.body, headers: true)
    target_names = rows.map { _1["対象名"] }

    expect(rows.headers).to eq(Admin::AccessLogsController::CSV_HEADERS)
    expect(rows.size).to eq(200)
    expect(target_names.first).to eq("csv-entry-200")
    expect(target_names.last).to eq("csv-entry-1")
    expect(target_names).not_to include("csv-entry-0", "csv-outside-filter.html")
    expect(rows.map { _1["案件コード"] }.uniq).to eq(["CSV"])
    expect(rows.map { _1["文書名"] }.uniq).to eq(["CSV Evidence"])
  end

  it "exports representative CSV filters with blank AI context columns for malformed target names" do
    base_time = Time.zone.parse("2026-05-10 12:00:00 UTC")
    csv_company = create(:company, domain: "csv-filter.example.com", name: "CSV Filter Co")
    csv_user = create(:user, :internal, company: csv_company, email_address: "csv-filter-user@example.com")

    create_access_log!(
      action_type: :download,
      target_type: "ai_context",
      target_name: "broken-ai-context-target",
      company: csv_company,
      user: csv_user,
      accessed_at: base_time,
      ip_address: "203.0.113.10"
    )
    create_access_log!(
      action_type: :view,
      target_type: "ai_context",
      target_name: "broken-ai-context-action-miss",
      company: csv_company,
      user: csv_user,
      accessed_at: base_time
    )
    create_access_log!(
      action_type: :download,
      target_type: "page",
      target_name: "broken-ai-context-target-type-miss",
      company: csv_company,
      user: csv_user,
      accessed_at: base_time
    )
    create_access_log!(
      action_type: :download,
      target_type: "ai_context",
      target_name: "outside-filter-target",
      company: csv_company,
      user: csv_user,
      accessed_at: base_time
    )
    create_access_log!(
      action_type: :download,
      target_type: "ai_context",
      target_name: "broken-ai-context-date-miss",
      company: csv_company,
      user: csv_user,
      accessed_at: base_time - 2.days
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(
      format: :csv,
      action_type: "download",
      target_type: "ai_context",
      company_id: csv_company.id,
      user_id: csv_user.id,
      q: "broken-ai-context",
      from: "2026-05-10",
      to: "2026-05-10"
    )

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")

    rows = CSV.parse(response.body, headers: true)

    expect(rows.size).to eq(1)
    row = rows.first
    expect(row["操作"]).to eq("download")
    expect(row["対象種別"]).to eq("ai_context")
    expect(row["対象名"]).to eq("broken-ai-context-target")
    expect(row["ユーザーEmail"]).to eq("csv-filter-user@example.com")
    expect(row["会社"]).to eq("CSV Filter Co")
    expect(row["IPアドレス"]).to eq("203.0.113.10")
    expect(row.values_at(
      "AI context mode",
      "AI context scope",
      "AI context selected_count",
      "AI context exported_count"
    )).to all(be_blank)
  end

  it "exports access log metadata JSON without row data using active filters" do
    metadata_project = create(:project, code: "META", name: "Metadata Project")
    metadata_company = create(:company, domain: "metadata.example.com", name: "Metadata Co")
    metadata_user = create(:user, :internal, company: metadata_company, email_address: "metadata-user@example.com")
    metadata_document = create(:document, project: metadata_project, title: "Metadata Document", slug: "metadata-document")
    metadata_version = create(:document_version, document: metadata_document, version_label: "v5.0.0")

    create_access_log!(
      action_type: :download,
      target_type: "ai_context",
      target_name: "mode=compact;scope=selected;selected_count=2;exported_count=2;metadata-target",
      user: metadata_user,
      company: metadata_company,
      project: metadata_project,
      document: metadata_document,
      document_version: metadata_version,
      accessed_at: Time.zone.parse("2026-05-10 12:00:00 UTC")
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(
      format: :json,
      action_type: "download",
      target_type: "ai_context",
      project_id: metadata_project.id,
      company_id: metadata_company.id,
      user_id: metadata_user.id,
      q: "metadata-target",
      document_q: "Metadata Document",
      from: "2026-05-10",
      to: "2026-05-10",
      ai_context_mode: "compact",
      ai_context_scope: "selected",
      page: 2
    )

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")

    metadata = JSON.parse(response.body)
    filters = metadata.fetch("filters")

    expect(metadata.keys).to contain_exactly(
      "exported_at",
      "report_type",
      "row_limit",
      "export_scope",
      "description",
      "filters",
      "ignored_filters",
      "summary"
    )
    expect(metadata).not_to include("rows", "access_logs", "csv")
    expect(metadata).to include(
      "report_type" => "access_logs",
      "row_limit" => Admin::AccessLogsController::ACCESS_LOGS_PER_PAGE,
      "export_scope" => "current_filter_latest_rows",
      "ignored_filters" => []
    )
    expect(metadata.fetch("description")).to include("表示中ページではなく")
    expect(metadata.fetch("summary")).to include("条件:")

    expect(filters).to include(
      "action_type" => "download",
      "target_type" => "ai_context",
      "project_id" => metadata_project.id.to_s,
      "company_id" => metadata_company.id.to_s,
      "user_id" => metadata_user.id.to_s,
      "q" => "metadata-target",
      "document_q" => "Metadata Document",
      "from" => "2026-05-10",
      "to" => "2026-05-10",
      "ai_context_mode" => "compact",
      "ai_context_scope" => "selected"
    )
    expect(filters.fetch("project")).to include("code" => "META", "name" => "Metadata Project")
    expect(filters.fetch("company")).to include("name" => "Metadata Co", "domain" => "metadata.example.com")
    expect(filters.fetch("user")).to include("email" => "metadata-user@example.com")
  end

  it "exports metadata JSON with ignored dates and drops AI filters for non-AI targets" do
    create_access_log!(action_type: :download, target_type: "zip", target_name: "metadata.zip")

    sign_in_as(admin_user)

    get admin_access_logs_path(
      format: :json,
      action_type: "download",
      target_type: "zip",
      from: "not-a-date",
      to: "2026-99-99",
      ai_context_mode: "compact",
      ai_context_scope: "selected"
    )

    expect(response).to have_http_status(:ok)

    metadata = JSON.parse(response.body)
    filters = metadata.fetch("filters")

    expect(metadata.fetch("ignored_filters")).to contain_exactly("from", "to")
    expect(metadata.fetch("summary")).to include("無効な日付条件を除外: from, to")
    expect(filters).to include("action_type" => "download", "target_type" => "zip")
    expect(filters).not_to include("from", "to", "ai_context_mode", "ai_context_scope")
    expect(metadata).not_to include("rows", "access_logs", "csv")
  end

  it "falls back to the first page for invalid page parameters" do
    base_time = Time.zone.parse("2026-05-01 00:00:00 UTC")
    create_access_log!(action_type: :view, target_type: "page", target_name: "entry-old", accessed_at: base_time)
    create_access_log!(action_type: :view, target_type: "page", target_name: "entry-new", accessed_at: base_time + 1.second)

    sign_in_as(admin_user)

    ["0", "51", "not-a-number"].each do |page|
      get admin_access_logs_path(page:)

      expect(response).to have_http_status(:ok)
      expect(page_text).to include("表示中: 2件 / 最新200件までを表示")
      expect(log_target_names).to eq(["entry-new", "entry-old"])
      expect(page_text).not_to include("2ページ目")
    end
  end

  it "forbids external users" do
    sign_in_as(external_user)

    get admin_access_logs_path

    expect(response).to have_http_status(:forbidden)
  end
end
