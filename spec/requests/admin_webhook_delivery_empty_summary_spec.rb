require "rails_helper"

RSpec.describe "Admin webhook delivery empty summary", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "shows the zero range and initial empty guidance for the unfiltered state" do
    sign_in_as(admin_user)

    get admin_webhook_deliveries_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("まだWebhook送信履歴はありません。")
    expect(page_text).to include("Webhook設定を登録し、通知対象イベントが発生すると送信履歴がここに表示されます。")
    expect(page_text).to include("0–0 / 0件")
    expect(parsed_html.css(%([data-rails-table-preferences-column-key]))).to be_empty
  end

  it "keeps the filtered empty copy with the zero range" do
    sign_in_as(admin_user)

    get admin_webhook_deliveries_path(status: "failed", error_q: "timeout")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致するWebhook送信履歴はありません。")
    expect(page_text).to include("Webhook設定、イベント、状態、HTTPステータス、エラー断片、作成日の範囲を見直してください。")
    expect(page_text).not_to include("endpoint、event、status、HTTP status")
    expect(page_text).to include("0–0 / 0件")
    expect(parsed_html.at_css(%(a[href="#{admin_webhook_deliveries_path}"]))).to be_present
  end

  it "keeps the range summary when results are present" do
    sign_in_as(admin_user)
    create(:webhook_delivery, status: :failed, error_message: "timeout")

    get admin_webhook_deliveries_path(status: "failed", error_q: "timeout")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("1–1 / 1件")
    expect(page_text).not_to include("条件に一致するWebhook送信履歴はありません。")
  end
end
