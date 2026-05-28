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
end
