require "rails_helper"

RSpec.describe "Admin webhook delivery search filters", type: :request do
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

  it "filters delivery search by HTTP status, error text, and existing filter fields" do
    sign_in_as(admin_user)

    matching_endpoint = create(:webhook_endpoint, name: "Target Hook", event_types: %w[document_updated])
    other_endpoint = create(:webhook_endpoint, name: "Other Hook", event_types: %w[document_updated])
    event = create(:notification_event, event_type: :document_updated)
    matching_delivery = create(
      :webhook_delivery,
      webhook_endpoint: matching_endpoint,
      notification_event: event,
      event_type: "document_updated",
      status: :failed,
      response_status: 500,
      error_message: "Upstream TIMEOUT while posting payload"
    )
    create(
      :webhook_delivery,
      webhook_endpoint: matching_endpoint,
      notification_event: event,
      event_type: "document_updated",
      status: :failed,
      response_status: 503,
      error_message: "Upstream timeout while posting payload"
    )
    create(
      :webhook_delivery,
      webhook_endpoint: other_endpoint,
      notification_event: event,
      event_type: "document_updated",
      status: :failed,
      response_status: 500,
      error_message: "Upstream timeout while posting payload"
    )
    create(
      :webhook_delivery,
      webhook_endpoint: matching_endpoint,
      notification_event: event,
      event_type: "document_updated",
      status: :succeeded,
      response_status: 500,
      error_message: "Upstream timeout while posting payload"
    )

    get admin_webhook_deliveries_path(
      webhook_endpoint_id: matching_endpoint.id,
      event_type: "document_updated",
      status: "failed",
      response_status: "500",
      error_q: "timeout"
    )

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示範囲: 1件中1件を新しい順で表示しています。")
    expect(page_text).to include("Target Hook")
    expect(page_text).to include("500")
    expect(page_text).to include("Upstream TIMEOUT")
    expect(page_text).not_to include("Other Hook")
    expect(page_text).not_to include("503")
    expect(action_targets).to include(
      admin_webhook_delivery_path(
        matching_delivery.public_id,
        webhook_endpoint_id: matching_endpoint.id.to_s,
        event_type: "document_updated",
        status: "failed",
        response_status: "500",
        error_q: "timeout",
        return_context: "deliveries_index"
      )
    )
    expect(action_targets).not_to include(retry_failed_admin_webhook_deliveries_path(delivery_status: "failed"))
  end

  it "ignores malformed HTTP status and blank error filters without leaking them to return params" do
    sign_in_as(admin_user)

    ok_delivery = create(:webhook_delivery, response_status: 200, error_message: "ok")
    failed_delivery = create(:webhook_delivery, status: :failed, response_status: 500, error_message: "timeout")

    get admin_webhook_deliveries_path(response_status: "999", error_q: "   ", created_from: "not-a-date")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(ok_delivery.webhook_endpoint.name)
    expect(page_text).to include(failed_delivery.webhook_endpoint.name)
    expect(action_targets).to include(admin_webhook_delivery_path(ok_delivery.public_id, return_context: "deliveries_index"))
    expect(action_targets).to include(admin_webhook_delivery_path(failed_delivery.public_id, return_context: "deliveries_index"))
    expect(action_targets.join(" ")).not_to include("response_status=999")
    expect(action_targets.join(" ")).not_to include("error_q")
    expect(action_targets.join(" ")).not_to include("not-a-date")
  end
end
