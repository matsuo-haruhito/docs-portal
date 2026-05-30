require "rails_helper"

RSpec.describe "Admin webhook endpoints", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def page_text
    Nokogiri::HTML(response.body).text.squish
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
    expect(page_text).to include("200")

    get admin_webhook_endpoints_path(delivery_status: "failed")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("失敗のみ")
    expect(page_text).to include("Failed Hook")
    expect(page_text).to include("timeout")
    expect(page_text).not_to include("200")
  end
end
