require "rails_helper"

RSpec.describe "Admin webhook delivery redelivery copy", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "labels detail redelivery as a single-history action using the current webhook settings" do
    sign_in_as(admin_user)

    endpoint = create(:webhook_endpoint, active: true)
    event = create(:notification_event, event_type: :document_updated)
    delivery = create(:webhook_delivery, webhook_endpoint: endpoint, notification_event: event, status: :failed)

    get admin_webhook_delivery_path(delivery.public_id)

    expect(response).to have_http_status(:ok)

    retry_form = parsed_html.at_css(%(form[action="#{retry_dispatch_admin_webhook_delivery_path(delivery.public_id)}"]))
    expect(retry_form).to be_present

    retry_button = retry_form.at_css("button")
    expect(retry_button.text.squish).to eq("この履歴を1件再送")
    expect(retry_button["title"]).to eq("現在のWebhook設定でこの履歴を1件再送")
    expect(retry_button["aria-label"]).to eq("現在のWebhook設定でこのWebhook送信履歴を1件再送")
    expect(retry_form["data-turbo-confirm"]).to eq("このWebhook送信履歴1件を現在のWebhook設定で再送します。受信先側の重複処理に注意してください。")
  end

  it "does not show detail redelivery copy for non-retryable deliveries" do
    sign_in_as(admin_user)

    delivery = create(:webhook_delivery, status: :succeeded)

    get admin_webhook_delivery_path(delivery.public_id)

    expect(response).to have_http_status(:ok)
    expect(parsed_html.text.squish).to include("この送信履歴は再送できません")
    expect(parsed_html.text.squish).not_to include("この履歴を1件再送")
    expect(parsed_html.css(%(form[action="#{retry_dispatch_admin_webhook_delivery_path(delivery.public_id)}"]))).to be_empty
  end
end
