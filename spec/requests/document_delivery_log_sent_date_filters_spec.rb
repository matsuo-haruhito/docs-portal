require "rails_helper"

RSpec.describe "Document delivery log sent date filters", type: :request do
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:other_external_user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "DLV1", name: "Delivery Project") }
  let(:document) { create(:document, project:, title: "Shared Manual", slug: "shared-manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.gsub(/[[:space:]]+/, " ").strip
  end

  def action_targets
    parsed_html.css("a[href], form[action]").map do |node|
      node["href"] || node["action"]
    end
  end

  def href_for(text)
    parsed_html.css("a[href]").find { |node| node.text.strip == text }&.[]("href")
  end

  def href_for_row_containing(row_text, link_text)
    row = parsed_html.css("tr").find { |node| node.text.include?(row_text) }
    row&.css("a[href]")&.find { |node| node.text.strip == link_text }&.[]("href")
  end

  def localized_status_label(status)
    I18n.t("labels.document_delivery_logs.status.#{status}", default: status.to_s)
  end

  def create_delivery_log_at(created_at, attributes = {})
    create(
      :document_delivery_log,
      {
        project:,
        document:,
        sender: external_user,
        status: :sent,
        delivery_type: :portal_link,
        to_addresses: "recipient@example.com",
        subject: "Delivery notice",
        sent_at: created_at
      }.merge(attributes)
    ).tap do |log|
      log.update_columns(created_at:, updated_at: created_at)
    end
  end

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: external_user)
    create(:project_membership, project:, user: other_external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "filters by sent date while preserving created date, status, delivery type, query, and sender scope" do
    matching_log = create_delivery_log_at(
      Time.zone.local(2026, 1, 15, 12, 0, 0),
      to_addresses: "sent-hit@example.com",
      subject: "Sent needle",
      sent_at: Time.zone.local(2026, 1, 12, 10, 30, 0)
    )
    outside_sent_date_log = create_delivery_log_at(
      Time.zone.local(2026, 1, 15, 12, 0, 0),
      to_addresses: "outside-sent-date@example.com",
      subject: "Sent needle",
      sent_at: Time.zone.local(2026, 1, 25, 10, 30, 0)
    )
    outside_created_date_log = create_delivery_log_at(
      Time.zone.local(2026, 2, 1, 12, 0, 0),
      to_addresses: "outside-created-date@example.com",
      subject: "Sent needle",
      sent_at: Time.zone.local(2026, 1, 12, 10, 30, 0)
    )
    wrong_type_log = create_delivery_log_at(
      Time.zone.local(2026, 1, 15, 12, 0, 0),
      delivery_type: :attachment,
      to_addresses: "wrong-type@example.com",
      subject: "Sent needle",
      sent_at: Time.zone.local(2026, 1, 12, 10, 30, 0)
    )
    blank_draft_log = create_delivery_log_at(
      Time.zone.local(2026, 1, 15, 12, 0, 0),
      status: :draft,
      to_addresses: "blank-draft@example.com",
      subject: "Sent needle",
      sent_at: nil
    )
    other_sender_log = create_delivery_log_at(
      Time.zone.local(2026, 1, 15, 12, 0, 0),
      sender: other_external_user,
      to_addresses: "other-sender@example.com",
      subject: "Sent needle",
      sent_at: Time.zone.local(2026, 1, 12, 10, 30, 0)
    )

    sign_in_as(external_user)

    get document_delivery_logs_path, params: {
      q: "Sent needle",
      status: :sent,
      delivery_type: :portal_link,
      created_from: "2026-01-01",
      created_to: "2026-01-31",
      sent_from: "2026-01-10",
      sent_to: "2026-01-20"
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("作成日", "送信日時")
    expect(page_text).to include(matching_log.to_addresses)
    expect(page_text).not_to include(outside_sent_date_log.to_addresses)
    expect(page_text).not_to include(outside_created_date_log.to_addresses)
    expect(page_text).not_to include(wrong_type_log.to_addresses)
    expect(page_text).not_to include(blank_draft_log.to_addresses)
    expect(page_text).not_to include(other_sender_log.to_addresses)
    expect(page_text).to include("表示範囲: 1件中1件を表示しています。")

    expect(action_targets).to include(
      document_delivery_logs_path(
        q: "Sent needle",
        created_from: "2026-01-01",
        created_to: "2026-01-31",
        sent_from: "2026-01-10",
        sent_to: "2026-01-20",
        status: :failed,
        delivery_type: :portal_link
      )
    )
    expect(action_targets).to include(
      document_delivery_logs_path(
        q: "Sent needle",
        created_from: "2026-01-01",
        created_to: "2026-01-31",
        sent_from: "2026-01-10",
        sent_to: "2026-01-20",
        status: :sent,
        delivery_type: :attachment
      )
    )
    expect(href_for("検索をクリア")).to eq(
      document_delivery_logs_path(
        status: :sent,
        delivery_type: :portal_link,
        created_from: "2026-01-01",
        created_to: "2026-01-31",
        sent_from: "2026-01-10",
        sent_to: "2026-01-20"
      )
    )
    expect(href_for("作成日をクリア")).to eq(
      document_delivery_logs_path(
        q: "Sent needle",
        status: :sent,
        delivery_type: :portal_link,
        sent_from: "2026-01-10",
        sent_to: "2026-01-20"
      )
    )
    expect(href_for("送信日時をクリア")).to eq(
      document_delivery_logs_path(
        q: "Sent needle",
        status: :sent,
        delivery_type: :portal_link,
        created_from: "2026-01-01",
        created_to: "2026-01-31"
      )
    )

    detail_href = href_for_row_containing(matching_log.to_addresses, localized_status_label(:sent))
    detail_params = Rack::Utils.parse_nested_query(URI.parse(detail_href).query)
    expect(detail_params["return_to"]).to eq(
      document_delivery_logs_path(
        q: "Sent needle",
        status: "sent",
        delivery_type: "portal_link",
        created_from: "2026-01-01",
        created_to: "2026-01-31",
        sent_from: "2026-01-10",
        sent_to: "2026-01-20"
      )
    )
    expect(detail_params).to include(
      "created_from" => "2026-01-01",
      "created_to" => "2026-01-31",
      "sent_from" => "2026-01-10",
      "sent_to" => "2026-01-20"
    )
  end

  it "supports open-ended sent date filters and ignores invalid sent dates safely" do
    old_log = create_delivery_log_at(
      Time.zone.local(2026, 1, 5, 12, 0, 0),
      to_addresses: "old-sent-date@example.com",
      sent_at: Time.zone.local(2026, 1, 5, 9, 0, 0)
    )
    middle_log = create_delivery_log_at(
      Time.zone.local(2026, 1, 15, 12, 0, 0),
      to_addresses: "middle-sent-date@example.com",
      sent_at: Time.zone.local(2026, 1, 15, 9, 0, 0)
    )
    future_log = create_delivery_log_at(
      Time.zone.local(2026, 1, 25, 12, 0, 0),
      to_addresses: "future-sent-date@example.com",
      sent_at: Time.zone.local(2026, 1, 25, 9, 0, 0)
    )
    blank_draft_log = create_delivery_log_at(
      Time.zone.local(2026, 1, 15, 12, 0, 0),
      status: :draft,
      to_addresses: "blank-sent-date@example.com",
      sent_at: nil
    )

    sign_in_as(external_user)

    get document_delivery_logs_path, params: { sent_from: "2026-01-10" }
    expect(response).to have_http_status(:ok)
    expect(page_text).to include(middle_log.to_addresses, future_log.to_addresses)
    expect(page_text).not_to include(old_log.to_addresses)
    expect(page_text).not_to include(blank_draft_log.to_addresses)

    get document_delivery_logs_path, params: { sent_to: "2026-01-20" }
    expect(response).to have_http_status(:ok)
    expect(page_text).to include(old_log.to_addresses, middle_log.to_addresses)
    expect(page_text).not_to include(future_log.to_addresses)
    expect(page_text).not_to include(blank_draft_log.to_addresses)

    get document_delivery_logs_path, params: { sent_from: "not-a-date", sent_to: "2026-01-20" }
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("送信日時は YYYY-MM-DD 形式で指定してください。無効な日付は絞り込みに使いません。")
    expect(page_text).to include(old_log.to_addresses, middle_log.to_addresses)
    expect(page_text).not_to include(future_log.to_addresses)
    expect(page_text).not_to include(blank_draft_log.to_addresses)

    get document_delivery_logs_path, params: { status: :draft, sent_from: "2026-01-01" }
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致する送付履歴はありません。")
    expect(page_text).not_to include(blank_draft_log.to_addresses)
  end
end
