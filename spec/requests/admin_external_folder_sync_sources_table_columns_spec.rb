require "rails_helper"

RSpec.describe "Admin external folder sync source table columns", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "SYNC001", name: "Sync Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def create_google_drive_source
    ExternalFolderSyncSource.create!(
      project:,
      created_by: admin_user,
      provider: :google_drive,
      auth_type: :oauth_user,
      name: "Drive source",
      folder_url: "https://drive.google.com/drive/folders/drive-source",
      external_folder_id: "folder-drive-source",
      sync_direction: :external_to_portal,
      conflict_policy: :manual,
      enabled: true,
      auth_config: {}.to_json
    )
  end

  it "keeps body cells aligned with the table preference columns" do
    sign_in_as(admin_user)
    create_google_drive_source

    get admin_external_folder_sync_sources_path

    expect(response).to have_http_status(:ok)

    expected_keys = %w[
      project
      name
      provider
      external_folder_location
      status
      last_synced_at
      latest_safety
      warning_count
      latest_error
      actions
    ]
    table = parsed_html.at_css("table")
    header_keys = table.css("thead th[data-rails-table-preferences-column-key]").map { _1["data-rails-table-preferences-column-key"] }
    row = table.css("tbody tr").find { _1.text.include?("Drive source") }
    body_keys = row.css("> td[data-rails-table-preferences-column-key]").map { _1["data-rails-table-preferences-column-key"] }

    expect(header_keys).to eq(expected_keys)
    expect(body_keys).to eq(expected_keys)
    expect(row.css("> td").size).to eq(expected_keys.size)
    expect(row.text.scan("Drive source").size).to eq(1)
    expect(row.text).to include("同期対応")
  end
end
