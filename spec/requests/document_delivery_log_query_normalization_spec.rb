require "rails_helper"

RSpec.describe "Document delivery log query normalization", type: :request do
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
        status: :failed,
        delivery_type: :portal_link,
        to_addresses: "recipient@example.com",
        subject: "Delivery notice"
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

  it "normalizes overlong search terms across filters and detail return_to without widening sender scope" do
    max_length = DocumentDeliveryLogsController::DELIVERY_LOG_QUERY_MAX_LENGTH
    bounded_fragment = "a" * max_length
    long_fragment = "  #{bounded_fragment}extra-error-log-tail  "
    created_from = "2026-01-10"
    created_to = "2026-01-20"
    matching_log = create_delivery_log_at(
      Time.zone.local(2026, 1, 15, 12, 0, 0),
      to_addresses: "bounded-hit@example.com",
      subject: bounded_fragment,
      error_message: "bounded failure"
    )
    outside_date_log = create_delivery_log_at(
      Time.zone.local(2026, 1, 5, 12, 0, 0),
      to_addresses: "outside-date@example.com",
      subject: bounded_fragment,
      error_message: "bounded failure"
    )
    other_sender_log = create_delivery_log_at(
      Time.zone.local(2026, 1, 15, 12, 0, 0),
      sender: other_external_user,
      to_addresses: "other-sender@example.com",
      subject: bounded_fragment,
      error_message: "bounded failure"
    )

    sign_in_as(external_user)

    get document_delivery_logs_path, params: {
      q: long_fragment,
      status: :failed,
      delivery_type: :portal_link,
      created_from:,
      created_to:
    }

    expect(response).to have_http_status(:ok)
    search_input = parsed_html.at_css("input[name='q']")
    expect(search_input).to be_present
    expect(search_input["maxlength"]).to eq(max_length.to_s)
    expect(search_input["value"]).to eq(bounded_fragment)
    expect(page_text).to include("検索語は最大#{max_length}文字です。")
    expect(page_text).to include("案件名・案件コード・宛先/CC/BCC・件名・失敗理由の断片で探せます。")
    expect(page_text).to include(matching_log.to_addresses)
    expect(page_text).not_to include(outside_date_log.to_addresses)
    expect(page_text).not_to include(other_sender_log.to_addresses)

    expect(action_targets).to include(
      document_delivery_logs_path(q: bounded_fragment, created_from:, created_to:, status: :draft, delivery_type: :portal_link)
    )
    expect(action_targets).to include(
      document_delivery_logs_path(q: bounded_fragment, created_from:, created_to:, status: :failed)
    )
    expect(href_for("検索をクリア")).to eq(
      document_delivery_logs_path(status: :failed, delivery_type: :portal_link, created_from:, created_to:)
    )

    detail_href = href_for_row_containing(matching_log.to_addresses, localized_status_label(:failed))
    detail_params = Rack::Utils.parse_nested_query(URI.parse(detail_href).query)
    expect(detail_params["return_to"]).to eq(
      document_delivery_logs_path(q: bounded_fragment, status: "failed", delivery_type: "portal_link", created_from:, created_to:)
    )
    expect(detail_params).to include("created_from" => created_from, "created_to" => created_to)
  end
end
