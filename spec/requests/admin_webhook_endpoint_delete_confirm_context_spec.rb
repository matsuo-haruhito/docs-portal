require "rails_helper"

RSpec.describe "Admin webhook endpoint delete confirm context", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  it "includes endpoint identity details in the destructive delete confirmation" do
    endpoint = create(
      :webhook_endpoint,
      name: "Docs release hook",
      target_url: "https://hooks.example.test/incoming/docs-release?token=raw-secret&team=docs",
      event_types: %w[document_updated import_failed],
      active: false
    )

    sign_in_as(admin_user)

    get admin_webhook_endpoints_path

    expect(response).to have_http_status(:ok)

    delete_form = parsed_html.at_css(%(form[action="#{admin_webhook_endpoint_path(endpoint)}"][data-turbo-confirm]))
    expect(delete_form).to be_present
    expect(delete_form.at_css(%(button[type="submit"])).text.squish).to eq("削除")

    confirm_copy = delete_form["data-turbo-confirm"]
    expect(confirm_copy).to include("Webhook設定を削除します。")
    expect(confirm_copy).to include("名称: Docs release hook")
    expect(confirm_copy).to include("送信先URL: https://hooks.example.test/incoming/docs-release?...")
    expect(confirm_copy).to include("イベント: 文書更新, インポート失敗")
    expect(confirm_copy).to include("状態: 停止")
    expect(confirm_copy).to include("以後この通知先へWebhookは送信されません。削除しますか？")
    expect(confirm_copy).not_to include("raw-secret")
    expect(confirm_copy).not_to include("team=docs")
  end
end
