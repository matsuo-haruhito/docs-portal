require "rails_helper"

RSpec.describe "Admin webhook endpoint secret copy", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def page_text
    Nokogiri::HTML(response.body).text.squish
  end

  it "explains the secret purpose on the new webhook endpoint form" do
    sign_in_as(admin_user)

    get admin_webhook_endpoints_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("任意で設定できます。設定すると、今後の送信に署名ヘッダーを付けて受信側で送信元を確認できます。")
    expect(page_text).to include("署名シークレットを設定すると、送信時に X-Docs-Portal-Signature-256 ヘッダーへ HMAC-SHA256 署名を付与します。")
  end

  it "explains that blank edits keep the existing secret" do
    sign_in_as(admin_user)
    endpoint = create(:webhook_endpoint, secret_token: "stored-secret")

    get edit_admin_webhook_endpoint_path(endpoint.public_id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("設定済み（変更する場合だけ入力）")
    expect(page_text).to include("空欄のまま保存すると既存の署名シークレットを維持します。値を入力した場合だけ、今後の送信署名に使うシークレットを更新します。")
    expect(page_text).to include("署名シークレットを設定すると、送信時に X-Docs-Portal-Signature-256 ヘッダーへ HMAC-SHA256 署名を付与します。")
    expect(page_text).not_to include("stored-secret")
  end
end
