require "rails_helper"

RSpec.describe "Admin webhook endpoint filters", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def action_targets
    parsed_html.css("a[href], form[action]").map do |node|
      node["href"] || node["action"]
    end
  end

  it "filters webhook endpoint settings by query, event, and active state" do
    sign_in_as(admin_user)

    matching_endpoint = create(
      :webhook_endpoint,
      name: "Docs Deploy Hook",
      target_url: "https://hooks.example.test/docs/deploy",
      event_types: %w[document_updated qa_answered],
      active: true
    )
    other_event_endpoint = create(
      :webhook_endpoint,
      name: "Docs Import Hook",
      target_url: "https://hooks.example.test/docs/import",
      event_types: %w[import_failed],
      active: true
    )
    inactive_endpoint = create(
      :webhook_endpoint,
      name: "Docs Stopped Hook",
      target_url: "https://hooks.example.test/docs/stopped",
      event_types: %w[document_updated],
      active: false
    )

    get admin_webhook_endpoints_path(
      endpoint_q: "docs",
      endpoint_event: "document_updated",
      endpoint_active: "active"
    )

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Docs Deploy Hook")
    expect(page_text).not_to include("Docs Import Hook")
    expect(page_text).not_to include("Docs Stopped Hook")
    expect(page_text).to include("表示範囲: Webhook設定 1件中1件を表示しています")
    expect(page_text).to include("設定検索・イベント・状態 filter は Webhook 設定一覧だけに適用されます")
    expect(action_targets).to include(edit_admin_webhook_endpoint_path(matching_endpoint.public_id))
    expect(action_targets).not_to include(edit_admin_webhook_endpoint_path(other_event_endpoint.public_id))
    expect(action_targets).not_to include(edit_admin_webhook_endpoint_path(inactive_endpoint.public_id))
  end

  it "uses bounded pagination and keeps endpoint filters in page links" do
    sign_in_as(admin_user)

    create(:webhook_endpoint, name: "Alpha Hook", event_types: %w[document_updated], active: true)
    create(:webhook_endpoint, name: "Beta Hook", event_types: %w[document_updated], active: true)
    create(:webhook_endpoint, name: "Gamma Hook", event_types: %w[document_updated], active: true)

    get admin_webhook_endpoints_path(
      endpoint_event: "document_updated",
      endpoint_active: "active",
      endpoint_per_page: "2"
    )

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Alpha Hook")
    expect(page_text).to include("Beta Hook")
    expect(page_text).not_to include("Gamma Hook")
    expect(page_text).to include("表示範囲: Webhook設定 3件中2件を表示しています")
    expect(action_targets.any? { |target| target.include?("endpoint_page=2") && target.include?("endpoint_event=document_updated") && target.include?("endpoint_active=active") && target.include?("endpoint_per_page=2") }).to be(true)

    get admin_webhook_endpoints_path(
      endpoint_event: "document_updated",
      endpoint_active: "active",
      endpoint_per_page: "2",
      endpoint_page: "2"
    )

    expect(response).to have_http_status(:ok)
    expect(page_text).not_to include("Alpha Hook")
    expect(page_text).not_to include("Beta Hook")
    expect(page_text).to include("Gamma Hook")
    expect(page_text).to include("2 / 2")
  end

  it "falls back safely for unsupported endpoint filter params" do
    sign_in_as(admin_user)

    create(:webhook_endpoint, name: "Active Hook", active: true, event_types: %w[document_updated])
    create(:webhook_endpoint, name: "Stopped Hook", active: false, event_types: %w[import_failed])

    get admin_webhook_endpoints_path(
      endpoint_event: "unsupported_event",
      endpoint_active: "https://evil.example.test",
      endpoint_page: "-4",
      endpoint_per_page: "999"
    )

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Active Hook")
    expect(page_text).to include("Stopped Hook")
    expect(page_text).to include("表示範囲: Webhook設定 2件中2件を表示しています")
    expect(page_text).not_to include("https://evil.example.test")
  end

  it "distinguishes empty filtered results from no registered endpoints" do
    sign_in_as(admin_user)

    get admin_webhook_endpoints_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("まだWebhook設定は登録されていません")
    expect(page_text).not_to include("条件に一致するWebhook設定はありません")

    create(:webhook_endpoint, name: "Existing Hook", target_url: "https://hooks.example.test/existing")

    get admin_webhook_endpoints_path(endpoint_q: "missing")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致するWebhook設定はありません")
    expect(page_text).not_to include("まだWebhook設定は登録されていません")
    expect(page_text).not_to include("Existing Hook")
  end
end
