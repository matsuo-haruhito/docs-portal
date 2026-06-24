require "rails_helper"

RSpec.describe "Admin dashboard document delivery failure alerts", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "DLV1", name: "Delivery Project") }
  let(:document) { create(:document, project:) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def delivery_card
    parsed_html.css("article.metric-card").find { |card| card.at_css("h3")&.text&.squish == "外部送付履歴" }
  end

  def delivery_link(label)
    delivery_card.css("a").find { |link| link.text.squish == label }
  end

  def create_delivery_log(status:, created_at:, subject: "Document delivery", to_addresses: "client@example.com", error_message: "boom")
    create(
      :document_delivery_log,
      project: project,
      document: document,
      sender: admin_user,
      status: status,
      delivery_type: :portal_link,
      to_addresses: to_addresses,
      subject: subject,
      error_message: status.to_sym == :failed ? error_message : nil
    ).tap do |log|
      log.update_columns(created_at: created_at, updated_at: created_at)
    end
  end

  it "shows read-only document delivery failure handoff candidates with safe previews" do
    latest_failed_at = 30.minutes.ago.change(usec: 0)
    create_delivery_log(
      status: :failed,
      created_at: latest_failed_at,
      subject: "Quarterly delivery secret=subject-raw",
      to_addresses: "client@example.com",
      error_message: "Authorization: Bearer bearer-raw token=token-raw secret=secret-raw"
    )
    create_delivery_log(status: :failed, created_at: 45.minutes.ago, subject: "Quarterly delivery secret=subject-raw", to_addresses: "client@example.com")
    create_delivery_log(status: :failed, created_at: 1.hour.ago, subject: "Quarterly delivery secret=subject-raw", to_addresses: "client@example.com")

    create_delivery_log(status: :sent, created_at: 5.minutes.ago, subject: "Recovered delivery")
    3.times do |index|
      create_delivery_log(status: :failed, created_at: 2.hours.ago - index.minutes, subject: "Recovered delivery", error_message: "resolved failure")
    end

    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(delivery_card).to be_present

    card_text = delivery_card.text.squish
    expect(card_text).to include("保存済み送付履歴の failed 件数")
    expect(card_text).to include("failed: 6")
    expect(card_text).to include("継続失敗候補: 1 件")
    expect(card_text).to include("既存の外部送付履歴 handoff payload")
    expect(card_text).to include("DLV1 Delivery Project")
    expect(card_text).to include("送付方式: portal_link / 連続失敗: 3 件")
    expect(response.body).to include(I18n.l(latest_failed_at, format: :short))
    expect(card_text).to include("宛先: client@example.com")
    expect(card_text).to include("件名: Quarterly delivery secret=[FILTERED]")
    expect(card_text).to include("エラー: Authorization: Bearer [FILTERED]")
    expect(card_text).to include("token=[FILTERED]")
    expect(card_text).to include("secret=[FILTERED]")
    expect(card_text).not_to include("Recovered delivery")
    expect(card_text).not_to include("resolved failure")

    candidate_link = delivery_link("この候補の failed 送付履歴")
    expect(candidate_link).to be_present
    candidate_uri = URI.parse(candidate_link["href"])
    candidate_params = Rack::Utils.parse_nested_query(candidate_uri.query)
    expect(candidate_uri.path).to eq(document_delivery_logs_path)
    expect(candidate_params).to include("status" => "failed", "delivery_type" => "portal_link")
    expect(candidate_params.fetch("q")).to include("[FILTERED]")

    expect(delivery_link("外部送付履歴の failed 一覧をすべて見る")["href"]).to eq(document_delivery_logs_path(status: "failed"))
    expect(delivery_link("継続失敗候補 runbook")["href"]).to include(DocumentDeliveryLogs::FailureAlertHandoff::RUNBOOK_PATH)

    expect(response.body).not_to include("subject-raw")
    expect(response.body).not_to include("bearer-raw")
    expect(response.body).not_to include("token-raw")
    expect(response.body).not_to include("secret-raw")
  end

  it "shows an empty document delivery candidate message without implying healthy monitoring" do
    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(delivery_card).to be_present

    card_text = delivery_card.text.squish
    expect(card_text).to include("継続失敗候補: 0 件")
    expect(card_text).to include("current 条件で外部送付履歴の handoff 候補はありません。")
    expect(card_text).to include("mail 全体正常、外部監視 green、通知正常を意味しません。")
    expect(delivery_link("外部送付履歴を確認")["href"]).to eq(document_delivery_logs_path(status: "failed"))
  end

  it "calls document delivery handoff with a bounded dashboard query window" do
    handoff_service = instance_double(DocumentDeliveryLogs::FailureAlertHandoff, call: [])
    expect(DocumentDeliveryLogs::FailureAlertHandoff).to receive(:new).with(
      limit: Admin::DashboardController::DOCUMENT_DELIVERY_ALERT_CANDIDATE_LIMIT,
      lookback_limit: Admin::DashboardController::DOCUMENT_DELIVERY_ALERT_CANDIDATE_LOOKBACK_LIMIT
    ).and_return(handoff_service)

    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("外部送付履歴")
  end
end
