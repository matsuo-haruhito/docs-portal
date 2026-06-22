require "rails_helper"

RSpec.describe "Admin webhook delivery empty state copy", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def page_text
    Nokogiri::HTML(response.body).text.squish
  end

  it "uses visible filter labels in the filtered empty state" do
    sign_in_as(admin_user)

    get admin_webhook_deliveries_path(status: "failed")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致するWebhook送信履歴はありません。")
    expect(page_text).to include("Webhook設定、イベント、ステータス、HTTP status、エラー断片、作成日の範囲を見直してください。")
    expect(page_text).not_to include("endpoint、event、status、HTTP status")
    expect(page_text).to include("すべてのWebhook送信履歴を見る")
  end
end
