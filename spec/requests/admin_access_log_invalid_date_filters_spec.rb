require "csv"
require "rails_helper"

RSpec.describe "Admin access log invalid date filters", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "DATE", name: "Date Filter Project") }
  let(:document) { create(:document, project:, title: "Date Filter Document", slug: "date-filter-document") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def log_target_names
    parsed_html.css("table tbody tr").filter_map do |row|
      row.at_css("td:nth-child(3) code")&.text&.squish
    end
  end

  def create_access_log!(target_name:, accessed_at:)
    AccessLog.create!(
      user: admin_user,
      company: admin_user.company,
      project:,
      document:,
      document_version: version,
      action_type: :view,
      target_type: "page",
      target_name:,
      ip_address: "127.0.0.1",
      user_agent: "RSpec",
      accessed_at:
    )
  end

  before do
    create_access_log!(target_name: "before-range.html", accessed_at: Time.zone.parse("2026-05-09 08:00:00 UTC"))
    create_access_log!(target_name: "range-match.html", accessed_at: Time.zone.parse("2026-05-11 10:00:00 UTC"))
    create_access_log!(target_name: "after-range.html", accessed_at: Time.zone.parse("2026-05-13 12:00:00 UTC"))
    sign_in_as(admin_user)
  end

  it "shows ignored start-date warning while applying a valid end date" do
    get admin_access_logs_path(from: "not-a-date", to: "2026-05-12")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["range-match.html", "before-range.html"])
    expect(page_text).to include("無効な日付条件は検索から除外しました:")
    expect(page_text).to include("開始日")
    expect(page_text).to include("有効な日付条件だけで監査ログを絞り込んでいます。")
    expect(page_text).to include("終了日: 2026-05-12")
    expect(page_text).to include("開始日: 日付を確認")
  end

  it "shows ignored end-date warning while applying a valid start date" do
    get admin_access_logs_path(from: "2026-05-10", to: "invalid-date")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["after-range.html", "range-match.html"])
    expect(page_text).to include("無効な日付条件は検索から除外しました:")
    expect(page_text).to include("終了日")
    expect(page_text).to include("有効な日付条件だけで監査ログを絞り込んでいます。")
    expect(page_text).to include("開始日: 2026-05-10")
    expect(page_text).to include("終了日: 日付を確認")
  end

  it "shows both ignored date labels when both date filters are invalid" do
    get admin_access_logs_path(from: "not-a-date", to: "2026-99-99")

    expect(response).to have_http_status(:ok)
    expect(log_target_names).to eq(["after-range.html", "range-match.html", "before-range.html"])
    expect(page_text).to include("無効な日付条件は検索から除外しました:")
    expect(page_text).to include("開始日、終了日")
    expect(page_text).to include("有効な日付条件だけで監査ログを絞り込んでいます。")
  end

  it "exports CSV with valid date filters only when the other date is invalid" do
    get admin_access_logs_path(format: :csv, from: "2026-05-10", to: "invalid-date")

    expect(response).to have_http_status(:ok)
    rows = CSV.parse(response.body, headers: true)
    expect(rows.map { _1["対象名"] }).to eq(["after-range.html", "range-match.html"])
  end
end
