require "rails_helper"

RSpec.describe "Admin webhook delivery empty summary", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "does not show a 0-0 range summary for the unfiltered empty state" do
    sign_in_as(admin_user)

    get admin_webhook_deliveries_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("まだWebhook送信履歴はありません。")
    expect(page_text).to include("この一覧は履歴を探して詳細へ進むための read-only 検索です。")
    expect(page_text).not_to include("表示範囲: 0件中0-0件")
    expect(parsed_html.css(%([data-rails-table-preferences-column-key]))).to be_empty
  end

  it "keeps the filtered empty copy without showing a 0-0 range summary" do
    sign_in_as(admin_user)

    get admin_webhook_deliveries_path(status: "failed", error_q: "timeout")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致するWebhook送信履歴はありません。")
    expect(page_text).to include("Webhook設定、イベント、ステータス、HTTP status、エラー断片、作成日の範囲を見直してください。")
    expect(page_text).not_to include("endpoint、event、status、HTTP status")
    expect(page_text).not_to include("表示範囲: 0件中0-0件")
    expect(parsed_html.at_css(%(a[href="#{admin_webhook_deliveries_path}"]))).to be_present
  end

  it "keeps the range summary when results are present" do
    sign_in_as(admin_user)
    create(:webhook_delivery, status: :failed, error_message: "timeout")

    get admin_webhook_deliveries_path(status: "failed", error_q: "timeout")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示範囲: 1件中1-1件を新しい順で表示しています")
    expect(page_text).not_to include("条件に一致するWebhook送信履歴はありません。")
  end
end
