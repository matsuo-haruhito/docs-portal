require "rails_helper"

RSpec.describe "Admin external folder sync source search", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "SYNC", name: "Search Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def action_targets
    parsed_html.css("a[href], form[action]").map do |node|
      node["href"] || node["action"]
    end
  end

  def search_input
    parsed_html.at_css("input[name='q']")
  end

  def create_sync_source(name:, external_folder_id:, external_folder_path:, last_error_message: nil, enabled: true)
    ExternalFolderSyncSource.create!(
      project:,
      created_by: admin_user,
      provider: :google_drive,
      auth_type: :oauth_user,
      name:,
      folder_url: "https://drive.google.com/drive/folders/#{external_folder_id}",
      external_folder_id:,
      external_folder_path:,
      sync_direction: :external_to_portal,
      conflict_policy: :manual,
      enabled:,
      auth_config: {}.to_json,
      last_error_message:
    )
  end

  it "bounds long queries before filtering and preserving return context" do
    sign_in_as(admin_user)

    bounded_query = "x" * Admin::ExternalFolderSyncSourcesController::EXTERNAL_FOLDER_SYNC_SOURCE_SEARCH_QUERY_MAX_LENGTH
    long_query = "  #{bounded_query}ignored-by-normalized-search  "
    matching_source = create_sync_source(
      name: "Target Sync",
      external_folder_id: "target-folder",
      external_folder_path: "/Shared/#{bounded_query}",
      last_error_message: "needs review"
    )
    create_sync_source(
      name: "Other Sync",
      external_folder_id: "other-folder",
      external_folder_path: "/Shared/not-matching",
      last_error_message: "needs review"
    )

    get admin_external_folder_sync_sources_path(q: long_query, review: "errors")

    expect(response).to have_http_status(:ok)
    expect(search_input["value"]).to eq(bounded_query)
    expect(page_text).to include("Target Sync")
    expect(page_text).not_to include("Other Sync")

    normalized_return_to = "#{admin_external_folder_sync_sources_path}?#{Rack::Utils.build_nested_query(review: "errors", q: bounded_query)}"
    expect(action_targets).to include(
      admin_external_folder_sync_source_path(matching_source, return_to: normalized_return_to)
    )
    expect(action_targets).to include(
      edit_admin_external_folder_sync_source_path(matching_source, return_to: normalized_return_to)
    )
  end

  it "keeps blank queries as unfiltered while preserving the list return target" do
    sign_in_as(admin_user)

    first_source = create_sync_source(
      name: "First Sync",
      external_folder_id: "first-folder",
      external_folder_path: "/Shared/first"
    )
    second_source = create_sync_source(
      name: "Second Sync",
      external_folder_id: "second-folder",
      external_folder_path: "/Shared/second"
    )

    get admin_external_folder_sync_sources_path(q: "   ")

    expect(response).to have_http_status(:ok)
    expect(search_input["value"].to_s).to eq("")
    expect(page_text).to include("First Sync", "Second Sync")
    expect(action_targets).to include(
      admin_external_folder_sync_source_path(first_source, return_to: admin_external_folder_sync_sources_path)
    )
    expect(action_targets).to include(
      admin_external_folder_sync_source_path(second_source, return_to: admin_external_folder_sync_sources_path)
    )
  end
end
