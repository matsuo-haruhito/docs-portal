require "rails_helper"

RSpec.describe "Document delivery logs maintenance mode", type: :request do
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:internal_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "DLVM", name: "Delivery Maintenance") }
  let(:document) { create(:document, project:, title: "Maintenance Manual", slug: "maintenance-manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  around do |example|
    original_value = ENV[DocumentDeliveryLogsController::READ_ONLY_MAINTENANCE_ENV]
    ENV[DocumentDeliveryLogsController::READ_ONLY_MAINTENANCE_ENV] = maintenance_env_value
    example.run
  ensure
    if original_value.nil?
      ENV.delete(DocumentDeliveryLogsController::READ_ONLY_MAINTENANCE_ENV)
    else
      ENV[DocumentDeliveryLogsController::READ_ONLY_MAINTENANCE_ENV] = original_value
    end
  end

  describe "when read-only maintenance is enabled" do
    let(:maintenance_env_value) { "1" }

    it "keeps list, detail, CSV, and failure handoff readable" do
      log = create(
        :document_delivery_log,
        project:,
        document:,
        sender: external_user,
        status: :failed,
        delivery_type: :portal_link,
        to_addresses: "client@example.com",
        subject: "Maintenance delivery",
        error_message: "manual failure"
      )
      sign_in_as(internal_user)

      get document_delivery_logs_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("client@example.com")

      get document_delivery_logs_path(format: :csv)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("client@example.com")

      get document_delivery_log_path(log)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Maintenance delivery")

      get failure_alert_handoff_document_delivery_logs_path
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include("count", "note", "entries")
    end

    it "blocks creating a delivery draft for a document" do
      sign_in_as(external_user)

      expect do
        post project_document_document_delivery_logs_path(project, document), params: {
          document_delivery_log: {
            to_addresses: "client@example.com",
            subject: "Please review",
            body: "Portal link"
          }
        }
      end.not_to change(DocumentDeliveryLog, :count)

      expect(response).to redirect_to(project_document_path(project, document.slug))
      expect(flash[:alert]).to include("外部送付履歴の下書き作成・手動状態更新は停止しています")
    end

    it "blocks marking a draft as sent while preserving the return path" do
      log = create(
        :document_delivery_log,
        project:,
        document:,
        sender: external_user,
        status: :draft,
        delivery_type: :portal_link,
        to_addresses: "client@example.com",
        subject: "Draft delivery",
        sent_at: nil,
        error_message: nil
      )
      return_to = document_delivery_logs_path(status: :draft, q: "DLVM")
      sign_in_as(external_user)

      patch document_delivery_log_path(log), params: { decision: "mark_sent", return_to: }

      expect(response).to redirect_to(document_delivery_log_path(log, return_to: return_to))
      expect(flash[:alert]).to include("外部送付履歴の下書き作成・手動状態更新は停止しています")
      expect(log.reload.status).to eq("draft")
      expect(log.sent_at).to be_nil
      expect(log.error_message).to be_nil
    end

    it "blocks marking a draft as failed" do
      log = create(
        :document_delivery_log,
        project:,
        document:,
        sender: external_user,
        status: :draft,
        delivery_type: :portal_link,
        to_addresses: "client@example.com",
        subject: "Draft delivery",
        error_message: nil
      )
      sign_in_as(external_user)

      patch document_delivery_log_path(log), params: { decision: "mark_failed", error_message: "manual failure" }

      expect(response).to redirect_to(document_delivery_log_path(log))
      expect(flash[:alert]).to include("外部送付履歴の下書き作成・手動状態更新は停止しています")
      expect(log.reload.status).to eq("draft")
      expect(log.error_message).to be_nil
    end
  end

  describe "when read-only maintenance is disabled" do
    let(:maintenance_env_value) { nil }

    it "keeps the existing draft creation and manual sent update behavior" do
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
      expect(log.status).to eq("draft")

      patch document_delivery_log_path(log), params: { decision: "mark_sent" }

      expect(response).to redirect_to(document_delivery_log_path(log))
      expect(log.reload.status).to eq("sent")
      expect(log.sent_at).to be_present
    end
  end
end
