require "rails_helper"

RSpec.describe "Admin external folder sync source metadata recheck", type: :request do
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
      external_folder_id: "item-current",
      external_folder_path: "Shared Documents/#{name}",
      sync_direction: :external_to_portal,
      conflict_policy: :manual,
      enabled: true,
      auth_config: {}.to_json,
      provider_metadata: {
        "drive_id" => "drive-current",
        "folder_item_id" => "item-current",
        "folder_path" => "Shared Documents/#{name}",
        "site_id" => "site-current"
      }
    )
  end

  def create_google_drive_source
    ExternalFolderSyncSource.create!(
      project:,
      created_by: admin_user,
      provider: :google_drive,
      auth_type: :oauth_user,
      name: "Drive docs",
      folder_url: "https://drive.google.com/drive/folders/folder-current",
      external_folder_id: "folder-current",
      sync_direction: :external_to_portal,
      conflict_policy: :manual,
      enabled: true,
      auth_config: {}.to_json,
      provider_metadata: {}
    )
  end

  def stub_graph_resolver(source, result: nil, error: nil)
    resolver = instance_double(ExternalFolderSync::MicrosoftGraphFolderResolver)
    if error
      allow(resolver).to receive(:resolve).and_raise(ExternalFolderSync::MicrosoftGraphFolderResolver::Error, error)
    else
      allow(resolver).to receive(:resolve).and_return(result)
    end
    allow(ExternalFolderSync::MicrosoftGraphFolderResolver).to receive(:new).with(source: source).and_return(resolver)
  end

  describe "POST /admin/external_folder_sync_sources/:public_id/recheck_metadata" do
    it "confirms Microsoft Graph metadata when the resolved values match the saved values" do
      sign_in_as(admin_user)
      source = create_microsoft_graph_source
      stub_graph_resolver(
        source,
        result: {
          drive_id: "drive-current",
          folder_item_id: "item-current",
          folder_path: "Shared Documents/SharePoint docs",
          site_id: "site-current"
        }
      )

      post recheck_metadata_admin_external_folder_sync_source_path(source)

      expect(response).to redirect_to(admin_external_folder_sync_source_path(source, return_to: admin_external_folder_sync_sources_path))
      summary = source.reload.provider_metadata.fetch("last_metadata_recheck")
      expect(summary).to include(
        "source_public_id" => source.public_id,
        "status" => "matched",
        "matched_labels" => ["Drive ID", "Folder item ID", "Folder path", "Site ID"],
        "changed_labels" => []
      )
      expect(summary["checked_at"]).to be_present
      expect(summary["actor_id"]).to eq(admin_user.id)
      follow_redirect!
      expect(response.body).to include("保存済み metadata を再確認しました。")
      expect(response.body).to include("Drive ID / Folder item ID / Folder path / Site ID は現在の Microsoft Graph 解決結果と一致しています。")
    end

    it "reports changed fields without updating the saved metadata values" do
      sign_in_as(admin_user)
      source = create_microsoft_graph_source
      original_external_folder_id = source.external_folder_id
      original_external_folder_path = source.external_folder_path
      original_provider_metadata = source.provider_metadata.deep_dup
      stub_graph_resolver(
        source,
        result: {
          drive_id: "drive-changed",
          folder_item_id: "item-current",
          folder_path: "Shared Documents/Changed docs",
          site_id: "site-current"
        }
      )

      post recheck_metadata_admin_external_folder_sync_source_path(source)

      expect(response).to redirect_to(admin_external_folder_sync_source_path(source, return_to: admin_external_folder_sync_sources_path))
      follow_redirect!
      expect(response.body).to include("差分があります: Drive ID / Folder path")
      expect(response.body).to include("保存済み値は変更していません")
      source.reload
      expect(source.external_folder_id).to eq(original_external_folder_id)
      expect(source.external_folder_path).to eq(original_external_folder_path)
      expect(source.provider_metadata.except("last_metadata_recheck")).to eq(original_provider_metadata)
      summary = source.provider_metadata.fetch("last_metadata_recheck")
      expect(summary).to include(
        "status" => "changed",
        "matched_labels" => ["Folder item ID", "Site ID"],
        "changed_labels" => ["Drive ID", "Folder path"]
      )
      expect(summary.to_json).not_to include("drive-changed")
      expect(summary.to_json).not_to include("Shared Documents/Changed docs")
    end

    it "treats Google Drive sources as unsupported for metadata recheck" do
      sign_in_as(admin_user)
      source = create_google_drive_source
      expect(ExternalFolderSync::MicrosoftGraphFolderResolver).not_to receive(:new)

      post recheck_metadata_admin_external_folder_sync_source_path(source)

      expect(response).to redirect_to(admin_external_folder_sync_source_path(source, return_to: admin_external_folder_sync_sources_path))
      follow_redirect!
      expect(response.body).to include("保存済み metadata の再確認は SharePoint / OneDrive の metadata-only source で利用できます。")
      expect(source.reload.provider_metadata).to eq({})
    end

    it "returns a resolver error without running sync or exposing raw error details" do
      sign_in_as(admin_user)
      source = create_microsoft_graph_source
      original_external_folder_id = source.external_folder_id
      original_external_folder_path = source.external_folder_path
      original_provider_metadata = source.provider_metadata.deep_dup
      stub_graph_resolver(source, error: "raw Graph payload with client_secret=hidden-token")
      expect(ExternalFolderSync::Runner).not_to receive(:new)
      expect(ExternalFolderSyncJob).not_to receive(:perform_later)

      post recheck_metadata_admin_external_folder_sync_source_path(source)

      expect(response).to redirect_to(admin_external_folder_sync_source_path(source, return_to: admin_external_folder_sync_sources_path))
      follow_redirect!
      expect(response.body).to include("保存済み metadata を再確認できませんでした。")
      expect(response.body).to include("Microsoft Graph接続・共有URL・権限を確認してください。")
      expect(response.body).not_to include("client_secret")
      expect(response.body).not_to include("hidden-token")
      source.reload
      expect(source.external_folder_id).to eq(original_external_folder_id)
      expect(source.external_folder_path).to eq(original_external_folder_path)
      expect(source.provider_metadata.except("last_metadata_recheck")).to eq(original_provider_metadata)
      summary = source.provider_metadata.fetch("last_metadata_recheck")
      expect(summary).to include(
        "status" => "error",
        "matched_labels" => [],
        "changed_labels" => [],
        "error_message" => "Microsoft Graph接続・共有URL・権限を確認してください。"
      )
      expect(summary.to_json).not_to include("client_secret")
      expect(summary.to_json).not_to include("hidden-token")
    end
  end
end
