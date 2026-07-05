# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin webhook delivery detail link labels", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def detail_links
    parsed_html.css("a[aria-label]").select { |link| link.text.squish == "詳細" }
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

  it "uses row-specific accessible labels for matching endpoint event and status rows" do
    sign_in_as(admin_user)

    event = create(:notification_event, event_type: :document_updated)
    endpoint = create(:webhook_endpoint, name: "Alpha Hook")
    first_delivery = create_delivery(
      endpoint: endpoint,
      event: event,
      status: :failed,
      response_status: 500,
      created_at: Time.zone.local(2026, 6, 10, 10, 0, 0)
    )
    second_delivery = create_delivery(
      endpoint: endpoint,
      event: event,
      status: :failed,
      response_status: 500,
      created_at: Time.zone.local(2026, 6, 10, 9, 0, 0)
    )

    get admin_webhook_deliveries_path(status: "failed")

    expect(response).to have_http_status(:ok)

    labels = detail_links.map { |link| link["aria-label"] }
    titles = detail_links.map { |link| link["title"] }
    hrefs = detail_links.map { |link| link["href"] }

    expect(labels).to contain_exactly(
      a_string_including("Alpha Hook", "文書更新", "失敗", "HTTP 500", "履歴ID #{first_delivery.public_id.first(8)}", "検索条件とページを保って開く"),
      a_string_including("Alpha Hook", "文書更新", "失敗", "HTTP 500", "履歴ID #{second_delivery.public_id.first(8)}", "検索条件とページを保って開く")
    )
    expect(labels).to all(include("作成日時"))
    expect(labels.uniq.size).to eq(2)
    expect(titles).to eq(labels)
    expect(labels.join).not_to include("hooks.example")
    expect(hrefs).to include(
      admin_webhook_delivery_path(
        first_delivery.public_id,
        status: "failed",
        return_context: "deliveries_index"
      ),
      admin_webhook_delivery_path(
        second_delivery.public_id,
        status: "failed",
        return_context: "deliveries_index"
      )
    )
  end
end
