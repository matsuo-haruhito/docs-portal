require "rails_helper"

RSpec.describe "Admin webhook endpoint filter reset cue", type: :request do
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

  it "keeps delivery filters when endpoint filter results are empty" do
    sign_in_as(admin_user)

    endpoint = create(:webhook_endpoint, name: "Docs Hook", event_types: %w[document_updated], active: true)
    create(:webhook_delivery, webhook_endpoint: endpoint, status: :failed)

    get admin_webhook_endpoints_path(endpoint_q: "missing hook", delivery_status: "failed")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致するWebhook設定はありません。")
    expect(page_text).to include("Webhook設定の条件だけを解除し、最近の送信履歴検索や再送条件は変更しません。")
    expect(action_targets).to include(admin_webhook_endpoints_path(delivery_status: "failed"))
    expect(action_targets).not_to include(admin_webhook_endpoints_path(endpoint_q: "missing hook", delivery_status: "failed"))
  end

  it "does not show a reset cue on the initial empty endpoint list" do
    sign_in_as(admin_user)

    get admin_webhook_endpoints_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("まだWebhook設定は登録されていません。")
    expect(page_text).not_to include("Webhook設定の条件をリセット")
  end
end
