require "rails_helper"

RSpec.describe "Document delivery log failure summaries", type: :request do
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "DLV1", name: "Delivery Project") }
  let(:document) { create(:document, project:, title: "Shared Manual", slug: "shared-manual", visibility_policy: :restricted_external) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.gsub(/[[:space:]]+/, " ").strip
  end

  def localized_status_label(status)
    I18n.t("labels.document_delivery_logs.status.#{status}", default: status.to_s)
  end

  def href_for_row_containing(row_text, link_text)
    row = parsed_html.css("tr").find { |node| node.text.include?(row_text) }
    row&.css("a[href]")&.find { |node| node.text.strip == link_text }&.[]("href")
  end

  before do
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "shows a failure summary in the status column for failed logs" do
    draft_log = create(:document_delivery_log, project:, document:, sender: external_user, status: :draft, delivery_type: :portal_link, to_addresses: "draft@example.com")
    failed_log = create(:document_delivery_log, project:, document:, sender: external_user, status: :failed, delivery_type: :portal_link, to_addresses: "failed@example.com", error_message: "SMTP timeout while contacting upstream gateway")

    sign_in_as(external_user)

    get document_delivery_logs_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("失敗理由: SMTP timeout while contacting upstream gateway")
    expect(href_for_row_containing(failed_log.to_addresses, localized_status_label(:failed))).to eq(document_delivery_log_path(failed_log, return_to: document_delivery_logs_path))
    expect(parsed_html.css("tr").find { |node| node.text.include?(draft_log.to_addresses) }.text).not_to include("失敗理由:")
  end
end
