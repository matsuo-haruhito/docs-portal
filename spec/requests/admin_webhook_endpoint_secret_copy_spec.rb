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
    expect(page_text).to include("設定すると送信時にHMAC-SHA256署名を付けます。編集時に空欄で保存すると既存値を維持し、入力した場合だけ更新します。")
  end

  it "explains that blank edits keep the existing secret" do
    sign_in_as(admin_user)
    endpoint = create(:webhook_endpoint, secret_token: "stored-secret")

    get edit_admin_webhook_endpoint_path(endpoint.public_id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("設定済み（変更する場合だけ入力）")
    expect(page_text).to include("設定すると送信時にHMAC-SHA256署名を付けます。編集時に空欄で保存すると既存値を維持し、入力した場合だけ更新します。")
    expect(page_text).not_to include("stored-secret")
  end
end
