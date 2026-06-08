require "rails_helper"
require "fileutils"

RSpec.describe "Consents", type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "CONSENT", name: "Consent Project") }
  let(:document) { create(:document, project:, title: "Consent Document", slug: "consent-document", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }
  let(:file) do
    create(
      :document_file,
      document_version: version,
      file_name: "manual.pdf",
      content_type: "application/pdf",
      storage_key: "spec/consents/manual.pdf",
      file_size: 8,
      scan_status: :scan_clean
    )
  end
  let(:unsafe_return_to_values) do
    [
      "",
      "//example.com/outside",
      "https://example.com/outside",
      "http://example.com/outside",
      "javascript:alert(1)",
      "evil/path",
      "/projects#section",
      "/projects/\u0000outside"
    ]
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def link_hrefs(text)
    parsed_html.css("a").filter_map do |link|
      link["href"] if link.text.squish == text
    end
  end

  def hidden_return_to_values
    parsed_html.css('input[name="return_to"]').map { _1["value"] }
  end

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
    expect(page_text).to include("Project Terms")
    expect(page_text).to include("対象:")
    expect(page_text).to include("案件 / Consent Project")
    expect(page_text).to include("種別:")
    expect(page_text).to include("案件")

    expect do
      post consents_path, params: { target_type: "Project", target_public_id: project.public_id, timing: "first_view", return_to: project_path(project) }
    end.to change(UserConsent, :count).by(1)

    expect(response).to redirect_to(project_path(project))

    get project_path(project)
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Consent Document")
  end

  it "does not create duplicate consent records when the same missing term is posted twice" do
    term = create(:consent_term, title: "Project Terms", consent_scope: :project, version_label: "v1")
    create(:project_consent_setting, project:, consent_term: term, required_on: :first_access)

    sign_in_as(user)

    params = { target_type: "Project", target_public_id: project.public_id, timing: "first_view", return_to: project_path(project) }

    expect do
      post consents_path, params:
    end.to change(UserConsent, :count).by(1)

    expect do
      post consents_path, params:
    end.not_to change(UserConsent, :count)

    expect(UserConsent.where(user:, consent_term: term, target: project)).to contain_exactly(UserConsent.last)
  end

  it "uses the current return_to for the back link when it is a path-only internal URL" do
    term = create(:consent_term, title: "Project Terms", consent_scope: :project, version_label: "v1")
    create(:project_consent_setting, project:, consent_term: term, required_on: :first_access)

    sign_in_as(user)

    return_to = "#{document_file_path(file)}?source_path=manuals"
    get new_consent_path(target_type: "Project", target_public_id: project.public_id, timing: "first_view", return_to:)

    expect(response).to have_http_status(:ok)
    expect(link_hrefs("同意せず戻る")).to include(return_to)
    expect(hidden_return_to_values).to include(return_to)
  end

  it "falls back to projects_path for the back link when return_to is unsafe" do
    term = create(:consent_term, title: "Project Terms", consent_scope: :project, version_label: "v1")
    create(:project_consent_setting, project:, consent_term: term, required_on: :first_access)

    sign_in_as(user)

    unsafe_return_to_values.each do |return_to|
      get new_consent_path(target_type: "Project", target_public_id: project.public_id, timing: "first_view", return_to:)

      expect(response).to have_http_status(:ok)
      expect(link_hrefs("同意せず戻る")).to include(projects_path)
      expect(hidden_return_to_values).to include(projects_path)
      expect(hidden_return_to_values).not_to include(return_to) if return_to.present?
    end
  end

  it "redirects immediately using the safe return_to rule when no terms are missing" do
    term = create(:consent_term, title: "Project Terms", consent_scope: :project, version_label: "v1")
    create(:project_consent_setting, project:, consent_term: term, required_on: :first_access)
    create(:user_consent, user:, consent_term: term, target: project, consent_term_version_label: "v1")

    sign_in_as(user)

    safe_return_to = "#{project_documents_path(project)}?q=manual"
    get new_consent_path(target_type: "Project", target_public_id: project.public_id, timing: "first_view", return_to: safe_return_to)
    expect(response).to redirect_to(safe_return_to)

    unsafe_return_to_values.each do |return_to|
      get new_consent_path(target_type: "Project", target_public_id: project.public_id, timing: "first_view", return_to:)

      expect(response).to redirect_to(projects_path)
    end
  end

  it "falls back to projects_path after consent when return_to is unsafe" do
    term = create(:consent_term, title: "Project Terms", consent_scope: :project, version_label: "v1")
    create(:project_consent_setting, project:, consent_term: term, required_on: :first_access)

    sign_in_as(user)

    unsafe_return_to_values.each do |return_to|
      post consents_path, params: { target_type: "Project", target_public_id: project.public_id, timing: "first_view", return_to: }

      expect(response).to redirect_to(projects_path)
    end
  end

  it "redirects file downloads to download consent and does not log before consent" do
    term = create(:consent_term, title: "Download Terms", consent_scope: :download, version_label: "v1")
    create(:project_consent_setting, project:, consent_term: term, required_on: :download)
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

  it "shows active terms and the user's consent history with localized target and scope labels" do
    file = create(:document_file, document_version: version, file_name: "history.pdf")
    term = create(:consent_term, title: "Visible Terms", body: "Handle carefully", version_label: "v1", consent_scope: :download)

    create(:user_consent, user:, consent_term: term, target: nil, consent_term_version_label: "v1")
    create(:user_consent, user:, consent_term: term, target: project, consent_term_version_label: "v1")
    create(:user_consent, user:, consent_term: term, target: document, consent_term_version_label: "v1")
    create(:user_consent, user:, consent_term: term, target: file, consent_term_version_label: "v1")
    create(:user_consent, user:, consent_term: term, target: version, consent_term_version_label: "v1")

    sign_in_as(user)
    get consents_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Visible Terms")
    expect(page_text).to include("Handle carefully")
    expect(page_text).to include("種別")
    expect(page_text).to include("ダウンロード")
    expect(page_text).to include("v1")
    expect(page_text).to include("全体")
    expect(page_text).to include("案件 / Consent Project")
    expect(page_text).to include("文書 / Consent Document")
    expect(page_text).to include("ファイル / history.pdf")
    expect(page_text).to include("文書版 / v1.0.0")
    expect(page_text).not_to include("Project / Consent Project")
    expect(page_text).not_to include("Document / Consent Document")
    expect(page_text).not_to include("DocumentFile / history.pdf")
    expect(page_text).not_to include("DocumentVersion / v1.0.0")
    expect(page_text).not_to include(">download<")
  end
end
