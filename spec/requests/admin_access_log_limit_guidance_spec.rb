require "rails_helper"

RSpec.describe "Admin access log display limit guidance", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "AUDIT", name: "Audit Project") }
  let(:document) { create(:document, project:, title: "Audit Document", slug: "audit-document") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0") }

  def page_text
    Nokogiri::HTML(response.body).text.squish
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

  it "does not show display limit guidance below 200 rows" do
    create_access_log!(action_type: :download, target_type: "zip", target_name: "audit.zip")

    sign_in_as(admin_user)

    get admin_access_logs_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 1件 / 最新200件までを表示")
    expect(page_text).not_to include("表示上限の200件に達しています。")
  end

  it "shows guidance when the latest 200 row display limit is reached" do
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
    expect(page_text).to include("表示上限の200件に達しています。")
    expect(page_text).to include("古い証跡を探す場合は、案件・会社・ユーザー・文書名などの条件を追加してください。")
  end

  it "shows filtered guidance when the display limit is reached with filters" do
    base_time = Time.zone.parse("2026-05-01 00:00:00 UTC")

    200.times do |index|
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
    expect(page_text).to include("表示上限の200件に達しています。")
    expect(page_text).to include("目的の証跡が見つからない場合は、案件・会社・ユーザー・文書名などの条件を追加してさらに絞り込んでください。")
  end
end
