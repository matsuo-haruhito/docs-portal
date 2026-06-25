require "rails_helper"

RSpec.describe "Admin webhook recent delivery empty states", type: :request do
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

  it "shows a nearby reset link only when a recent delivery status filter has no rows" do
    sign_in_as(admin_user)

    endpoint = create(:webhook_endpoint, name: "Success Hook")
    event = create(:notification_event, event_type: :document_updated)
    create(
      :webhook_delivery,
      webhook_endpoint: endpoint,
      notification_event: event,
      event_type: "document_updated",
      status: :succeeded
    )

    get admin_webhook_endpoints_path(delivery_status: "failed")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("失敗のみの送信履歴はありません")
    expect(page_text).to include("すべての送信履歴へ戻す")
    expect(action_targets).to include(admin_webhook_endpoints_path)

    get admin_webhook_endpoints_path

    expect(response).to have_http_status(:ok)
    expect(page_text).not_to include("すべての送信履歴へ戻す")
  end

  it "does not show the reset link when no recent deliveries exist at all" do
    sign_in_as(admin_user)

    get admin_webhook_endpoints_path(delivery_status: "failed")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("まだ送信履歴はありません")
    expect(page_text).not_to include("すべての送信履歴へ戻す")
  end
end
