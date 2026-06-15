require "rails_helper"

RSpec.describe "Admin access log date filter hint", type: :request do
  let(:admin_company) { create(:company, domain: "audit-hint.example.com", name: "Audit Hint Company") }
  let(:admin_user) { create(:user, :internal, company: admin_company) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "shows day-boundary guidance near the date filter fields" do
    sign_in_as(admin_user)

    get admin_access_logs_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("開始日はその日の0:00以降、終了日はその日の23:59までを含みます。片方だけでも指定できます。")
  end

  it "keeps the guidance visible with invalid date warnings" do
    create(:access_log, user: admin_user, company: admin_company, accessed_at: Time.zone.parse("2026-05-10 10:00:00 UTC"))
    sign_in_as(admin_user)

    get admin_access_logs_path(from: "not-a-date", to: "2026-99-99")

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(page_text).to include("開始日はその日の0:00以降、終了日はその日の23:59までを含みます。片方だけでも指定できます。")
      expect(page_text).to include("無効な日付条件は検索から除外しました")
    end
  end
end
