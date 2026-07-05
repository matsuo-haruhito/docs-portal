require "rails_helper"

RSpec.describe "Admin webhook delivery detail link cue", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def link_by_href(href)
    parsed_html.css("a[href]").find { |link| link["href"] == href }
  end

  def create_delivery(endpoint:, event:, created_at:, **attributes)
    create(
      :webhook_delivery,
      {
        webhook_endpoint: endpoint,
        notification_event: event,
        event_type: event.event_type,
        created_at: created_at
      }.merge(attributes)
    )
  end

  it "labels search result detail links while preserving filters and page" do
    sign_in_as(admin_user)

    event = create(:notification_event, event_type: :document_updated)
    endpoint = create(:webhook_endpoint, name: "Cue Hook")
    base_time = Time.zone.local(2026, 6, 10, 12, 0, 0)
    deliveries = Array.new(101) do |index|
      create_delivery(
        endpoint: endpoint,
        event: event,
        status: :failed,
        response_status: 500,
        error_message: "cue timeout #{index}",
        created_at: base_time - index.minutes
      )
    end
    filters = {
      webhook_endpoint_id: endpoint.id.to_s,
      event_type: "document_updated",
      status: "failed",
      response_status: "500",
      error_q: "cue",
      created_from: "2026-06-10",
      created_to: "2026-06-10"
    }
    expected_href = admin_webhook_delivery_path(
      deliveries.last.public_id,
      filters.merge(return_context: "deliveries_index", page: 2)
    )

    get admin_webhook_deliveries_path(filters.merge(page: 2))

    expect(response).to have_http_status(:ok)
    detail_link = link_by_href(expected_href)
    expect(detail_link).to be_present
    expect(detail_link.text.squish).to eq("詳細")
    expect(detail_link["title"]).to eq("Cue Hook / 文書更新 / 失敗 の詳細を、検索条件とページを保って開く")
    expect(detail_link["aria-label"]).to eq("Cue Hook / 文書更新 / 失敗 の詳細を、検索条件とページを保って開く")
  end
end
