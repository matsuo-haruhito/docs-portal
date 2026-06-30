require "rails_helper"

RSpec.describe "Admin webhook bulk redelivery confirmation", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def bulk_retry_path
    retry_failed_admin_webhook_deliveries_path(delivery_status: "failed")
  end

  def bulk_retry_form
    parsed_html.at_css(%(form[action="#{bulk_retry_path}"]))
  end

  it "shows confirmation copy for retryable failed deliveries only on the failed filter" do
    sign_in_as(admin_user)

    active_endpoint = create(:webhook_endpoint, name: "Active Hook", active: true)
    inactive_endpoint = create(:webhook_endpoint, name: "Stopped Hook", active: false)
    event = create(:notification_event, event_type: :document_updated)
    create(:webhook_delivery, webhook_endpoint: active_endpoint, notification_event: event, event_type: "document_updated", status: :failed)
    create(:webhook_delivery, webhook_endpoint: inactive_endpoint, notification_event: event, event_type: "document_updated", status: :failed)

    get admin_webhook_endpoints_path

    expect(response).to have_http_status(:ok)
    expect(bulk_retry_form).to be_nil

    get admin_webhook_endpoints_path(delivery_status: "failed")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中のまとめて再送対象: 1件")
    expect(page_text).to include("設定: Active Hook")
    expect(page_text).to include("イベント: 文書更新")
    expect(page_text).to include("表示範囲: 失敗のみ 2件中2件を表示しています")

    form = bulk_retry_form
    expect(form).to be_present
    expect(form["data-turbo-confirm"]).to include("表示中の失敗Webhookのうち再送可能な1件")
    expect(form["data-turbo-confirm"]).to include("受信先側の重複処理に注意してください")
    expect(form.at_css(%(button[type="submit"])).text.squish).to eq("表示中の失敗Webhookをまとめて再送")
  end

  it "shows the no-retryable cue instead of the bulk confirmation when every failed delivery is stopped" do
    sign_in_as(admin_user)

    inactive_endpoint = create(:webhook_endpoint, name: "Stopped Hook", active: false)
    event = create(:notification_event, event_type: :document_updated)
    create(:webhook_delivery, webhook_endpoint: inactive_endpoint, notification_event: event, event_type: "document_updated", status: :failed)

    get admin_webhook_endpoints_path(delivery_status: "failed")

    expect(response).to have_http_status(:ok)
    expect(bulk_retry_form).to be_nil
    expect(page_text).to include("再送可能なWebhook送信履歴はありません")
    expect(page_text).to include("停止中のWebhook設定はまとめて再送の対象外です")
  end
end
