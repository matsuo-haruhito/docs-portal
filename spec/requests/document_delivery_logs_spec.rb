require "rails_helper"
require "cgi"

RSpec.describe "Document delivery logs", type: :request do
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:internal_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "DLV1", name: "Delivery Project") }
  let(:document) { create(:document, project:, title: "Shared Manual", slug: "shared-manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }
  let(:document_set) { create(:document_set, project:, name: "顧客送付セット", visibility_policy: :restricted_external) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.gsub(/[[:space:]]+/, " ").strip
  end

  def localized_status_label(status)
    I18n.t("labels.document_delivery_logs.status.#{status}", default: status.to_s)
  end

  def localized_delivery_type_label(delivery_type)
    I18n.t("labels.document_delivery_logs.delivery_type.#{delivery_type}", default: delivery_type.to_s)
  end

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "creates and marks sent a portal-link delivery draft for a document" do
    sign_in_as(external_user)

    expect do
      post project_document_document_delivery_logs_path(project, document), params: {
        document_delivery_log: {
          to_addresses: "client@example.com",
          subject: "Please review",
          body: "Portal link"
        }
      }
    end.to change(DocumentDeliveryLog, :count).by(1)

    log = DocumentDeliveryLog.order(:id).last
    expect(response).to redirect_to(document_delivery_log_path(log))
    expect(log.document).to eq(document)
    expect(log.status).to eq("draft")

    patch document_delivery_log_path(log), params: { decision: "mark_sent" }

    expect(response).to redirect_to(document_delivery_log_path(log))
    expect(log.reload.status).to eq("sent")
    expect(log.sent_at).to be_present
  end

  it "creates a portal-link delivery draft for a document set" do
    sign_in_as(external_user)

    expect do
      post project_document_set_document_delivery_logs_path(project, document_set), params: {
        document_delivery_log: {
          to_addresses: "client@example.com",
          subject: "Set review",
          body: "Please review the set."
        }
      }
    end.to change(DocumentDeliveryLog, :count).by(1)

    log = DocumentDeliveryLog.order(:id).last
    expect(response).to redirect_to(document_delivery_log_path(log))
    expect(log.document_set).to eq(document_set)
    expect(log.document).to be_nil
  end

  it "filters delivery logs by status and delivery type without widening the visible scope" do
    other_external_user = create(:user, :external, company:)
    own_draft = create(:document_delivery_log, project:, document:, sender: external_user, status: :draft, delivery_type: :portal_link, to_addresses: "draft@example.com")
    own_sent = create(:document_delivery_log, project:, document:, sender: external_user, status: :sent, delivery_type: :attachment, to_addresses: "sent@example.com")
    own_failed = create(:document_delivery_log, project:, document:, sender: external_user, status: :failed, delivery_type: :zip_attachment, to_addresses: "failed-self@example.com")
    other_failed = create(:document_delivery_log, project:, document:, sender: other_external_user, status: :failed, delivery_type: :shared_link, to_addresses: "failed@example.com")

    sign_in_as(external_user)

    get document_delivery_logs_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("すべて (3)")
    expect(response.body).to include("#{localized_status_label(:draft)} (1)")
    expect(response.body).to include("#{localized_status_label(:sent)} (1)")
    expect(response.body).to include("#{localized_status_label(:failed)} (1)")
    expect(response.body).to include("#{localized_delivery_type_label(:portal_link)} (1)")
    expect(response.body).to include("#{localized_delivery_type_label(:attachment)} (1)")
    expect(response.body).to include("#{localized_delivery_type_label(:zip_attachment)} (1)")
    expect(response.body).to include("#{localized_delivery_type_label(:shared_link)} (0)")
    expect(response.body).to include(own_draft.to_addresses)
    expect(response.body).to include(own_sent.to_addresses)
    expect(response.body).to include(own_failed.to_addresses)
    expect(response.body).not_to include(other_failed.to_addresses)

    get document_delivery_logs_path, params: { delivery_type: :portal_link }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(own_draft.to_addresses)
    expect(response.body).not_to include(own_sent.to_addresses)
    expect(response.body).not_to include(own_failed.to_addresses)
    expect(response.body).not_to include(other_failed.to_addresses)
    expect(CGI.unescapeHTML(response.body)).to include(document_delivery_logs_path(status: :draft, delivery_type: :portal_link))
    expect(CGI.unescapeHTML(response.body)).to include(document_delivery_logs_path(status: :failed, delivery_type: :portal_link))

    get document_delivery_logs_path, params: { status: :failed, delivery_type: :zip_attachment }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(own_failed.to_addresses)
    expect(response.body).not_to include(own_draft.to_addresses)
    expect(response.body).not_to include(own_sent.to_addresses)
    expect(response.body).not_to include(other_failed.to_addresses)
    expect(CGI.unescapeHTML(response.body)).to include(document_delivery_logs_path(status: :failed))

    sign_in_as(internal_user)

    get document_delivery_logs_path, params: { delivery_type: :shared_link }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(other_failed.to_addresses)
    expect(response.body).not_to include(own_draft.to_addresses)
    expect(response.body).not_to include(own_sent.to_addresses)
    expect(response.body).not_to include(own_failed.to_addresses)
  end

  it "renders localized delivery labels in the index" do
    sign_in_as(external_user)

    DocumentDeliveryLog.create!(
      project:,
      document:,
      sender: external_user,
      to_addresses: "client@example.com",
      subject: "Please review",
      body: "Portal link",
      delivery_type: :portal_link,
      status: :draft
    )

    get document_delivery_logs_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("ポータルリンク")
    expect(page_text).to include("下書き")
    expect(page_text).not_to include("portal_link")
  end

  it "shows localized labels and links back to the project and document" do
    sign_in_as(external_user)

    log = DocumentDeliveryLog.create!(
      project:,
      document:,
      sender: external_user,
      to_addresses: "client@example.com",
      subject: "Please review",
      body: "Portal link",
      delivery_type: :portal_link,
      status: :draft
    )

    get document_delivery_log_path(log)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("ポータルリンク")
    expect(response.body).to include("下書き")
    expect(response.body).to include(project_path(project))
    expect(response.body).to include(project_document_path(project, document.slug))
    expect(response.body).to include("対象の文書へ戻る")
  end

  it "shows links back to the project and document set" do
    sign_in_as(external_user)

    log = DocumentDeliveryLog.create!(
      project:,
      document_set:,
      sender: external_user,
      to_addresses: "client@example.com",
      subject: "Set review",
      body: "Please review the set.",
      delivery_type: :portal_link,
      status: :draft
    )

    get document_delivery_log_path(log)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(project_path(project))
    expect(response.body).to include(project_document_set_path(project, document_set))
    expect(response.body).to include("対象の文書セットへ戻る")
  end
end