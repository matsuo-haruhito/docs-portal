require "rails_helper"

RSpec.describe "Admin webhook endpoint HTTP status cues", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "uses readable recent delivery cues when HTTP status has not been captured" do
    sign_in_as(admin_user)

    event = create(:notification_event, event_type: :document_updated)
    missing_status_endpoint = create(:webhook_endpoint, name: "Missing HTTP Hook", active: true)
    captured_status_endpoint = create(:webhook_endpoint, name: "Captured HTTP Hook", active: true)

    missing_status_delivery = create(
      :webhook_delivery,
      webhook_endpoint: missing_status_endpoint,
      notification_event: event,
      event_type: "document_updated",
      status: :failed,
      response_status: nil,
      created_at: 2.minutes.ago
    )
    captured_status_delivery = create(
      :webhook_delivery,
      webhook_endpoint: captured_status_endpoint,
      notification_event: event,
      event_type: "document_updated",
      status: :failed,
      response_status: 500,
      created_at: 1.minute.ago
    )

    get admin_webhook_endpoints_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Missing HTTP Hook")
    expect(page_text).to include("Captured HTTP Hook")
    expect(page_text).to include("未取得")
    expect(page_text).to include("500")
    expect(response.body).to include("HTTP未取得")
    expect(response.body).to include("HTTP 500")
    expect(response.body).not_to include("HTTP -")
    expect(response.body).to include(retry_dispatch_admin_webhook_delivery_path(missing_status_delivery.public_id))
    expect(response.body).to include(retry_dispatch_admin_webhook_delivery_path(captured_status_delivery.public_id))
  end
end
