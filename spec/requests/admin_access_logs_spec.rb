require "rails_helper"

RSpec.describe "Admin access logs", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }
  let(:project) { create(:project, code: "AUDIT", name: "Audit Project") }
  let(:document) { create(:document, project:, title: "Audit Document", slug: "audit-document") }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0") }

  def create_access_log!(action_type:, target_type:, target_name:, user: admin_user, company: admin_user.company, project: self.project, document: self.document, document_version: version)
    AccessLog.create!(
      user:,
      company:,
      project:,
      document:,
      document_version:,
      action_type:,
      target_type:,
      target_name:,
      ip_address: "127.0.0.1",
      user_agent: "RSpec",
      accessed_at: Time.current
    )
  end

  it "shows access logs to internal admins" do
    create_access_log!(action_type: :download, target_type: "zip", target_name: "audit.zip")

    sign_in_as(admin_user)

    get admin_access_logs_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("監査ログ")
    expect(response.body).to include("Audit Project")
    expect(response.body).to include("Audit Document")
    expect(response.body).to include("audit.zip")
  end

  it "filters access logs by action type and target type" do
    create_access_log!(action_type: :download, target_type: "zip", target_name: "audit.zip")
    create_access_log!(action_type: :view, target_type: "page", target_name: "index.html")

    sign_in_as(admin_user)

    get admin_access_logs_path(action_type: "download", target_type: "zip")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("audit.zip")
    expect(response.body).not_to include("index.html")
  end

  it "filters access logs by document title or slug" do
    other_document = create(:document, project:, title: "Other Document", slug: "other-document")
    other_version = create(:document_version, document: other_document, version_label: "v1.0.0")
    create_access_log!(action_type: :view, target_type: "page", target_name: "audit.html")
    create_access_log!(
      action_type: :view,
      target_type: "page",
      target_name: "other.html",
      document: other_document,
      document_version: other_version
    )

    sign_in_as(admin_user)

    get admin_access_logs_path(document_q: "audit")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("audit.html")
    expect(response.body).not_to include("other.html")
  end

  it "forbids external users" do
    sign_in_as(external_user)

    get admin_access_logs_path

    expect(response).to have_http_status(:forbidden)
  end
end
