require "rails_helper"

RSpec.describe "Admin access log display limit guidance", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "AUDIT", name: "Audit Project") }
  let(:document) { create(:document, project:, title: "Audit Document", slug: "audit-document") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def create_access_log!(action_type:, target_type:, target_name:, accessed_at: Time.current)
    AccessLog.create!(
      user: admin_user,
      company: admin_user.company,
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

  it "shows the bounded range without rendering pagination below 50 rows" do
    create_access_log!(action_type: :download, target_type: "zip", target_name: "audit.zip")

    sign_in_as(admin_user)

    get admin_access_logs_path

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css(".list-footer__summary").text.squish).to eq("1–1 / 1件")
    expect(parsed_html.at_css(".list-footer__pagination")).to be_nil
    expect(page_text).to include("最大10,000件まで確認できます。")
  end

  it "shows pagination and the bounded display disclosure after 50 rows" do
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
    expect(parsed_html.at_css(".list-footer__summary").text.squish).to eq("1–50 / 205件")
    expect(parsed_html.at_css(".list-footer__pagination")).to be_present
    expect(page_text).to include("監査ログは新しい順に1ページ50件、最大10,000件まで確認できます。")
  end

  it "keeps active filters visible as filter chips at the page boundary" do
    base_time = Time.zone.parse("2026-05-01 00:00:00 UTC")

    50.times do |index|
      create_access_log!(
        action_type: :view,
        target_type: "page",
        target_name: "filtered-entry-#{index}",
        accessed_at: base_time + index.seconds
      )
    end

    sign_in_as(admin_user)

    get admin_access_logs_path(action_type: "view")

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css(".list-footer__summary").text.squish).to eq("1–50 / 50件")
    expect(parsed_html.at_css('[aria-label="適用中の検索条件"]').text.squish).to include("操作: 閲覧")
    expect(parsed_html.at_css(".list-footer__pagination")).to be_nil
  end
end
