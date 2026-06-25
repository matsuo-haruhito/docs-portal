require "rails_helper"

RSpec.describe "Bounded history lists", type: :request do
  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.gsub(/[[:space:]]+/, " ").strip
  end

  it "limits document delivery log rows while preserving filter counts and visible scope" do
    company = create(:company)
    external_user = create(:user, :external, company:)
    other_user = create(:user, :external, company:)
    project = create(:project, code: "DLIMIT", name: "Delivery Limit Project")
    document = create(:document, project:, title: "Bounded Manual", slug: "bounded-manual", visibility_policy: :restricted_external)

    visible_logs = 51.times.map do |index|
      create(
        :document_delivery_log,
        project:,
        document:,
        sender: external_user,
        status: :sent,
        delivery_type: :portal_link,
        to_addresses: "bounded-#{index.to_s.rjust(2, "0")}@example.com"
      )
    end
    create(:document_delivery_log, project:, document:, sender: external_user, status: :draft, delivery_type: :portal_link, to_addresses: "draft-visible@example.com")
    other_log = create(:document_delivery_log, project:, document:, sender: other_user, status: :sent, delivery_type: :portal_link, to_addresses: "other-user@example.com")

    sign_in_as(external_user)

    get document_delivery_logs_path, params: { status: :sent, delivery_type: :portal_link }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示範囲: 51件中50件を表示しています")
    expect(page_text).to include("さらに絞り込む場合は検索・状態・方式フィルタを使ってください")
    expect(response.body).to include("送付済み (51)")
    expect(response.body).to include("下書き (1)")
    expect(page_text).to include(visible_logs.last.to_addresses)
    expect(page_text).not_to include(visible_logs.first.to_addresses)
    expect(page_text).not_to include("draft-visible@example.com")
    expect(page_text).not_to include(other_log.to_addresses)
  end

  it "shows the filtered webhook delivery range for the recent history limit" do
    admin_user = create(:user, :internal)
    endpoint = create(:webhook_endpoint, name: "Bounded Hook", event_types: %w[document_updated])
    event = create(:notification_event, event_type: :document_updated)

    failed_deliveries = 51.times.map do |index|
      create(
        :webhook_delivery,
        webhook_endpoint: endpoint,
        notification_event: event,
        event_type: "document_updated",
        status: :failed,
        error_message: "bounded failure #{index.to_s.rjust(2, "0")}"
      )
    end
    succeeded_delivery = create(
      :webhook_delivery,
      webhook_endpoint: endpoint,
      notification_event: event,
      event_type: "document_updated",
      status: :succeeded,
      response_status: 200,
      error_message: "success should be hidden"
    )

    sign_in_as(admin_user)

    get admin_webhook_endpoints_path(delivery_status: "failed")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("直近の送信履歴に失敗が51件あります")
    expect(page_text).to include("表示範囲: 失敗のみ 51件中50件を表示しています")
    expect(page_text).to include("50件より前の履歴は、送信履歴検索でWebhook設定・イベント・ステータス・作成日を指定して確認できます。")
    expect(page_text).not_to include("後続 slice")
    expect(page_text).not_to include("endpoint / event / status / 作成日")
    expect(page_text).to include(failed_deliveries.last.error_message)
    expect(page_text).not_to include(failed_deliveries.first.error_message)
    expect(page_text).not_to include(succeeded_delivery.error_message)
  end
end
