require "rails_helper"

RSpec.describe "Admin webhook recent history overflow copy", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def page_text
    Nokogiri::HTML(response.body).text.squish
  end

  it "explains where to review deliveries outside the recent history limit" do
    create_recent_deliveries(51)

    sign_in_as(admin_user)
    get admin_webhook_endpoints_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示範囲: すべて 51件中50件を表示しています。")
    expect(page_text).to include("50件より前の履歴は、送信履歴検索でWebhook設定・イベント・ステータス・作成日を指定して確認できます。")
    expect(page_text).to include("送信履歴検索へ")
    expect(page_text).not_to include("後続 slice")
    expect(page_text).not_to include("endpoint / event / status / 作成日")
  end

  it "keeps the overflow explanation hidden when recent history is within the limit" do
    create_recent_deliveries(50)

    sign_in_as(admin_user)
    get admin_webhook_endpoints_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示範囲: すべて 50件中50件を表示しています。")
    expect(page_text).not_to include("50件より前の履歴は")
    expect(page_text).not_to include("後続 slice")
  end

  def create_recent_deliveries(count)
    endpoint = create(:webhook_endpoint, name: "Recent History Hook", event_types: %w[document_updated])
    event = create(:notification_event, event_type: :document_updated)

    count.times do |index|
      create(
        :webhook_delivery,
        webhook_endpoint: endpoint,
        notification_event: event,
        event_type: "document_updated",
        status: :succeeded,
        response_status: 200,
        created_at: index.minutes.ago
      )
    end
  end
end
