require "rails_helper"

RSpec.describe "Admin webhook endpoint search cue", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "shows endpoint search target and max length without changing delivery filter guidance" do
    sign_in_as(admin_user)

    create(:webhook_endpoint, name: "Docs Hook", target_url: "https://hooks.example.test/docs")
    normalized_query = "x" * Admin::WebhookEndpointsController::ENDPOINT_Q_MAX_LENGTH
    long_query = "  #{normalized_query}ignored-suffix  "

    get admin_webhook_endpoints_path(endpoint_q: long_query)

    expect(response).to have_http_status(:ok)
    endpoint_q_input = parsed_html.at_css(%(input[name="endpoint_q"]))

    expect(endpoint_q_input["value"]).to eq(normalized_query)
    expect(endpoint_q_input["maxlength"]).to eq(Admin::WebhookEndpointsController::ENDPOINT_Q_MAX_LENGTH.to_s)
    expect(page_text).to include("名称または送信先URLを部分一致で検索します。入力できるのは100文字までです。")
    expect(page_text).to include("ここでの絞り込みは設定一覧だけに適用され、送信履歴や再送条件には影響しません。")
  end
end
