require "rails_helper"

RSpec.describe "Admin webhook endpoint target URL display", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "masks query values in the endpoint list while keeping the edit form raw value" do
    sign_in_as(admin_user)

    target_url = "https://hooks.example.test/docs/events?token=secret-value&signature=abc123"
    endpoint = create(
      :webhook_endpoint,
      name: "Secret Hook",
      target_url: target_url,
      event_types: %w[document_updated]
    )

    get admin_webhook_endpoints_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Secret Hook")
    expect(page_text).to include("https://hooks.example.test/docs/events?...")
    expect(response.body).not_to include("token=secret-value")
    expect(response.body).not_to include("signature=abc123")
    expect(response.body).not_to include("secret-value")
    expect(parsed_html.css('[data-rails-table-preferences-column-key="target_url"]').map(&:text).join(" ")).to include("送信先URL")

    get edit_admin_webhook_endpoint_path(endpoint)

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css('input[name="webhook_endpoint[target_url]"]')["value"]).to eq(target_url)
  end
end
