require "rails_helper"

RSpec.describe "Admin webhook endpoint action clarity", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def action_targets
    parsed_html.css("a[href], form[action]").map do |node|
      node["href"] || node["action"]
    end
  end

  it "separates endpoint edit/delete actions from delivery detail/redelivery actions" do
    sign_in_as(admin_user)

    endpoint = create(:webhook_endpoint, name: "Docs Hook", active: true)
    event = create(:notification_event, event_type: :document_updated)
    delivery = create(:webhook_delivery, webhook_endpoint: endpoint, notification_event: event, status: :failed)

    get admin_webhook_endpoints_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Webhook設定そのものの編集・削除です。")
    expect(page_text).to include("最近の送信履歴の詳細確認・再送とは別の操作です。")
    expect(page_text).to include("設定操作")
    expect(response.body).to include("Webhook設定を削除します。")
    expect(response.body).to include("名称: Docs Hook")
    expect(response.body).to include("イベント: 文書更新")
    expect(action_targets).to include(edit_admin_webhook_endpoint_path(endpoint))
    expect(action_targets).to include(admin_webhook_endpoint_path(endpoint))
    expect(action_targets).to include(admin_webhook_delivery_path(delivery.public_id))
    expect(action_targets).to include(retry_dispatch_admin_webhook_delivery_path(delivery.public_id))
  end
end
