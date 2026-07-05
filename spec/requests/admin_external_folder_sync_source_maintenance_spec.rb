require "rails_helper"

RSpec.describe "Admin external folder sync source maintenance mode", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "EXT-MAINT", name: "External Maintenance") }

  around do |example|
    original_value = ENV[Admin::ExternalFolderSyncSourcesController::READ_ONLY_MAINTENANCE_ENV]
    ENV[Admin::ExternalFolderSyncSourcesController::READ_ONLY_MAINTENANCE_ENV] = maintenance_env_value
    example.run
  ensure
    if original_value.nil?
      ENV.delete(Admin::ExternalFolderSyncSourcesController::READ_ONLY_MAINTENANCE_ENV)
    else
      ENV[Admin::ExternalFolderSyncSourcesController::READ_ONLY_MAINTENANCE_ENV] = original_value
    end
  end

  def page_text
    Nokogiri::HTML(response.body).text.squish
  end

  def google_drive_source_params(name: "Maintenance Drive", folder_url: "https://drive.google.com/drive/folders/maintenance-drive", enabled: "true")
    {
      project_id: project.id,
      provider: "google_drive",
      auth_type: "service_account",
      name: name,
      folder_url: folder_url,
      external_folder_path: "",
      sync_direction: "external_to_portal",
      conflict_policy: "manual",
      enabled: enabled,
      auth_config: { client_email: "sync@example.com" }.to_json
    }
  end

  def create_google_drive_source(name: "Readable Drive", enabled: true)
    ExternalFolderSyncSource.create!(
      project: project,
      created_by: admin_user,
      provider: :google_drive,
      auth_type: :service_account,
      name: name,
      folder_url: "https://drive.google.com/drive/folders/#{name.parameterize}",
      external_folder_id: "folder-#{name.parameterize}",
      sync_direction: :external_to_portal,
      conflict_policy: :manual,
      enabled: enabled,
      auth_config: { client_email: "sync@example.com" }.to_json,
      provider_metadata: {}
    )
  end

  describe "when read-only maintenance is enabled" do
    let(:maintenance_env_value) { "1" }

    it "keeps list, detail, project lookup, and recent run metadata readable" do
      sign_in_as(admin_user)
      source = create_google_drive_source(name: "Readable source")
      ExternalFolderSyncRun.create!(
        external_folder_sync_source: source,
        status: :completed,
        mode: :dry_run,
        started_at: Time.current,
        summary_json: { "conflict_warnings_count" => 1 }
      )

      get admin_external_folder_sync_sources_path, params: { q: "readable", review: "warnings" }

      expect(response).to have_http_status(:ok)
      expect(page_text).to include("Readable source")
      expect(page_text).to include("現在の絞り込み: warning あり / 検索: readable")
      expect(page_text).to include("直近run")

      get admin_external_folder_sync_source_path(source)

      expect(response).to have_http_status(:ok)
      expect(page_text).to include("Readable source")
      expect(page_text).to include("同期履歴")

      get project_search_admin_external_folder_sync_sources_path(format: :json), params: { q: "ext-maint" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).fetch("options")).to contain_exactly(
        include("value" => project.id, "text" => "EXT-MAINT / External Maintenance")
      )

      get selected_project_admin_external_folder_sync_sources_path(format: :json), params: { id: project.id }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).fetch("option")).to include("value" => project.id)
    end

    it "blocks source creation before saving provider metadata" do
      sign_in_as(admin_user)

      expect do
        post admin_external_folder_sync_sources_path, params: {
          external_folder_sync_source: google_drive_source_params(name: "Blocked create")
        }
      end.not_to change(ExternalFolderSyncSource, :count)

      expect(response).to redirect_to(admin_external_folder_sync_sources_path)
      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(page_text).to include("メンテナンス中のため外部フォルダ同期設定の作成・更新・削除は停止しています")
    end

    it "blocks source updates without changing metadata or enabled state" do
      sign_in_as(admin_user)
      source = create_google_drive_source(name: "Original source", enabled: true)

      patch admin_external_folder_sync_source_path(source), params: {
        external_folder_sync_source: google_drive_source_params(
          name: "Changed source",
          folder_url: "https://drive.google.com/drive/folders/changed-folder",
          enabled: "false"
        )
      }

      expect(response).to redirect_to(edit_admin_external_folder_sync_source_path(source, return_to: admin_external_folder_sync_sources_path))
      source.reload
      expect(source.name).to eq("Original source")
      expect(source.folder_url).to eq("https://drive.google.com/drive/folders/original-source")
      expect(source.external_folder_id).to eq("folder-original-source")
      expect(source.enabled).to be(true)
    end

    it "blocks source deletion" do
      sign_in_as(admin_user)
      source = create_google_drive_source(name: "Delete source")

      expect do
        delete admin_external_folder_sync_source_path(source)
      end.not_to change(ExternalFolderSyncSource, :count)

      expect(response).to redirect_to(admin_external_folder_sync_sources_path)
      expect(ExternalFolderSyncSource.exists?(source.id)).to be(true)
    end

    it "does not add the CRUD guard to execution actions" do
      sign_in_as(admin_user)
      source = create_google_drive_source(name: "Dry run source")
      run = instance_double(ExternalFolderSyncRun, items_scanned_count: 4)
      runner = instance_double(ExternalFolderSync::Runner, call: run)
      allow(ExternalFolderSync::Runner).to receive(:new).and_return(runner)

      post dry_run_admin_external_folder_sync_source_path(source)

      expect(ExternalFolderSync::Runner).to have_received(:new).with(source: source, mode: :dry_run, actor: admin_user)
      expect(response).to redirect_to(admin_external_folder_sync_source_path(source, return_to: admin_external_folder_sync_sources_path))
    end
  end

  describe "when read-only maintenance is disabled" do
    let(:maintenance_env_value) { nil }

    it "keeps the existing create, update, and destroy behavior" do
      sign_in_as(admin_user)

      expect do
        post admin_external_folder_sync_sources_path, params: {
          external_folder_sync_source: google_drive_source_params(name: "Allowed create")
        }
      end.to change(ExternalFolderSyncSource, :count).by(1)

      source = ExternalFolderSyncSource.order(:id).last
      expect(response).to redirect_to(admin_external_folder_sync_source_path(source, return_to: admin_external_folder_sync_sources_path))
      expect(source.name).to eq("Allowed create")
      expect(source.external_folder_id).to eq("maintenance-drive")

      patch admin_external_folder_sync_source_path(source), params: {
        external_folder_sync_source: google_drive_source_params(
          name: "Allowed update",
          folder_url: "https://drive.google.com/drive/folders/allowed-update",
          enabled: "false"
        )
      }

      expect(response).to redirect_to(admin_external_folder_sync_source_path(source, return_to: admin_external_folder_sync_sources_path))
      source.reload
      expect(source.name).to eq("Allowed update")
      expect(source.external_folder_id).to eq("allowed-update")
      expect(source.enabled).to be(false)

      expect do
        delete admin_external_folder_sync_source_path(source)
      end.to change(ExternalFolderSyncSource, :count).by(-1)
    end
  end
end
