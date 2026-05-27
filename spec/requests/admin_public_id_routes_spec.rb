require "rails_helper"

RSpec.describe "Admin public_id member routes", type: :request do
  let(:admin_user) { create(:user, :internal) }

  let!(:project) { create(:project, code: "ADM001", name: "Admin Project") }
  let!(:git_import_source) do
    GitImportSource.create!(
      project:,
      created_by: admin_user,
      provider: :github,
      repository_full_name: "example/docs-portal",
      branch: "main",
      source_path: "docs",
      auth_type: :github_app,
      enabled: true
    )
  end
  let!(:webhook_endpoint) do
    WebhookEndpoint.create!(
      name: "Portal webhook",
      target_url: "https://example.com/webhooks/docs-portal",
      secret_token: "secret-token",
      active: true,
      event_types: %w[document_updated]
    )
  end
  let!(:microsoft_graph_connection) do
    MicrosoftGraphConnection.create!(
      project:,
      created_by: admin_user,
      name: "Preview connection",
      auth_type: :client_credentials,
      tenant_id: SecureRandom.uuid,
      client_id: SecureRandom.uuid,
      client_secret: "client-secret",
      drive_id: "drive-id",
      preview_folder_path: "docs-portal-previews",
      enabled: true
    )
  end
  let!(:consent_term) do
    ConsentTerm.create!(
      title: "利用同意",
      body: "本文",
      version_label: "v1",
      consent_scope: :project,
      requirement_timing: :first_view,
      active: true
    )
  end
  let!(:project_consent_setting) do
    ProjectConsentSetting.create!(
      project:,
      consent_term: consent_term,
      required_on: :first_access,
      enabled: true
    )
  end

  before do
    sign_in_as(admin_user)
  end

  it "renders public_id member links for operational admin resources" do
    get admin_git_import_sources_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(sync_admin_git_import_source_path(git_import_source.public_id))
    expect(response.body).to include(edit_admin_git_import_source_path(git_import_source.public_id))
    expect(response.body).to include(admin_git_import_source_path(git_import_source.public_id))
    expect(response.body).not_to include(sync_admin_git_import_source_path(git_import_source.id))
    expect(response.body).not_to include(edit_admin_git_import_source_path(git_import_source.id))
    expect(response.body).not_to include(admin_git_import_source_path(git_import_source.id))

    get admin_webhook_endpoints_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(edit_admin_webhook_endpoint_path(webhook_endpoint.public_id))
    expect(response.body).to include(admin_webhook_endpoint_path(webhook_endpoint.public_id))
    expect(response.body).not_to include(edit_admin_webhook_endpoint_path(webhook_endpoint.id))
    expect(response.body).not_to include(admin_webhook_endpoint_path(webhook_endpoint.id))

    get admin_microsoft_graph_connections_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(edit_admin_microsoft_graph_connection_path(microsoft_graph_connection.public_id))
    expect(response.body).to include(admin_microsoft_graph_connection_path(microsoft_graph_connection.public_id))
    expect(response.body).not_to include(edit_admin_microsoft_graph_connection_path(microsoft_graph_connection.id))
    expect(response.body).not_to include(admin_microsoft_graph_connection_path(microsoft_graph_connection.id))
  end

  it "renders public_id member links for consent admin resources" do
    get admin_consent_terms_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(edit_admin_consent_term_path(consent_term.public_id))
    expect(response.body).to include(admin_consent_term_path(consent_term.public_id))
    expect(response.body).not_to include(edit_admin_consent_term_path(consent_term.id))
    expect(response.body).not_to include(admin_consent_term_path(consent_term.id))

    get admin_project_consent_settings_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(edit_admin_project_consent_setting_path(project_consent_setting.public_id))
    expect(response.body).to include(admin_project_consent_setting_path(project_consent_setting.public_id))
    expect(response.body).not_to include(edit_admin_project_consent_setting_path(project_consent_setting.id))
    expect(response.body).not_to include(admin_project_consent_setting_path(project_consent_setting.id))
  end

  it "rejects numeric ids for operational admin resources and keeps public_id updates working" do
    get edit_admin_git_import_source_path(git_import_source.id)
    expect(response).to have_http_status(:not_found)

    post sync_admin_git_import_source_path(git_import_source.id)
    expect(response).to have_http_status(:not_found)

    delete admin_git_import_source_path(git_import_source.id)
    expect(response).to have_http_status(:not_found)
    expect(GitImportSource.exists?(git_import_source.id)).to be(true)

    patch admin_webhook_endpoint_path(webhook_endpoint.public_id), params: {
      webhook_endpoint: {
        name: "Portal webhook updated",
        target_url: webhook_endpoint.target_url,
        secret_token: webhook_endpoint.secret_token,
        active: true,
        event_types: webhook_endpoint.normalized_event_types
      }
    }

    expect(response).to redirect_to(admin_webhook_endpoints_path)
    expect(webhook_endpoint.reload.name).to eq("Portal webhook updated")

    get edit_admin_webhook_endpoint_path(webhook_endpoint.id)
    expect(response).to have_http_status(:not_found)

    delete admin_webhook_endpoint_path(webhook_endpoint.id)
    expect(response).to have_http_status(:not_found)
    expect(WebhookEndpoint.exists?(webhook_endpoint.id)).to be(true)

    get edit_admin_microsoft_graph_connection_path(microsoft_graph_connection.id)
    expect(response).to have_http_status(:not_found)

    delete admin_microsoft_graph_connection_path(microsoft_graph_connection.id)
    expect(response).to have_http_status(:not_found)
    expect(MicrosoftGraphConnection.exists?(microsoft_graph_connection.id)).to be(true)
  end

  it "rejects numeric ids for consent admin resources and keeps public_id updates working" do
    patch admin_consent_term_path(consent_term.public_id), params: {
      consent_term: {
        title: "利用同意 改",
        body: consent_term.body,
        version_label: consent_term.version_label,
        consent_scope: consent_term.consent_scope,
        requirement_timing: consent_term.requirement_timing,
        active: true
      }
    }

    expect(response).to redirect_to(admin_consent_terms_path)
    expect(consent_term.reload.title).to eq("利用同意 改")

    get edit_admin_consent_term_path(consent_term.id)
    expect(response).to have_http_status(:not_found)

    delete admin_consent_term_path(consent_term.id)
    expect(response).to have_http_status(:not_found)
    expect(ConsentTerm.exists?(consent_term.id)).to be(true)

    patch admin_project_consent_setting_path(project_consent_setting.public_id), params: {
      project_consent_setting: {
        project_id: project.id,
        consent_term_id: consent_term.id,
        required_on: project_consent_setting.required_on,
        enabled: false
      }
    }

    expect(response).to redirect_to(admin_project_consent_settings_path)
    expect(project_consent_setting.reload.enabled).to be(false)

    get edit_admin_project_consent_setting_path(project_consent_setting.id)
    expect(response).to have_http_status(:not_found)

    delete admin_project_consent_setting_path(project_consent_setting.id)
    expect(response).to have_http_status(:not_found)
    expect(ProjectConsentSetting.exists?(project_consent_setting.id)).to be(true)
  end
end
