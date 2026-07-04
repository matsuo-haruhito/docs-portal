require "rails_helper"

RSpec.describe Admin::WebhookEndpointsHelper, type: :helper do
  describe "#webhook_endpoint_display_target_url" do
    it "keeps host and path while hiding query parameter names and values" do
      display_url = helper.webhook_endpoint_display_target_url(
        "https://hooks.example.test/docs/events?token=secret-value&signature=abc123"
      )

      expect(display_url).to eq("https://hooks.example.test/docs/events?...")
      expect(display_url).not_to include("token")
      expect(display_url).not_to include("secret-value")
      expect(display_url).not_to include("signature")
      expect(display_url).not_to include("abc123")
    end

    it "keeps non-default ports and falls back to slash for root paths" do
      expect(helper.webhook_endpoint_display_target_url("https://hooks.example.test:8443?token=secret")).to eq(
        "https://hooks.example.test:8443/?..."
      )
    end

    it "does not expose query-looking suffixes for unparseable values" do
      display_url = helper.webhook_endpoint_display_target_url("not a url?token=secret-value&signature=abc123")

      expect(display_url).to eq("not a url?...")
      expect(display_url).not_to include("secret-value")
      expect(display_url).not_to include("signature")
    end
  end

  describe "#webhook_endpoint_delete_confirm_message" do
    it "keeps endpoint details and clarifies delete scope" do
      endpoint = double(
        name: "停止中 Hook",
        target_url: "https://hooks.example.test/docs?token=secret",
        normalized_event_types: [],
        active?: false
      )

      message = helper.webhook_endpoint_delete_confirm_message(endpoint)

      expect(message).to include("Webhook設定を削除します。")
      expect(message).to include("名称: 停止中 Hook")
      expect(message).to include("送信先URL: https://hooks.example.test/docs?...")
      expect(message).to include("イベント: -")
      expect(message).to include("状態: 停止")
      expect(message).to include("停止ではなく設定削除の操作です。")
      expect(message).to include("この設定に紐づく送信履歴も削除対象になります。")
      expect(message).to include("以後この通知先へWebhookは送信されません。削除しますか？")
    end
  end
end
