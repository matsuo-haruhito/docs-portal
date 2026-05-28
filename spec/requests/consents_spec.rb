require "rails_helper"
require "fileutils"

RSpec.describe "Consents", type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "CONSENT", name: "Consent Project") }
  let(:document) { create(:document, project:, title: "Consent Document", slug: "consent-document", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  before do
    create(:project_membership, project:, user:)
    create(:document_permission, document:, company:, access_level: :download)
    document.update!(latest_version: version)
  end

  it "redirects project access to the consent screen until agreed" do
    term = create(:consent_term, title: "Project Terms", consent_scope: :project, version_label: "v1")
    create(:project_consent_setting, project:, consent_term: term, required_on: :first_access)

    sign_in_as(user)

    get project_path(project)

    expect(response).to redirect_to(new_consent_path(target_type: "Project", target_public_id: project.public_id, timing: :first_view, return_to: project_path(project)))

    follow_redirect!
    expect(response.body).to include("Project Terms")

    expect do
      post consents_path, params: { target_type: "Project", target_public_id: project.public_id, timing: "first_view", return_to: project_path(project) }
    end.to change(UserConsent, :count).by(1)

    expect(response).to redirect_to(project_path(project))

    get project_path(project)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Consent Document")
  end

  it "redirects file downloads to download consent and does not log before consent" do
    term = create(:consent_term, title: "Download Terms", consent_scope: :download, version_label: "v1")
    create(:project_consent_setting, project:, consent_term: term, required_on: :download)
    file = create(:document_file, document_version: version, file_name: "manual.pdf", content_type: "application/pdf", storage_key: "spec/consents/manual.pdf", file_size: 8, scan_status: :scan_clean)
    FileUtils.mkdir_p(file.absolute_path.dirname)
    File.binwrite(file.absolute_path, "%PDF-1.4")

    sign_in_as(user)

    expect do
      get document_file_path(file)
    end.not_to change(AccessLog, :count)

    expect(response).to redirect_to(new_consent_path(target_type: "Project", target_public_id: project.public_id, timing: :download, return_to: document_file_path(file)))

    post consents_path, params: { target_type: "Project", target_public_id: project.public_id, timing: "download", return_to: document_file_path(file) }

    expect(response).to redirect_to(document_file_path(file))

    expect do
      get document_file_path(file)
    end.to change(AccessLog.where(action_type: :download), :count).by(1)

    expect(response).to have_http_status(:ok)
  ensure
    FileUtils.rm_rf(Rails.root.join("storage", "document_files", "spec", "consents"))
  end

  it "shows active terms and the user's consent history with localized target labels" do
    file = create(:document_file, document_version: version, file_name: "history.pdf")
    term = create(:consent_term, title: "Visible Terms", body: "Handle carefully", version_label: "v1")

    create(:user_consent, user:, consent_term: term, target: nil, consent_term_version_label: "v1")
    create(:user_consent, user:, consent_term: term, target: project, consent_term_version_label: "v1")
    create(:user_consent, user:, consent_term: term, target: document, consent_term_version_label: "v1")
    create(:user_consent, user:, consent_term: term, target: file, consent_term_version_label: "v1")
    create(:user_consent, user:, consent_term: term, target: version, consent_term_version_label: "v1")

    sign_in_as(user)
    get consents_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Visible Terms")
    expect(response.body).to include("Handle carefully")
    expect(response.body).to include("v1")
    expect(response.body).to include("全体")
    expect(response.body).to include("案件 / Consent Project")
    expect(response.body).to include("文書 / Consent Document")
    expect(response.body).to include("ファイル / history.pdf")
    expect(response.body).to include("文書版 / v1.0.0")
    expect(response.body).not_to include("Project / Consent Project")
    expect(response.body).not_to include("Document / Consent Document")
    expect(response.body).not_to include("DocumentFile / history.pdf")
    expect(response.body).not_to include("DocumentVersion / v1.0.0")
  end
end
