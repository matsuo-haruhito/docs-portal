require "rails_helper"

RSpec.describe "Admin external folder sync provider boundary", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "SYNC001", name: "Sync Project") }

  def create_microsoft_graph_source(name: "SharePoint docs")
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
      provider_metadata: {
        "drive_id" => "drive-#{name.parameterize}",
        "folder_item_id" => "item-#{name.parameterize}",
        "folder_path" => "Shared Documents/#{name}",
        "site_id" => "site-#{name.parameterize}"
      }
    )
  end

  def create_google_drive_source(name: "Drive docs")
    ExternalFolderSyncSource.create!(
      project:,
      created_by: admin_user,
      provider: :google_drive,
      auth_type: :service_account,
      name:,
      folder_url: "https://drive.google.com/drive/folders/#{name.parameterize}",
      external_folder_id: "folder-#{name.parameterize}",
      sync_direction: :external_to_portal,
      conflict_policy: :manual,
      enabled: true,
      auth_config: { client_email: "sync@example.com" }.to_json,
      provider_metadata: {}
    )
  end

  shared_examples "blocks Microsoft Graph sync operation" do |operation_name, request_path|
    it "blocks #{operation_name} for Microsoft Graph metadata-only sources" do
      sign_in_as(admin_user)
      source = create_microsoft_graph_source

      expect(ExternalFolderSync::Runner).not_to receive(:new)
      expect(ExternalFolderSyncJob).not_to receive(:perform_later)
      expect(ExternalFolderSync::GoogleDriveSubscriptionManager).not_to receive(:new)

      instance_exec(source, &request_path)

      expect(response).to redirect_to(admin_external_folder_sync_source_path(source, return_to: admin_external_folder_sync_sources_path))
      follow_redirect!
      expect(response.body).to include("後続 issue で対応予定")
    end
  end

  include_examples "blocks Microsoft Graph sync operation", "apply", lambda { |source|
    post apply_admin_external_folder_sync_source_path(source)
  }

  include_examples "blocks Microsoft Graph sync operation", "enqueue", lambda { |source|
    post enqueue_admin_external_folder_sync_source_path(source)
  }

  include_examples "blocks Microsoft Graph sync operation", "subscribe", lambda { |source|
    post subscribe_admin_external_folder_sync_source_path(source)
  }

  it "keeps Google Drive apply on the runner lane" do
    sign_in_as(admin_user)
    source = create_google_drive_source
    run = instance_double(ExternalFolderSyncRun, items_scanned_count: 3)
    runner = instance_double(ExternalFolderSync::Runner, call: run)

    expect(ExternalFolderSync::Runner).to receive(:new).with(
      source: source,
      mode: :apply,
      actor: admin_user
    ).and_return(runner)

    post apply_admin_external_folder_sync_source_path(source)

    expect(response).to redirect_to(admin_external_folder_sync_source_path(source, return_to: admin_external_folder_sync_sources_path))
  end
end
