require "rails_helper"
require "uri"

RSpec.describe "Admin access log target search", type: :request do
  let(:admin_company) { create(:company, domain: "audit.example.com", name: "Audit Company") }
  let(:admin_user) { create(:user, :internal, company: admin_company) }
  let(:project) { create(:project, code: "AUDIT", name: "Audit Project") }
  let(:document) { create(:document, project:, title: "Audit Document", slug: "audit-document") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def log_rows
    parsed_html.css("table tbody tr")
  end

  def log_target_names
    log_rows.filter_map do |row|
      row.at_css("td:nth-child(3) code")&.text&.squish
    end
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

  def pagination_query(label)
    link = parsed_html.css("nav.pagination a").find { _1.text.squish == label }
    return {} unless link

    Rack::Utils.parse_nested_query(URI.parse(link["href"]).query)
  end

  def create_access_log!(action_type:, target_type:, target_name:, user: admin_user, company: admin_user.company, project: self.project, document: self.document, document_version: version, ip_address: "127.0.0.1", accessed_at: Time.current)
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

  it "filters access logs by target_name and ip_address fragments" do
    create_access_log!(action_type: :download, target_type: "zip", target_name: "client-contract.zip", ip_address: "172.16.0.10")
    create_access_log!(action_type: :view, target_type: "file", target_name: "onboarding-guide.pdf", ip_address: "10.20.30.40")
    create_access_log!(action_type: :download, target_type: "page", target_name: "unrelated.html", ip_address: "192.0.2.8")

    sign_in_as(admin_user)

    get admin_access_logs_path(q: "contract")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["client-contract.zip"])
    expect(page_text).to include("対象名・IPアドレス: contract")
    expect(parsed_html.at_css('input[name="q"]')["value"]).to eq("contract")

    get admin_access_logs_path(q: "10.20.30")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["onboarding-guide.pdf"])
    expect(row_column_texts("ip_address")).to eq(["10.20.30.40"])
  end

  it "finds AI context raw target_name snippets without changing structured filters" do
    create_access_log!(
      action_type: :download,
      target_type: "ai_context",
      target_name: "mode=full;scope=selected;selected_count=3;exported_count=2"
    )
    create_access_log!(
      action_type: :download,
      target_type: "ai_context",
      target_name: "mode=compact;scope=all;selected_count=0;exported_count=9"
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(target_type: "ai_context", q: "scope=selected")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("AI context export")
    expect(page_text).to include("AI出力範囲: 選択")
    expect(page_text).to include("対象名・IPアドレス: scope=selected")
    expect(page_text).not_to include("AI出力範囲: 全件")
  end

  it "combines q with document_q and existing filters as AND conditions" do
    matching_document = create(:document, project:, title: "Audit Handbook", slug: "audit-handbook")
    matching_version = create(:document_version, document: matching_document, version_label: "v2.0.0")
    other_document = create(:document, project:, title: "Other Handbook", slug: "other-handbook")
    other_version = create(:document_version, document: other_document, version_label: "v3.0.0")

    create_access_log!(
      action_type: :download,
      target_type: "zip",
      target_name: "audit-bundle.zip",
      document: matching_document,
      document_version: matching_version
    )
    create_access_log!(
      action_type: :download,
      target_type: "zip",
      target_name: "audit-bundle.zip",
      document: other_document,
      document_version: other_version
    )
    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "audit-handbook.html",
      document: matching_document,
      document_version: matching_version
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(action_type: "download", document_q: "Audit Handbook", q: "bundle")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["audit-bundle.zip"])
    expect(row_column_texts("document")).to eq(["Audit Handbook"])
    expect(page_text).to include("操作: ダウンロード")
    expect(page_text).to include("対象名・IPアドレス: bundle")
    expect(page_text).to include("文書名・URL識別子: Audit Handbook")
  end

  it "escapes LIKE wildcards in q so the search does not broaden unexpectedly" do
    create_access_log!(action_type: :download, target_type: "zip", target_name: "literal%_needle.zip")
    create_access_log!(action_type: :download, target_type: "zip", target_name: "literalXXneedle.zip")

    sign_in_as(admin_user)

    get admin_access_logs_path(q: "literal%_needle")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["literal%_needle.zip"])
    expect(page_text).to include("対象名・IPアドレス: literal%_needle")
  end

  it "shows q in the filtered empty state" do
    create_access_log!(action_type: :download, target_type: "zip", target_name: "audit.zip")

    sign_in_as(admin_user)

    get admin_access_logs_path(q: "missing-target")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致する監査ログはありません。")
    expect(page_text).to include("対象名・IPアドレス: missing-target")
  end

  it "keeps q in pagination links" do
    base_time = Time.zone.parse("2026-05-01 00:00:00 UTC")

    201.times do |index|
      create_access_log!(
        action_type: :view,
        target_type: "page",
        target_name: "archive-match-#{index}",
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

    get admin_access_logs_path(q: "archive-match")

    expect(response).to have_http_status(:ok)
    expect(log_target_names.size).to eq(200)
    expect(log_target_names.first).to eq("archive-match-200")
    expect(log_target_names.last).to eq("archive-match-1")
    expect(log_target_names).not_to include("archive-match-0", "outside-filter.html")
    expect(pagination_query("次の200件")).to include(
      "q" => "archive-match",
      "page" => "2"
    )
  end
end
