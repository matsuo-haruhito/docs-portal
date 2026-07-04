require "rails_helper"

RSpec.describe "Consent maintenance mode", type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, :external, company:) }
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "CONSENT-MAINT", name: "Consent Maintenance") }
  let(:document) { create(:document, project:, title: "Consent Guide", slug: "consent-guide", visibility_policy: :restricted_external) }

  around do |example|
    previous_value = ENV["READ_ONLY_MAINTENANCE"]
    ENV["READ_ONLY_MAINTENANCE"] = "true"
    example.run
  ensure
    ENV["READ_ONLY_MAINTENANCE"] = previous_value
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "does not create user consents during maintenance mode" do
    term = create(:consent_term, title: "Maintenance Terms", consent_scope: :project, version_label: "v1")
    create(:project_consent_setting, project:, consent_term: term, required_on: :first_access)
    create(:project_membership, project:, user:)
    create(:document_permission, document:, company:, access_level: :view)

    sign_in_as(user)

    expect do
      post consents_path, params: {
        target_type: "Project",
        target_public_id: project.public_id,
        timing: "first_view",
        return_to: project_path(project)
      }
    end.not_to change(UserConsent, :count)

    expect(response).to redirect_to(
      new_consent_path(
        target_type: "Project",
        target_public_id: project.public_id,
        timing: "first_view",
        return_to: project_path(project)
      )
    )

    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("メンテナンス中のため同意記録の作成は停止しています")
    expect(page_text).to include("Maintenance Terms")
  end

  it "keeps consent history and confirmation pages readable during maintenance mode" do
    term = create(:consent_term, title: "Readable Terms", body: "Read this carefully", consent_scope: :project, version_label: "v1")
    create(:project_consent_setting, project:, consent_term: term, required_on: :first_access)

    sign_in_as(user)

    get consents_path
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Readable Terms")

    get new_consent_path(target_type: "Project", target_public_id: project.public_id, timing: "first_view", return_to: project_path(project))
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Readable Terms")
    expect(page_text).to include("確認が必要な注意事項")
  end

  it "does not create, update, or destroy consent terms during maintenance mode" do
    existing_term = create(
      :consent_term,
      title: "Existing Terms",
      body: "Original body",
      version_label: "v1",
      consent_scope: :project,
      requirement_timing: :first_view,
      active: true
    )

    sign_in_as(admin_user)

    expect do
      post admin_consent_terms_path, params: {
        consent_term: {
          title: "Blocked Terms",
          body: "Blocked body",
          version_label: "v2",
          consent_scope: "project",
          requirement_timing: "first_view",
          active: true
        }
      }
    end.not_to change(ConsentTerm, :count)

    expect(response).to redirect_to(admin_consent_terms_path)

    patch admin_consent_term_path(existing_term), params: {
      consent_term: {
        title: "Updated Terms",
        body: "Updated body",
        version_label: "v9",
        consent_scope: "download",
        requirement_timing: "every_download",
        active: false
      }
    }

    expect(response).to redirect_to(admin_consent_terms_path)
    expect(existing_term.reload).to have_attributes(
      title: "Existing Terms",
      body: "Original body",
      version_label: "v1",
      consent_scope: "project",
      requirement_timing: "first_view",
      active: true
    )

    expect do
      delete admin_consent_term_path(existing_term)
    end.not_to change(ConsentTerm, :count)

    expect(response).to redirect_to(admin_consent_terms_path)
    expect(ConsentTerm.exists?(existing_term.id)).to be(true)
  end

  it "does not create, update, or destroy project consent settings during maintenance mode" do
    existing_project = create(:project, code: "EXIST", name: "Existing Project")
    replacement_project = create(:project, code: "NEW", name: "New Project")
    existing_term = create(:consent_term, title: "Existing Project Terms", version_label: "v1", consent_scope: :project)
    replacement_term = create(:consent_term, title: "Replacement Terms", version_label: "v2", consent_scope: :download)
    setting = create(:project_consent_setting, project: existing_project, consent_term: existing_term, required_on: :first_access, enabled: true)

    sign_in_as(admin_user)

    expect do
      post admin_project_consent_settings_path, params: {
        project_consent_setting: {
          project_id: replacement_project.id,
          consent_term_id: replacement_term.id,
          required_on: "download",
          enabled: true
        }
      }
    end.not_to change(ProjectConsentSetting, :count)

    expect(response).to redirect_to(admin_project_consent_settings_path)

    patch admin_project_consent_setting_path(setting), params: {
      project_consent_setting: {
        project_id: replacement_project.id,
        consent_term_id: replacement_term.id,
        required_on: "download",
        enabled: false
      }
    }

    expect(response).to redirect_to(admin_project_consent_settings_path)
    expect(setting.reload).to have_attributes(
      project_id: existing_project.id,
      consent_term_id: existing_term.id,
      required_on: "first_access",
      enabled: true
    )

    expect do
      delete admin_project_consent_setting_path(setting)
    end.not_to change(ProjectConsentSetting, :count)

    expect(response).to redirect_to(admin_project_consent_settings_path)
    expect(ProjectConsentSetting.exists?(setting.id)).to be(true)
  end

  it "keeps admin consent term and project consent setting read-only routes available" do
    project = create(:project, code: "READ", name: "Readable Project")
    term = create(:consent_term, title: "Readable Admin Terms", version_label: "v1", consent_scope: :project)
    create(:project_consent_setting, project:, consent_term: term, enabled: true)

    sign_in_as(admin_user)

    get admin_consent_terms_path(q: "Readable")
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Readable Admin Terms")

    get edit_admin_consent_term_path(term)
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Readable Admin Terms")

    get admin_project_consent_settings_path(project_id: project.id, consent_term_id: term.id, enabled: "true")
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Readable Project")
    expect(page_text).to include("Readable Admin Terms")

    get edit_admin_project_consent_setting_path(ProjectConsentSetting.last)
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Readable Project")

    get project_search_admin_project_consent_settings_path(format: :json), params: { q: "READ" }
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).fetch("options")).to include(include("value" => project.id, "text" => "Readable Project (READ)"))

    get consent_term_search_admin_project_consent_settings_path(format: :json), params: { q: "Readable" }
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).fetch("options")).to include(include("value" => term.id, "text" => "Readable Admin Terms / v1"))
  end
end
