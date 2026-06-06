require "rails_helper"
require "uri"

RSpec.describe "Admin access log CSV export scope", type: :request do
  let(:admin_company) { create(:company, domain: "audit.example.com", name: "Audit Company") }
  let(:admin_user) { create(:user, :internal, company: admin_company) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def csv_export_link
    parsed_html.css("a").find { |link| link.text.squish == "現在の条件でCSV export（最新200件）" }
  end

  def csv_export_query
    Rack::Utils.parse_nested_query(URI.parse(csv_export_link["href"]).query)
  end

  def create_access_log!(target_name:, accessed_at: Time.current)
    AccessLog.create!(
      user: admin_user,
      company: admin_company,
      action_type: :view,
      target_type: "page",
      target_name:,
      ip_address: "127.0.0.1",
      user_agent: "RSpec",
      accessed_at:
    )
  end

  it "clarifies that CSV export ignores the current page while preserving active filters" do
    base_time = Time.zone.parse("2026-05-01 00:00:00 UTC")

    205.times do |index|
      create_access_log!(target_name: "filtered-entry-#{index}", accessed_at: base_time + index.seconds)
    end

    sign_in_as(admin_user)

    get admin_access_logs_path(page: 2, q: "filtered-entry")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 5件 / 最新200件までを表示 / 2ページ目 / 絞り込み中")
    expect(page_text).to include("ページ移動中でも、CSV export は表示中ページではなく条件一致の最新200件が対象です。")
    expect(csv_export_query).to include("q" => "filtered-entry")
    expect(csv_export_query).to include("format" => "csv")
    expect(csv_export_query).not_to include("page")
  end
end
