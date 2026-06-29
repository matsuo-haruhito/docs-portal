require "rails_helper"
require "csv"

RSpec.describe "Document delivery logs CSV", type: :request do
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:other_external_user) { create(:user, :external, company:) }
  let(:internal_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "DLV1", name: "Delivery Project") }
  let(:document) { create(:document, project:, title: "Shared Manual", slug: "shared-manual", visibility_policy: :restricted_external) }

  def csv_rows
    CSV.parse(response.body, headers: true)
  end

  def csv_text
    response.body
  end

  def create_delivery_log_at(created_at, attributes = {})
    create(
      :document_delivery_log,
      {
        project:,
        document:,
        sender: external_user,
        status: :failed,
        delivery_type: :portal_link,
        to_addresses: "recipient@example.com",
        subject: "CSV needle",
        error_message: "CSV failure"
      }.merge(attributes)
    ).tap do |log|
      log.update_columns(created_at:, updated_at: created_at)
    end
  end

  it "exports fixed columns using the same filter and sender scope as the list" do
    matching_log = create_delivery_log_at(
      Time.zone.local(2026, 1, 15, 12, 0, 0),
      to_addresses: "client@example.com",
      cc_addresses: "cc@example.com",
      bcc_addresses: "bcc@example.com",
      subject: "CSV needle for customer",
      error_message: "timeout while sending CSV needle with token=secret-value and a long explanation that should be shortened in the export"
    )
    outside_status_log = create_delivery_log_at(
      Time.zone.local(2026, 1, 15, 12, 0, 0),
      status: :sent,
      sent_at: Time.zone.local(2026, 1, 15, 13, 0, 0),
      to_addresses: "sent@example.com",
      subject: "CSV needle for customer",
      error_message: nil
    )
    other_sender_log = create_delivery_log_at(
      Time.zone.local(2026, 1, 15, 12, 0, 0),
      sender: other_external_user,
      to_addresses: "other-sender@example.com",
      subject: "CSV needle for customer"
    )

    sign_in_as(external_user)

    get document_delivery_logs_path(format: :csv), params: {
      q: "CSV needle",
      status: :failed,
      delivery_type: :portal_link,
      created_from: "2026-01-10",
      created_to: "2026-01-20"
    }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(csv_rows.headers).to eq([
      "作成日時",
      "送信日時",
      "案件コード",
      "案件名",
      "対象種別",
      "対象名",
      "To",
      "CC",
      "BCC",
      "方式",
      "状態",
      "失敗理由"
    ])
    expect(csv_rows.size).to eq(1)

    row = csv_rows.first
    expect(row["案件コード"]).to eq("DLV1")
    expect(row["案件名"]).to eq("Delivery Project")
    expect(row["対象種別"]).to eq("文書")
    expect(row["対象名"]).to eq("Shared Manual")
    expect(row["To"]).to eq(matching_log.to_addresses)
    expect(row["CC"]).to eq(matching_log.cc_addresses)
    expect(row["BCC"]).to eq(matching_log.bcc_addresses)
    expect(row["方式"]).to eq(I18n.t("labels.document_delivery_logs.delivery_type.portal_link"))
    expect(row["状態"]).to eq(I18n.t("labels.document_delivery_logs.status.failed"))
    expect(row["失敗理由"]).to include("timeout while sending CSV needle")
    expect(row["失敗理由"].length).to be <= 83
    expect(csv_text).not_to include(outside_status_log.to_addresses)
    expect(csv_text).not_to include(other_sender_log.to_addresses)
  end

  it "applies sent date, status, and delivery type filters for internal users" do
    matching_log = create_delivery_log_at(
      Time.zone.local(2026, 2, 10, 9, 0, 0),
      status: :sent,
      delivery_type: :attachment,
      sent_at: Time.zone.local(2026, 2, 15, 10, 0, 0),
      to_addresses: "sent-hit@example.com",
      subject: "Monthly package",
      error_message: nil
    )
    outside_sent_date_log = create_delivery_log_at(
      Time.zone.local(2026, 2, 10, 9, 0, 0),
      status: :sent,
      delivery_type: :attachment,
      sent_at: Time.zone.local(2026, 2, 1, 10, 0, 0),
      to_addresses: "sent-outside@example.com",
      subject: "Monthly package",
      error_message: nil
    )
    wrong_type_log = create_delivery_log_at(
      Time.zone.local(2026, 2, 10, 9, 0, 0),
      status: :sent,
      delivery_type: :portal_link,
      sent_at: Time.zone.local(2026, 2, 15, 10, 0, 0),
      to_addresses: "wrong-type@example.com",
      subject: "Monthly package",
      error_message: nil
    )

    sign_in_as(internal_user)

    get document_delivery_logs_path(format: :csv), params: {
      q: "Monthly package",
      status: :sent,
      delivery_type: :attachment,
      sent_from: "2026-02-10",
      sent_to: "2026-02-20"
    }

    expect(response).to have_http_status(:ok)
    expect(csv_rows.size).to eq(1)
    expect(csv_rows.first["To"]).to eq(matching_log.to_addresses)
    expect(csv_rows.first["失敗理由"]).to be_nil
    expect(csv_text).not_to include(outside_sent_date_log.to_addresses)
    expect(csv_text).not_to include(wrong_type_log.to_addresses)
  end

  it "limits CSV export to the latest display limit and keeps table preferences out of CSV columns" do
    51.times do |index|
      create_delivery_log_at(
        Time.zone.local(2026, 3, 1, 0, index, 0),
        to_addresses: "limit-#{index}@example.com",
        subject: "Limit needle"
      )
    end

    sign_in_as(internal_user)

    get document_delivery_logs_path(format: :csv), params: { q: "Limit needle" }

    expect(response).to have_http_status(:ok)
    expect(csv_rows.size).to eq(DocumentDeliveryLogsController::DELIVERY_LOG_DISPLAY_LIMIT)
    expect(csv_text).to include("limit-50@example.com")
    expect(csv_text).not_to include("limit-0@example.com")
    expect(csv_rows.headers).not_to include("rails_table_preferences", "表示設定")
  end

  it "links to CSV export from the filtered HTML list without including the current page" do
    create_delivery_log_at(Time.zone.local(2026, 4, 1, 12, 0, 0), subject: "Link needle")

    sign_in_as(internal_user)

    get document_delivery_logs_path, params: {
      q: "Link needle",
      status: :failed,
      delivery_type: :portal_link,
      created_from: "2026-04-01",
      created_to: "2026-04-30",
      page: 2
    }

    expect(response).to have_http_status(:ok)
    html = Nokogiri::HTML(response.body)
    csv_link = html.css("a[href]").find { |node| node.text.strip == "CSV出力" }
    expect(csv_link["href"]).to eq(document_delivery_logs_path(
      q: "Link needle",
      created_from: "2026-04-01",
      created_to: "2026-04-30",
      status: :failed,
      delivery_type: :portal_link,
      format: :csv
    ))
    expect(html.text.squish).to include("現在の絞り込み条件に一致する最新50件を固定列で出力します。表示設定はCSV列に影響しません。")
  end
end
