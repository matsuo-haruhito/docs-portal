require "rails_helper"

RSpec.describe "Admin webhook endpoints", type: :request do
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

  def recent_delivery_rows
    parsed_html.css("tbody tr").select do |row|
      row.at_css(%(td[data-rails-table-preferences-column-key="response_status"]))
    end
  end

  def recent_delivery_response_statuses
    recent_delivery_rows.map do |row|
      row.at_css(%(td[data-rails-table-preferences-column-key="response_status"])).text.squish
    end
  end

  it "renders localized event labels in the form, endpoint list, and recent deliveries" do
    sign_in_as(admin_user)

    endpoint = create(
      :webhook_endpoint,
      name: "Docs Hook",
      event_types: %w[document_updated qa_answered],
      active: true
    )
    event = create(:notification_event, event_type: :qa_answered)
    create(:webhook_delivery, webhook_endpoint: endpoint, notification_event: event, event_type: "qa_answered", status: :failed)

    get admin_webhook_endpoints_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("文書更新")
    expect(page_text).to include("Q&A回答")
    expect(page_text).to include("失敗")
    expect(page_text).not_to include("document_updated")
    expect(page_text).not_to include("qa_answered")
  end

  it "highlights failed deliveries and filters the recent delivery table by status" do
    sign_in_as(admin_user)

    failed_endpoint = create(:webhook_endpoint, name: "Failed Hook", event_types: %w[document_updated])
    succeeded_endpoint = create(:webhook_endpoint, name: "Success Hook", event_types: %w[document_updated])
    event = create(:notification_event, event_type: :document_updated)
    create(
      :webhook_delivery,
      webhook_endpoint: failed_endpoint,
      notification_event: event,
      event_type: "document_updated",
      status: :failed,
      response_status: 500,
      error_message: "timeout"
    )
    create(
      :webhook_delivery,
      webhook_endpoint: succeeded_endpoint,
      notification_event: event,
      event_type: "document_updated",
      status: :succeeded,
      response_status: 200
    )

    get admin_webhook_endpoints_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("直近の送信履歴に失敗が1件あります")
    expect(page_text).to include("失敗のみ")
    expect(page_text).to include("Failed Hook")
    expect(page_text).to include("Success Hook")
    expect(recent_delivery_response_statuses).to include("200")

    get admin_webhook_endpoints_path(delivery_status: "failed")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("失敗のみ")
    expect(page_text).to include("Failed Hook")
    expect(page_text).to include("timeout")
    expect(recent_delivery_response_statuses).not_to include("200")
  end

  it "links recent deliveries to the detail page" do
    sign_in_as(admin_user)

    delivery = create(:webhook_delivery, status: :failed)

    get admin_webhook_endpoints_path

    expect(response).to have_http_status(:ok)
    expect(action_targets).to include(admin_webhook_delivery_path(delivery.public_id))
  end

  it "keeps the existing secret when editing with a blank secret field" do
    sign_in_as(admin_user)

    endpoint = create(
      :webhook_endpoint,
      name: "Blank Secret Hook",
      target_url: "https://example.com/webhooks/original",
      secret_token: "stored-secret",
      active: true,
      event_types: %w[document_updated]
    )

    patch admin_webhook_endpoint_path(endpoint.public_id), params: {
      webhook_endpoint: {
        name: "Blank Secret Hook Updated",
        target_url: "https://example.com/webhooks/updated",
        secret_token: "",
        active: "0",
        event_types: ["", "document_published"]
      }
    }

    expect(response).to redirect_to(admin_webhook_endpoints_path)
    endpoint.reload
    expect(endpoint).to have_attributes(
      name: "Blank Secret Hook Updated",
      target_url: "https://example.com/webhooks/updated",
      active: false,
      normalized_event_types: ["document_published"]
    )
    expect(endpoint.secret_token).to eq("stored-secret")
  end
end
