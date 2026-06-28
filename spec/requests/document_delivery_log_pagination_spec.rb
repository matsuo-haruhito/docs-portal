require "rails_helper"

RSpec.describe "Document delivery log pagination", type: :request do
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:other_external_user) { create(:user, :external, company:) }
  let(:internal_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "DLV1", name: "Delivery Project") }
  let(:document) { create(:document, project:, title: "Shared Manual", slug: "shared-manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.gsub(/[[:space:]]+/, " ").strip
  end

  def href_for(text)
    parsed_html.css("a[href]").find { |node| node.text.strip == text }&.[]("href")
  end

  def href_for_row_containing(row_text, link_text)
    row = parsed_html.css("tr").find { |node| node.text.include?(row_text) }
    row&.css("a[href]")&.find { |node| node.text.strip == link_text }&.[]("href")
  end

  def query_params_for(text)
    href = href_for(text)
    expect(href).to be_present

    Rack::Utils.parse_nested_query(URI.parse(href).query)
  end

  def localized_status_label(status)
    I18n.t("labels.document_delivery_logs.status.#{status}", default: status.to_s)
  end

  def create_delivery_log_at(created_at, attributes = {})
    sent_at = attributes.key?(:sent_at) ? attributes[:sent_at] : created_at + 1.minute

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
        sent_at: sent_at
      }.merge(attributes)
    ).tap do |log|
      log.update_columns(created_at:, updated_at: created_at, sent_at: sent_at)
    end
  end

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: external_user)
    create(:project_membership, project:, user: other_external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "moves between bounded pages and preserves the current page in detail return links" do
    51.times do |index|
      create_delivery_log_at(
        Time.zone.local(2026, 1, 1, 9, 0, 0) + index.minutes,
        to_addresses: "paged-#{index.to_s.rjust(2, '0')}@example.com"
      )
    end

    sign_in_as(internal_user)

    get document_delivery_logs_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示範囲: 51件中50件を表示しています。現在のページ: 1-50件。1ページあたり最大50件です。")
    expect(page_text).to include("paged-50@example.com")
    expect(page_text).not_to include("paged-00@example.com")
    expect(query_params_for("次へ")).to include("page" => "2")
    expect(href_for("前へ")).to be_nil

    get document_delivery_logs_path, params: { page: 2 }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示範囲: 51件中1件を表示しています。現在のページ: 51-51件。1ページあたり最大50件です。")
    expect(page_text).to include("2 / 2ページ")
    expect(page_text).to include("paged-00@example.com")
    expect(page_text).not_to include("paged-50@example.com")
    expect(query_params_for("前へ")).to include("page" => "1")
    expect(href_for("次へ")).to be_nil

    detail_href = href_for_row_containing("paged-00@example.com", localized_status_label(:sent))
    expect(detail_href).to eq(document_delivery_log_path(DocumentDeliveryLog.find_by!(to_addresses: "paged-00@example.com"), return_to: document_delivery_logs_path(page: 2)))
  end

  it "keeps query, date, status, and delivery type filters while moving to the next page" do
    55.times do |index|
      created_at = Time.zone.local(2026, 1, 15, 9, 0, 0) + index.minutes
      create_delivery_log_at(
        created_at,
        status: :failed,
        delivery_type: :zip_attachment,
        to_addresses: "filter-#{index.to_s.rjust(2, '0')}@example.com",
        subject: "Needle delivery",
        sent_at: Time.zone.local(2026, 1, 16, 10, 0, 0) + index.minutes
      )
    end
    create_delivery_log_at(Time.zone.local(2026, 1, 15, 11, 0, 0), status: :sent, delivery_type: :zip_attachment, to_addresses: "wrong-status@example.com", subject: "Needle delivery")
    create_delivery_log_at(Time.zone.local(2026, 1, 15, 12, 0, 0), status: :failed, delivery_type: :portal_link, to_addresses: "wrong-type@example.com", subject: "Needle delivery")

    sign_in_as(internal_user)

    filter_params = {
      q: "Needle",
      status: :failed,
      delivery_type: :zip_attachment,
      created_from: "2026-01-15",
      created_to: "2026-01-15",
      sent_from: "2026-01-16",
      sent_to: "2026-01-16"
    }

    get document_delivery_logs_path, params: filter_params

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示範囲: 55件中50件を表示しています。現在のページ: 1-50件。1ページあたり最大50件です。")
    expect(page_text).to include("filter-54@example.com")
    expect(page_text).not_to include("filter-00@example.com")
    expect(page_text).not_to include("wrong-status@example.com")
    expect(page_text).not_to include("wrong-type@example.com")
    expect(query_params_for("次へ")).to include(
      "q" => "Needle",
      "status" => "failed",
      "delivery_type" => "zip_attachment",
      "created_from" => "2026-01-15",
      "created_to" => "2026-01-15",
      "sent_from" => "2026-01-16",
      "sent_to" => "2026-01-16",
      "page" => "2"
    )

    get document_delivery_logs_path, params: filter_params.merge(page: 2)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示範囲: 55件中5件を表示しています。現在のページ: 51-55件。1ページあたり最大50件です。")
    expect(page_text).to include("filter-00@example.com")
    expect(page_text).not_to include("filter-54@example.com")
    expect(page_text).to include("表示件数はこの条件に一致した履歴のうち、現在のページに表示している件数です。")
  end

  it "keeps external users scoped to their own delivery logs on later pages" do
    55.times do |index|
      created_at = Time.zone.local(2026, 2, 1, 9, 0, 0) + index.minutes
      create_delivery_log_at(created_at, to_addresses: "own-#{index.to_s.rjust(2, '0')}@example.com")
      create_delivery_log_at(created_at, sender: other_external_user, to_addresses: "other-#{index.to_s.rjust(2, '0')}@example.com")
    end

    sign_in_as(external_user)

    get document_delivery_logs_path, params: { page: 2 }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示範囲: 55件中5件を表示しています。現在のページ: 51-55件。1ページあたり最大50件です。")
    expect(page_text).to include("own-00@example.com")
    expect(page_text).not_to include("other-00@example.com")
    expect(page_text).not_to include("other-54@example.com")
  end

  it "falls invalid and out-of-range pages back to a valid bounded page" do
    51.times do |index|
      create_delivery_log_at(
        Time.zone.local(2026, 3, 1, 9, 0, 0) + index.minutes,
        to_addresses: "invalid-page-#{index.to_s.rjust(2, '0')}@example.com"
      )
    end

    sign_in_as(internal_user)

    get document_delivery_logs_path, params: { page: "bad" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示範囲: 51件中50件を表示しています。現在のページ: 1-50件。1ページあたり最大50件です。")
    expect(page_text).to include("invalid-page-50@example.com")
    expect(page_text).not_to include("invalid-page-00@example.com")

    get document_delivery_logs_path, params: { page: 99 }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示範囲: 51件中1件を表示しています。現在のページ: 51-51件。1ページあたり最大50件です。")
    expect(page_text).to include("invalid-page-00@example.com")
  end
end
