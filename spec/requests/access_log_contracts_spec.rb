require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe "Access log contracts", type: :request do
  def latest_access_log
    AccessLog.order(:id).last
  end

  describe "document file downloads" do
    let(:user) { create(:user, :internal) }
    let(:project) { create(:project, code: "PJ#{SecureRandom.hex(4)}", name: "Project #{SecureRandom.hex(2)}") }
    let(:document) { create(:document, project:, title: "運用手順", slug: "operation-manual") }

    it "records a download access log for direct document file downloads" do
      version = create(:document_version, document:, version_label: "v1.0.0", status: :published)
      file = DocumentFile.create!(
        document_version: version,
        file_name: "operation-manual.pdf",
        content_type: "application/pdf",
        storage_key: "spec/#{SecureRandom.hex(8)}-operation-manual.pdf",
        file_size: 10,
        scan_status: :scan_clean
      )
      FileUtils.mkdir_p(file.absolute_path.dirname)
      File.write(file.absolute_path, "%PDF-1.4")

      sign_in_as(user)

      expect do
        get document_file_path(file)
      end.to change(AccessLog, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")

      log = latest_access_log
      expect(log.user).to eq(user)
      expect(log.company).to eq(user.company)
      expect(log.project).to eq(project)
      expect(log.document).to eq(document)
      expect(log.document_version).to eq(version)
      expect(log.action_type).to eq("download")
      expect(log.target_type).to eq("file")
      expect(log.target_name).to eq("operation-manual.pdf")
    ensure
      FileUtils.rm_f(file.absolute_path) if file&.id
    end
  end

  describe "admin external preview" do
    let(:admin_user) { create(:user, :internal) }
    let(:preview_user) { create(:user, :external, email_address: "viewer-#{SecureRandom.hex(4)}@example.com") }
    let(:project) { create(:project, code: "PJ#{SecureRandom.hex(4)}", name: "Preview Project") }

    it "records an external preview access log when an admin previews a specific user" do
      sign_in_as(admin_user)

      expect do
        get external_preview_admin_project_path(project), params: { user_id: preview_user.id }
      end.to change(AccessLog, :count).by(1)

      expect(response).to have_http_status(:ok)

      log = latest_access_log
      expect(log.user).to eq(admin_user)
      expect(log.company).to eq(preview_user.company)
      expect(log.project).to eq(project)
      expect(log.document).to be_nil
      expect(log.document_version).to be_nil
      expect(log.action_type).to eq("view")
      expect(log.target_type).to eq("external_preview")
      expect(log.target_name).to eq("user:#{preview_user.email_address}")
    end
  end

  describe "session creation" do
    it "updates last_login_at without recording an access log" do
      user = create(:user, last_login_at: nil)

      expect do
        post session_path, params: {
          session: {
            email_address: user.email_address,
            password: "password123!"
          }
        }
      end.not_to change(AccessLog, :count)

      expect(response).to redirect_to(root_path)
      expect(user.reload.last_login_at).to be_present
    end
  end
end
