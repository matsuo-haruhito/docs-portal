require "rails_helper"

RSpec.describe "Admin webhook delivery detail display boundaries", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "masks URL query diagnostics and keeps request body raw values hidden" do
    sign_in_as(admin_user)

    endpoint = create(
      :webhook_endpoint,
      name: "Diagnostic Hook",
      active: true,
      target_url: "https://hooks.example.test/receive?token=target-secret&user_id=customer-123#debug"
    )
    event = create(:notification_event, event_type: :document_updated)
    delivery = create(
      :webhook_delivery,
      webhook_endpoint: endpoint,
      notification_event: event,
      event_type: "document_updated",
      status: :failed,
      target_url: endpoint.target_url,
      request_body: "event_type=document_updated token=request-secret visible=request-visible",
      response_status: 502,
      response_body: "<script>alert('x')</script> client_secret=response-secret note=#{'b' * 800}",
      error_message: "Authorization: Bearer hidden-token\nretry failed",
      sent_at: Time.zone.local(2026, 6, 3, 9, 0, 0)
    )

    get admin_webhook_delivery_path(delivery.public_id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Diagnostic Hook")
    expect(page_text).to include("https://hooks.example.test/receive?...")
    expect(page_text).to include("client_secret=[masked]")
    expect(page_text).to include("Authorization: [masked]")
    expect(page_text).to include("token=[masked]")
    expect(page_text).to include("visible=request-visible")
    expect(page_text).to include("...省略...")
    expect(parsed_html.css("pre script")).to be_empty
    expect(page_text).not_to include("target-secret")
    expect(page_text).not_to include("user_id")
    expect(page_text).not_to include("customer-123")
    expect(page_text).not_to include("#debug")
    expect(page_text).not_to include("response-secret")
    expect(page_text).not_to include("hidden-token")
    expect(page_text).not_to include("request-secret")
    expect(page_text).not_to include("#{'b' * 700}")
  end
end
