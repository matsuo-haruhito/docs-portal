require "rails_helper"

RSpec.describe "Admin external folder sync source project picker", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def project_select
    parsed_html.at_css("select[name='external_folder_sync_source[project_id]']")
  end

  it "renders the project picker as remote search while keeping only the selected project option" do
    sign_in_as(admin_user)
    selected_project = create(:project, code: "SYNC-SELECTED", name: "Selected Project")
    hidden_project = create(:project, code: "SYNC-HIDDEN", name: "Hidden Project")
    source = create(:external_folder_sync_source, project: selected_project, name: "Selected Source")

    get edit_admin_external_folder_sync_source_path(source)

    expect(response).to have_http_status(:ok)
    expect(project_select).to be_present
    expect(project_select["data-rails-fields-kit--tom-select-url-value"]).to eq(project_search_admin_external_folder_sync_sources_path)
    expect(project_select["data-rails-fields-kit--tom-select-selected-url-value"]).to eq(selected_project_admin_external_folder_sync_sources_path)
    expect(project_select["data-rails-fields-kit--tom-select-query-param-value"]).to eq("q")
    expect(project_select["data-rails-fields-kit--tom-select-selected-param-value"]).to eq("id")
    expect(project_select["data-rails-fields-kit--tom-select-value-field-value"]).to eq("id")
    expect(project_select["data-rails-fields-kit--tom-select-label-field-value"]).to eq("text")
    expect(project_select["data-rails-fields-kit--tom-select-option-description-field-value"]).to eq("code")
    expect(project_select["data-rails-fields-kit--tom-select-max-options-value"]).to eq(Admin::ExternalFolderSyncSourcesController::PROJECT_SEARCH_LIMIT.to_s)
    expect(project_select.at_css(%(option[value="#{selected_project.id}"]))).to be_present
    expect(page_text).to include("Selected Project")
    expect(page_text).not_to include("Hidden Project")
  end

  it "searches projects by bounded project code or name and returns remote options" do
    sign_in_as(admin_user)
    bounded_query = "x" * Admin::ExternalFolderSyncSourcesController::PROJECT_SEARCH_QUERY_MAX_LENGTH
    matching_project = create(:project, code: "SYNC-MATCH", name: "Project #{bounded_query}")
    other_project = create(:project, code: "SYNC-OTHER", name: "Other Project")

    get project_search_admin_external_folder_sync_sources_path(q: "  #{bounded_query}ignored-tail  ")

    expect(response).to have_http_status(:ok)
    payload = JSON.parse(response.body)
    option_ids = payload.fetch("options").map { |option| option.fetch("id") }
    expect(option_ids).to include(matching_project.id)
    expect(option_ids).not_to include(other_project.id)
    expect(payload.fetch("options").first).to include(
      "id" => matching_project.id,
      "value" => matching_project.id,
      "text" => "#{matching_project.code} / #{matching_project.name}",
      "code" => matching_project.code,
      "name" => matching_project.name
    )
    expect(payload.fetch("options").size).to be <= Admin::ExternalFolderSyncSourcesController::PROJECT_SEARCH_LIMIT
  end

  it "returns a selected project option for persisted values" do
    sign_in_as(admin_user)
    project = create(:project, code: "SYNC-RESTORE", name: "Restore Project")

    get selected_project_admin_external_folder_sync_sources_path(id: project.id)

    expect(response).to have_http_status(:ok)
    payload = JSON.parse(response.body)
    expect(payload.fetch("option")).to include(
      "id" => project.id,
      "value" => project.id,
      "text" => "#{project.code} / #{project.name}",
      "code" => project.code,
      "name" => project.name
    )
  end

  it "restores the submitted project option on validation errors" do
    sign_in_as(admin_user)
    project = create(:project, code: "SYNC-RERENDER", name: "Rerender Project")
    create(:project, code: "SYNC-UNRELATED", name: "Unrelated Project")

    post admin_external_folder_sync_sources_path, params: {
      external_folder_sync_source: {
        project_id: project.id,
        provider: "google_drive",
        auth_type: "oauth_user",
        name: "",
        folder_url: "",
        sync_direction: "external_to_portal",
        conflict_policy: "manual",
        enabled: "true"
      }
    }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(project_select.at_css(%(option[value="#{project.id}"]))).to be_present
    expect(page_text).to include("Rerender Project")
    expect(page_text).not_to include("Unrelated Project")
  end
end
