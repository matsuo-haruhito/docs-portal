require "rails_helper"

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

  def page_links
    parsed_html.css('nav[aria-label="監査ログページ移動"] a').map do |link|
      [link.text.squish, link["href"]]
    end
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

  it "paginates access logs after the first 200 rows with stable recent ordering" do
    base_time = Time.zone.parse("2026-05-01 00:00:00 UTC")

    205.times do |index|
      create_access_log!(target_name: "entry-#{index}", accessed_at: base_time + index.seconds)
    end

    sign_in_as(admin_user)

    get admin_access_logs_path

    expect(response).to have_http_status(:ok)
    expect(log_target_names.size).to eq(200)
    expect(log_target_names.first).to eq("entry-204")
    expect(log_target_names.last).to eq("entry-5")
    expect(page_text).to include("次ページで古い証跡を確認できます")
    expect(page_links).to include(["次の200件", admin_access_logs_path(page: 2)])
    expect(page_links.map(&:first)).not_to include("前の200件")

    get admin_access_logs_path(page: 2)

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["entry-4", "entry-3", "entry-2", "entry-1", "entry-0"])
    expect(page_text).to include("2ページ目")
    expect(page_links).to include(["前の200件", admin_access_logs_path(page: 1)])
    expect(page_links.map(&:first)).not_to include("次の200件")
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
    expect(log_target_names).to eq(["ai-entry-1", "ai-entry-0"])
    expect(log_target_names).not_to include("zip-entry")
    expect(page_links).to include(["前の200件", admin_access_logs_path(target_type: "ai_context", page: 1)])
  end

  it "treats invalid page and limit params as a bounded first page request" do
    base_time = Time.zone.parse("2026-05-01 00:00:00 UTC")

    205.times do |index|
      create_access_log!(target_name: "bounded-entry-#{index}", accessed_at: base_time + index.seconds)
    end

    sign_in_as(admin_user)

    get admin_access_logs_path(page: "0", limit: "1000")

    expect(response).to have_http_status(:ok)
    expect(log_target_names.size).to eq(200)
    expect(log_target_names.first).to eq("bounded-entry-204")
    expect(log_target_names.last).to eq("bounded-entry-5")
    expect(page_links).to include(["次の200件", admin_access_logs_path(page: 2)])
  end
end
