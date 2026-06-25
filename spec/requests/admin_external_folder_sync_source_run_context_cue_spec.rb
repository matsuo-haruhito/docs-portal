require "rails_helper"

RSpec.describe "Admin external folder sync source run context cues", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "SYNC001", name: "Sync Project") }

  def page_text
    Nokogiri::HTML(response.body).text.squish
  end

  def create_google_drive_source(name:, last_error_message: nil)
    ExternalFolderSyncSource.create!(
      project:,
      created_by: admin_user,
      provider: :google_drive,
      auth_type: :oauth_user,
      name:,
      folder_url: "https://drive.google.com/drive/folders/#{name.parameterize}",
      external_folder_id: "folder-#{name.parameterize}",
      sync_direction: :external_to_portal,
      conflict_policy: :manual,
      enabled: true,
      auth_config: {}.to_json,
      last_error_message:
    )
  end

  def create_microsoft_graph_source(name:, last_error_message: nil)
    create(:microsoft_graph_connection, project:, enabled: true)

    ExternalFolderSyncSource.create!(
      project:,
      created_by: admin_user,
      provider: :microsoft_graph,
      auth_type: :microsoft_graph_connection,
      name:,
      folder_url: "https://contoso.sharepoint.com/:f:/s/#{name.parameterize}/ExampleFolder",
      external_folder_id: "item-#{name.parameterize}",
      external_folder_path: "Shared Documents/#{name}",
      sync_direction: :external_to_portal,
      conflict_policy: :manual,
      enabled: true,
      auth_config: {}.to_json,
      last_error_message:,
      provider_metadata: {
        "drive_id" => "drive-#{name.parameterize}",
        "folder_item_id" => "item-#{name.parameterize}",
        "folder_path" => "Shared Documents/#{name}"
      }
    )
  end

  it "shows the latest run timestamp, mode, and status on warning filter rows" do
    sign_in_as(admin_user)
    stale_warning_source = create_google_drive_source(name: "Finance stale warning")
    current_warning_source = create_google_drive_source(name: "Finance current warning")
    stale_started_at = Time.zone.local(2026, 6, 20, 9, 0)
    current_started_at = Time.zone.local(2026, 6, 20, 10, 0)

    ExternalFolderSyncRun.create!(
      external_folder_sync_source: stale_warning_source,
      status: :completed,
      mode: :dry_run,
      started_at: stale_started_at,
      summary_json: { "conflict_warnings_count" => 3 }
    )
    ExternalFolderSyncRun.create!(
      external_folder_sync_source: stale_warning_source,
      status: :completed,
      mode: :dry_run,
      started_at: current_started_at,
      summary_json: { "conflict_warnings_count" => 0 }
    )
    ExternalFolderSyncRun.create!(
      external_folder_sync_source: current_warning_source,
      status: :completed,
      mode: :dry_run,
      started_at: current_started_at,
      summary_json: { "conflict_warnings_count" => 2 }
    )

    get admin_external_folder_sync_sources_path, params: { review: "warnings", q: "finance" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(current_warning_source.name)
    expect(page_text).not_to include(stale_warning_source.name)
    expect(page_text).to include("直近run: #{I18n.l(current_started_at)} / 同期プレビュー / 完了")
    expect(page_text).to include("警告あり (1)")
  end

  it "labels latest error origin without exposing raw secret-like values" do
    sign_in_as(admin_user)
    run_error_source = create_google_drive_source(name: "Run error source")
    metadata_error_source = create_microsoft_graph_source(
      name: "Metadata error source",
      last_error_message: "secret=metadata-secret Drive metadata failed"
    )
    started_at = Time.zone.local(2026, 6, 20, 10, 30)

    ExternalFolderSyncRun.create!(
      external_folder_sync_source: run_error_source,
      status: :failed,
      mode: :apply,
      started_at:,
      error_message: "token=run-secret apply failed",
      summary_json: {}
    )

    get admin_external_folder_sync_sources_path, params: { review: "errors" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(run_error_source.name)
    expect(page_text).to include(metadata_error_source.name)
    expect(page_text).to include("由来: 直近run")
    expect(page_text).to include("由来: 同期元metadata")
    expect(page_text).to include("直近run: #{I18n.l(started_at)} / 同期 / 失敗")
    expect(page_text).to include("メタデータ確認のみ")
    expect(response.body).not_to include("run-secret")
    expect(response.body).not_to include("metadata-secret")
  end
end
