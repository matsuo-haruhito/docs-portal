require "rails_helper"

RSpec.describe "Admin external folder sync source project picker", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def json_body
    JSON.parse(response.body)
  end

  def project_picker
    parsed_html.at_css('select[name="external_folder_sync_source[project_id]"]')
  end

  it "returns bounded project search results by code and name" do
    code_match = create(:project, code: "EXT-100", name: "External Folder")
    name_match = create(:project, code: "OPS-200", name: "Needle Workspace")

    max_length = Admin::ExternalFolderSyncSourcesController::PROJECT_SEARCH_QUERY_MAX_LENGTH
    bounded_query = "remote-" + ("a" * (max_length - "remote-".length))
    bounded_match = create(:project, code: "BOUND-100", name: "Target #{bounded_query}")
    suffix_only = create(:project, code: "BOUND-200", name: "Suffix only source")
    21.times do |index|
      create(:project, code: format("LIMIT-%02d", index), name: format("Limit Source %02d", index))
    end

    sign_in_as(admin_user)

    get project_search_admin_external_folder_sync_sources_path, params: { q: "ext" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      a_hash_including("value" => code_match.id, "text" => "EXT-100 / External Folder")
    )

    get project_search_admin_external_folder_sync_sources_path, params: { q: "needle" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      a_hash_including("value" => name_match.id, "text" => "OPS-200 / Needle Workspace")
    )

    get project_search_admin_external_folder_sync_sources_path, params: { q: "  #{bounded_query}   suffix  " }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options")).to contain_exactly(
      a_hash_including("value" => bounded_match.id, "text" => "BOUND-100 / Target #{bounded_query}")
    )
    expect(json_body.fetch("options")).not_to include(a_hash_including("value" => suffix_only.id))

    get project_search_admin_external_folder_sync_sources_path, params: { q: "limit" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("options").size).to eq(Admin::ExternalFolderSyncSourcesController::PROJECT_SEARCH_LIMIT)
    expect(json_body.fetch("options").map { |option| option.fetch("text") }).to all(start_with("LIMIT-"))
  end

  it "returns selected project options for edit and rerender restoration" do
    project = create(:project, code: "SYNC-RESTORE", name: "Sync Restore Project")

    sign_in_as(admin_user)

    get selected_project_admin_external_folder_sync_sources_path, params: { id: project.id }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to include(
      "value" => project.id,
      "text" => "SYNC-RESTORE / Sync Restore Project"
    )

    get selected_project_admin_external_folder_sync_sources_path, params: { id: "missing" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("option")).to be_nil
  end

  it "renders the remote project combobox and restores selected projects on invalid create and edit" do
    project = create(:project, code: "FORM-EXT", name: "External Form Project")
    source = ExternalFolderSyncSource.create!(
      project:,
      created_by: admin_user,
      provider: :google_drive,
      auth_type: :oauth_user,
      name: "Drive source",
      folder_url: "https://drive.google.com/drive/folders/form-ext",
      external_folder_id: "form-ext",
      sync_direction: :external_to_portal,
      conflict_policy: :manual,
      enabled: true,
      auth_config: {}.to_json,
      provider_metadata: {}
    )

    sign_in_as(admin_user)

    get admin_external_folder_sync_sources_path
    expect(response).to have_http_status(:ok)
    picker = project_picker
    expect(picker).to be_present
    expect(picker["data-controller"]).to include("rails-fields-kit--tom-select")
    expect(picker["data-rails-fields-kit--tom-select-kind-value"]).to eq("combobox")
    expect(picker["data-rails-fields-kit--tom-select-url-value"]).to eq(project_search_admin_external_folder_sync_sources_path(format: :json))
    expect(picker["data-rails-fields-kit--tom-select-selected-url-value"]).to eq(selected_project_admin_external_folder_sync_sources_path(format: :json))
    expect(picker["data-rails-fields-kit--tom-select-value-field-value"]).to eq("value")
    expect(picker["data-rails-fields-kit--tom-select-label-field-value"]).to eq("text")
    expect(picker["data-rails-fields-kit--tom-select-search-field-value"]).to eq("text")
    expect(picker["data-rails-fields-kit--tom-select-min-length-value"]).to eq("1")
    expect(picker["data-rails-fields-kit--tom-select-max-options-value"]).to eq("20")

    post admin_external_folder_sync_sources_path, params: {
      external_folder_sync_source: {
        project_id: project.id,
        provider: "google_drive",
        auth_type: "oauth_user",
        name: "",
        folder_url: "https://drive.google.com/drive/folders/invalid-create",
        external_folder_path: "",
        sync_direction: "external_to_portal",
        conflict_policy: "manual",
        enabled: "true",
        auth_config: ""
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(project_picker.at_css(%(option[value="#{project.id}"][selected]))&.text&.squish).to eq("FORM-EXT / External Form Project")
    expect(response.body).to include("SharePoint / OneDrive を準備する")

    get edit_admin_external_folder_sync_source_path(source)

    expect(response).to have_http_status(:ok)
    expect(project_picker.at_css(%(option[value="#{project.id}"][selected]))&.text&.squish).to eq("FORM-EXT / External Form Project")
  end

  it "keeps provider support fields unchanged while using the remote project picker" do
    sign_in_as(admin_user)

    get admin_external_folder_sync_sources_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Google Drive は同期実行まで、SharePoint / OneDrive は metadata 保存までこの画面で扱います。")
    expect(response.body).to include("Google Drive は同期プレビューと同期実行まで利用できます。SharePoint / OneDrive は共有URLからの metadata 保存まで利用でき、差分同期本体と変更通知はこの画面ではまだ実行できません。")
    expect(response.body).not_to include("後続 issue")
    expect(response.body).not_to include("first slice")
    expect(response.body).to include("Google Drive は「OAuthユーザー方式」または「サービスアカウント方式」、SharePoint / OneDrive は「Microsoft Graph接続」を選んでください。")
    expect(parsed_html.at_css('select[name="external_folder_sync_source[provider]"]')).to be_present
    expect(parsed_html.at_css('select[name="external_folder_sync_source[auth_type]"]')).to be_present
    expect(parsed_html.at_css('input[name="external_folder_sync_source[sync_direction]"][type="hidden"]')).to be_present
    expect(parsed_html.at_css('input[name="external_folder_sync_source[conflict_policy]"][type="hidden"]')).to be_present
  end

  it "forbids external users from project picker JSON endpoints" do
    project = create(:project)

    sign_in_as(external_user)

    get project_search_admin_external_folder_sync_sources_path, params: { q: project.code }

    expect(response).to have_http_status(:forbidden)

    get selected_project_admin_external_folder_sync_sources_path, params: { id: project.id }

    expect(response).to have_http_status(:forbidden)
  end
end
