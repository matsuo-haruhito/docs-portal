require "rails_helper"
require "uri"

RSpec.describe "Admin access log pagination", type: :request do
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

  def pagination_link(direction)
    phrase = direction == :previous ? "ページ目へ戻る" : "ページ目へ進む"
    parsed_html.css('nav[aria-label="監査ログ一覧"] a').find do |link|
      link["aria-label"].to_s.include?(phrase)
    end
  end

  def pagination_query(direction)
    link = pagination_link(direction)
    return {} unless link

    Rack::Utils.parse_nested_query(URI.parse(link["href"]).query)
  end

  def footer_summary
    parsed_html.at_css(".list-footer__summary")&.text&.squish
  end

  def create_access_log!(target_name:, action_type: :view, target_type: "page", accessed_at: Time.current)
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

  it "paginates access logs after the first 50 rows with stable recent ordering" do
    base_time = Time.zone.parse("2026-05-01 00:00:00 UTC")

    205.times do |index|
      create_access_log!(target_name: "entry-#{index}", accessed_at: base_time + index.seconds)
    end

    sign_in_as(admin_user)

    get admin_access_logs_path

    expect(response).to have_http_status(:ok)
    expect(log_target_names.size).to eq(50)
    expect(log_target_names.first).to eq("entry-204")
    expect(log_target_names.last).to eq("entry-155")
    expect(footer_summary).to eq("1–50 / 205件")
    expect(pagination_query(:next)).to include("page" => "2")
    expect(pagination_link(:previous)).to be_nil
    expect(parsed_html.at_css('.table-scroll[role="region"][tabindex="0"][aria-label="監査ログ一覧"]')).to be_present
    expect(parsed_html.at_css("table caption").text.squish).to eq("監査ログ一覧")

    get admin_access_logs_path(page: 2)

    expect(response).to have_http_status(:ok)
    expect(log_target_names.size).to eq(50)
    expect(log_target_names.first).to eq("entry-154")
    expect(log_target_names.last).to eq("entry-105")
    expect(footer_summary).to eq("51–100 / 205件")
    expect(pagination_query(:previous)).to include("page" => "1")
    expect(pagination_query(:next)).to include("page" => "3")
  end

  it "keeps filters on pagination links and does not mix other matching pages" do
    base_time = Time.zone.parse("2026-05-01 00:00:00 UTC")

    202.times do |index|
      create_access_log!(
        target_name: "ai-entry-#{index}",
        target_type: "ai_context",
        accessed_at: base_time + index.seconds
      )
    end
    create_access_log!(
      target_name: "zip-entry",
      action_type: :download,
      target_type: "zip",
      accessed_at: base_time + 1_000.seconds
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(target_type: "ai_context", page: 2)

    expect(response).to have_http_status(:ok)
    expect(log_target_names.size).to eq(50)
    expect(log_target_names.first).to eq("ai-entry-151")
    expect(log_target_names.last).to eq("ai-entry-102")
    expect(log_target_names).not_to include("zip-entry")
    expect(pagination_query(:previous)).to include("target_type" => "ai_context", "page" => "1")
    expect(pagination_query(:next)).to include("target_type" => "ai_context", "page" => "3")
  end

  it "treats invalid page and limit params as a bounded first page request" do
    base_time = Time.zone.parse("2026-05-01 00:00:00 UTC")

    205.times do |index|
      create_access_log!(target_name: "bounded-entry-#{index}", accessed_at: base_time + index.seconds)
    end

    sign_in_as(admin_user)

    get admin_access_logs_path(page: "0", limit: "1000")

    expect(response).to have_http_status(:ok)
    expect(log_target_names.size).to eq(50)
    expect(log_target_names.first).to eq("bounded-entry-204")
    expect(log_target_names.last).to eq("bounded-entry-155")
    expect(footer_summary).to eq("1–50 / 205件")
    expect(pagination_query(:next)).to include("page" => "2")
  end

  it "treats pages above the fixed page bound as a first page request" do
    base_time = Time.zone.parse("2026-05-01 00:00:00 UTC")

    205.times do |index|
      create_access_log!(target_name: "max-page-entry-#{index}", accessed_at: base_time + index.seconds)
    end

    sign_in_as(admin_user)

    get admin_access_logs_path(page: "200")

    expect(response).to have_http_status(:ok)
    expect(log_target_names.size).to eq(50)
    expect(log_target_names.first).to eq("max-page-entry-204")
    expect(log_target_names.last).to eq("max-page-entry-155")
    expect(footer_summary).to eq("1–50 / 205件")
    expect(pagination_query(:next)).to include("page" => "2")

    get admin_access_logs_path(page: "999999")

    expect(response).to have_http_status(:ok)
    expect(Admin::AccessLogsController::ACCESS_LOGS_MAX_PAGE).to eq(200)
    expect(Admin::AccessLogsController::ACCESS_LOGS_MAX_PAGE * Admin::AccessLogsController::ACCESS_LOGS_PER_PAGE).to eq(10_000)
    expect(log_target_names.size).to eq(50)
    expect(log_target_names.first).to eq("max-page-entry-204")
    expect(log_target_names.last).to eq("max-page-entry-155")
    expect(page_text).not_to include("999999ページ目")
    expect(footer_summary).to eq("1–50 / 205件")
    expect(pagination_query(:next)).to include("page" => "2")
  end
end
