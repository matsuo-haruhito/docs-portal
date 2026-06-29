require "rails_helper"

RSpec.describe "Admin webhook delivery empty state", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def endpoint_links
    parsed_html.css(%(a[href="#{admin_webhook_endpoints_path}"])).map { |link| link.text.squish }
  end

  it "points initial empty state back to webhook settings without replacing filtered reset" do
    sign_in_as(admin_user)

    get admin_webhook_deliveries_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("まだWebhook送信履歴はありません。")
    expect(page_text).to include("Webhook設定を登録し、通知対象イベントが発生すると送信履歴がここに表示されます。")
    expect(endpoint_links).to include("Webhook一覧へ戻る", "Webhook設定へ戻る")
    expect(page_text).not_to include("すべてのWebhook送信履歴を見る")

    get admin_webhook_deliveries_path(status: "failed")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致するWebhook送信履歴はありません。")
    expect(page_text).to include("すべてのWebhook送信履歴を見る")
    expect(page_text).not_to include("Webhook設定を登録し、通知対象イベントが発生すると送信履歴がここに表示されます。")
    expect(endpoint_links).to contain_exactly("Webhook一覧へ戻る")
  end
end
