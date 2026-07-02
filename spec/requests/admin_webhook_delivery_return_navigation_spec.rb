require "rails_helper"
require "uri"

RSpec.describe "Admin webhook delivery return navigation", type: :request do
  let(:user) { create(:user, :internal) }
  let(:endpoint) { create(:webhook_endpoint, name: "Billing Webhook") }
  let(:delivery) do
    create(
      :webhook_delivery,
      webhook_endpoint: endpoint,
      status: :failed,
      response_status: 500,
      error_message: "timeout while posting"
    )
  end

  before do
    sign_in_as(user)
  end

  it "explains that the delivery search return link keeps filters and page" do
    get admin_webhook_delivery_path(
      delivery.public_id,
      return_context: "deliveries_index",
      status: "failed",
      event_type: "document_updated",
      webhook_endpoint_id: endpoint.id,
      response_status: "500",
      error_q: "timeout",
      created_from: "2026-06-01",
      created_to: "2026-06-30",
      page: "2"
    )

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("送信履歴検索へ戻る")
    expect(response.body).to include("検索条件とページを保った送信履歴検索へ戻ります。")

    return_link = Nokogiri::HTML(response.body).at_css("p.actions a")
    expect(return_link.text).to eq("送信履歴検索へ戻る")
    expect(URI.parse(return_link["href"]).path).to eq(admin_webhook_deliveries_path)

    query = Rack::Utils.parse_nested_query(URI.parse(return_link["href"]).query)
    expect(query).to include(
      "status" => "failed",
      "event_type" => "document_updated",
      "webhook_endpoint_id" => endpoint.id.to_s,
      "response_status" => "500",
      "error_q" => "timeout",
      "created_from" => "2026-06-01",
      "created_to" => "2026-06-30",
      "page" => "2"
    )
  end

  it "keeps the webhook endpoint return link distinct from search results" do
    get admin_webhook_delivery_path(delivery.public_id, return_delivery_status: "failed")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Webhook一覧へ戻る")
    expect(response.body).not_to include("検索条件とページを保った送信履歴検索へ戻ります。")

    return_link = Nokogiri::HTML(response.body).at_css("p.actions a")
    expect(return_link.text).to eq("Webhook一覧へ戻る")
    expect(return_link["href"]).to eq(admin_webhook_endpoints_path(delivery_status: "failed"))
  end
end
