require "rails_helper"

RSpec.describe "Admin webhook recent delivery preview", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:webhook_endpoint) { create(:webhook_endpoint, name: "Recent Preview Hook", active: true) }
  let(:event) { create(:notification_event, event_type: :document_updated) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def error_cells
    parsed_html.css(%(td[data-rails-table-preferences-column-key="error_message"]))
  end

  def action_targets
    parsed_html.css("a[href], form[action]").map { _1["href"] || _1["action"] }
  end

  it "shows masked error previews in the recent delivery table while preserving actions" do
    sign_in_as(admin_user)
    delivery = create(
      :webhook_delivery,
      webhook_endpoint:,
      notification_event: event,
      event_type: "document_updated",
      status: :failed,
      response_status: 500,
      error_message: "Authorization: Bearer raw-secret-token\ntoken=abc123 failed at /home/alice/customer/docs.yml"
    )

    get admin_webhook_endpoints_path(delivery_status: "failed")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("最近の送信履歴")
    expect(page_text).to include("失敗のみ")
    expect(page_text).to include("500")
    expect(page_text).to include("Authorization: [masked]")
    expect(page_text).to include("token=[masked]")
    expect(page_text).to include("[path hidden]")
    expect(page_text).not_to include("raw-secret-token")
    expect(page_text).not_to include("abc123")
    expect(page_text).not_to include("/home/alice/customer/docs.yml")
    expect(error_cells.map { _1.text.squish }).to include("Authorization: [masked] token=[masked] failed at [path hidden]")
    expect(action_targets).to include(admin_webhook_deliveries_path)
    expect(action_targets).to include(admin_webhook_delivery_path(delivery.public_id, return_delivery_status: "failed"))
    expect(action_targets).to include(retry_dispatch_admin_webhook_delivery_path(delivery.public_id, return_delivery_status: "failed"))
    expect(action_targets).to include(retry_failed_admin_webhook_deliveries_path(delivery_status: "failed"))
  end

  it "keeps blank recent delivery errors as a dash" do
    sign_in_as(admin_user)
    create(:webhook_delivery, webhook_endpoint:, notification_event: event, status: :failed, error_message: nil)

    get admin_webhook_endpoints_path(delivery_status: "failed")

    expect(response).to have_http_status(:ok)
    expect(error_cells.map { _1.text.squish }).to include("-")
  end
end
