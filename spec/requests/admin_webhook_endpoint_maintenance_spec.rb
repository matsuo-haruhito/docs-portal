require "rails_helper"

RSpec.describe "Admin webhook endpoint maintenance mode", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def with_read_only_maintenance(value)
    previous = ENV.fetch(Admin::WebhookEndpointsController::READ_ONLY_MAINTENANCE_ENV, nil)
    ENV[Admin::WebhookEndpointsController::READ_ONLY_MAINTENANCE_ENV] = value
    yield
  ensure
    if previous.nil?
      ENV.delete(Admin::WebhookEndpointsController::READ_ONLY_MAINTENANCE_ENV)
    else
      ENV[Admin::WebhookEndpointsController::READ_ONLY_MAINTENANCE_ENV] = previous
    end
  end

  it "does not create webhook endpoints during read-only maintenance" do
    sign_in_as(admin_user)

    expect do
      with_read_only_maintenance("1") do
        post admin_webhook_endpoints_path, params: {
          webhook_endpoint: {
            name: "Maintenance Hook",
            target_url: "https://example.com/webhooks/maintenance",
            secret_token: "new-secret",
            active: "1",
            event_types: ["document_updated", ""]
          }
        }
      end
    end.not_to change(WebhookEndpoint, :count)

    expect(response).to redirect_to(admin_webhook_endpoints_path)
    expect(flash[:alert]).to include("メンテナンス中のためWebhook設定の作成・更新・削除は停止しています")
  end

  it "does not update webhook endpoints during read-only maintenance" do
    endpoint = create(
      :webhook_endpoint,
      name: "Original Hook",
      target_url: "https://example.com/webhooks/original",
      secret_token: "stored-secret",
      active: true,
      event_types: %w[document_updated]
    )
    sign_in_as(admin_user)

    with_read_only_maintenance("true") do
      patch admin_webhook_endpoint_path(endpoint.public_id), params: {
        webhook_endpoint: {
          name: "Changed Hook",
          target_url: "https://example.com/webhooks/changed",
          secret_token: "changed-secret",
          active: "0",
          event_types: ["qa_answered"]
        }
      }
    end

    expect(response).to redirect_to(edit_admin_webhook_endpoint_path(endpoint.public_id))
    expect(flash[:alert]).to include("メンテナンス中のためWebhook設定の作成・更新・削除は停止しています")
    endpoint.reload
    expect(endpoint).to have_attributes(
      name: "Original Hook",
      target_url: "https://example.com/webhooks/original",
      secret_token: "stored-secret",
      active: true
    )
    expect(endpoint.event_types).to eq(%w[document_updated])
  end

  it "does not destroy webhook endpoints or their delivery history during read-only maintenance" do
    endpoint = create(:webhook_endpoint, active: true)
    delivery = create(:webhook_delivery, webhook_endpoint: endpoint, status: :failed)
    sign_in_as(admin_user)

    expect do
      with_read_only_maintenance("1") do
        delete admin_webhook_endpoint_path(endpoint.public_id)
      end
    end.not_to change(WebhookEndpoint, :count)
    expect { delivery.reload }.not_to raise_error

    expect(response).to redirect_to(admin_webhook_endpoints_path)
    expect(flash[:alert]).to include("メンテナンス中のためWebhook設定の作成・更新・削除は停止しています")
    expect(endpoint.reload).to be_persisted
  end

  it "keeps webhook endpoint lists, delivery detail, and failure handoff readable during read-only maintenance" do
    endpoint = create(:webhook_endpoint, name: "Readable Hook", active: true)
    delivery = create(:webhook_delivery, webhook_endpoint: endpoint, status: :failed, error_message: "maintenance timeout")
    sign_in_as(admin_user)

    with_read_only_maintenance("1") do
      get admin_webhook_endpoints_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Readable Hook")

      get admin_webhook_delivery_path(delivery.public_id)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("maintenance timeout")

      get failure_alert_handoff_admin_webhook_deliveries_path(format: :json)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include("candidates")
    end
  end

  it "keeps webhook endpoint CRUD working when read-only maintenance is disabled" do
    sign_in_as(admin_user)

    expect do
      with_read_only_maintenance("0") do
        post admin_webhook_endpoints_path, params: {
          webhook_endpoint: {
            name: "Writable Hook",
            target_url: "https://example.com/webhooks/writable",
            secret_token: "writable-secret",
            active: "1",
            event_types: ["document_updated"]
          }
        }
      end
    end.to change(WebhookEndpoint, :count).by(1)

    endpoint = WebhookEndpoint.order(:id).last
    expect(response).to redirect_to(admin_webhook_endpoints_path)
    expect(endpoint.name).to eq("Writable Hook")

    with_read_only_maintenance("0") do
      patch admin_webhook_endpoint_path(endpoint.public_id), params: {
        webhook_endpoint: {
          name: "Writable Hook Updated",
          target_url: "https://example.com/webhooks/writable-updated",
          secret_token: "",
          active: "0",
          event_types: ["qa_answered"]
        }
      }
    end

    expect(response).to redirect_to(admin_webhook_endpoints_path)
    endpoint.reload
    expect(endpoint.name).to eq("Writable Hook Updated")
    expect(endpoint.active).to eq(false)
    expect(endpoint.event_types).to eq(%w[qa_answered])

    expect do
      with_read_only_maintenance("0") do
        delete admin_webhook_endpoint_path(endpoint.public_id)
      end
    end.to change(WebhookEndpoint, :count).by(-1)
    expect(response).to redirect_to(admin_webhook_endpoints_path)
  end
end
