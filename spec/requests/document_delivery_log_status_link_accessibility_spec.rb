require "rails_helper"

RSpec.describe "Document delivery log status link accessibility", type: :request do
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "DLV1", name: "Delivery Project") }
  let(:document) { create(:document, project:, title: "Shared Manual", slug: "shared-manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def localized_status_label(status)
    I18n.t("labels.document_delivery_logs.status.#{status}", default: status.to_s)
  end

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "adds a row-specific accessible name to status detail links" do
    log = create(
      :document_delivery_log,
      project:,
      document:,
      sender: external_user,
      status: :sent,
      delivery_type: :portal_link,
      to_addresses: "client@example.com"
    )

    sign_in_as(external_user)

    get document_delivery_logs_path

    expect(response).to have_http_status(:ok)

    row = parsed_html.css("tr").find { |node| node.text.include?(log.to_addresses) }
    status_link = row.css("a[href]").find { |node| node.text.strip == localized_status_label(:sent) }

    expect(status_link["href"]).to eq(document_delivery_log_path(log, return_to: document_delivery_logs_path))
    expect(status_link.text.strip).to eq(localized_status_label(:sent))
    expect(status_link["aria-label"]).to include(
      "送付履歴詳細",
      localized_status_label(:sent),
      project.name,
      document.title,
      "To: #{log.to_addresses}"
    )
    expect(status_link["title"]).to eq(status_link["aria-label"])
  end
end
