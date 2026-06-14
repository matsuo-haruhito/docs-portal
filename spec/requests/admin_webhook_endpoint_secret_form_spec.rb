require "rails_helper"

RSpec.describe "Admin webhook endpoint secret form", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def signature_for(endpoint, body)
    event = create(:notification_event, event_type: :document_updated)
    _uri, request = WebhookDispatch::RequestBuilder.new(endpoint: endpoint, event: event, body: body).call
    request["X-Docs-Portal-Signature-256"]
  end

  it "does not render the existing secret token in the edit form" do
    sign_in_as(admin_user)

    endpoint = create(:webhook_endpoint, secret_token: "existing-secret-token")

    get edit_admin_webhook_endpoint_path(endpoint.public_id)

    secret_input = parsed_html.at_css(%(input[name="webhook_endpoint[secret_token]"]))

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("設定済み（変更する場合だけ入力）")
    expect(secret_input["value"]).to be_nil
    expect(response.body).not_to include("existing-secret-token")
  end

  it "shows unset state without adding a raw secret value" do
    sign_in_as(admin_user)

    endpoint = create(:webhook_endpoint, secret_token: nil)

    get edit_admin_webhook_endpoint_path(endpoint.public_id)

    secret_input = parsed_html.at_css(%(input[name="webhook_endpoint[secret_token]"]))

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("未設定")
    expect(secret_input["value"]).to be_nil
  end

  it "keeps the existing secret when the edit form submits a blank secret token" do
    sign_in_as(admin_user)

    endpoint = create(:webhook_endpoint, secret_token: "existing-secret-token", target_url: "https://hooks.example.test/old", active: true)
    body = JSON.generate(event_type: "document_updated")

    patch admin_webhook_endpoint_path(endpoint.public_id), params: {
      webhook_endpoint: {
        name: "Updated Hook",
        target_url: "https://hooks.example.test/new",
        secret_token: "",
        active: "0",
        event_types: ["document_published"]
      }
    }

    endpoint.reload

    expect(response).to redirect_to(admin_webhook_endpoints_path)
    expect(endpoint.name).to eq("Updated Hook")
    expect(endpoint.target_url).to eq("https://hooks.example.test/new")
    expect(endpoint).not_to be_active
    expect(endpoint.normalized_event_types).to eq(["document_published"])
    expect(endpoint.secret_token).to eq("existing-secret-token")
    expect(signature_for(endpoint, body)).to eq("sha256=#{OpenSSL::HMAC.hexdigest('SHA256', 'existing-secret-token', body)}")
  end

  it "updates the secret only when a non-blank secret token is submitted" do
    sign_in_as(admin_user)

    endpoint = create(:webhook_endpoint, secret_token: "existing-secret-token")
    body = JSON.generate(event_type: "document_updated")

    patch admin_webhook_endpoint_path(endpoint.public_id), params: {
      webhook_endpoint: {
        name: endpoint.name,
        target_url: endpoint.target_url,
        secret_token: "new-secret-token",
        active: "1",
        event_types: endpoint.normalized_event_types
      }
    }

    endpoint.reload

    expect(response).to redirect_to(admin_webhook_endpoints_path)
    expect(endpoint.secret_token).to eq("new-secret-token")
    expect(signature_for(endpoint, body)).to eq("sha256=#{OpenSSL::HMAC.hexdigest('SHA256', 'new-secret-token', body)}")
  end
end
