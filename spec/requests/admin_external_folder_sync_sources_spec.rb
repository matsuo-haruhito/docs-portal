require "rails_helper"

RSpec.describe "Admin external folder sync sources", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "SYNC001", name: "Sync Project") }

  describe "POST /admin/external_folder_sync_sources" do
    let!(:graph_connection) { create(:microsoft_graph_connection, project:, enabled: true) }

    let(:params) do
      {
        external_folder_sync_source: {
          project_id: project.id,
          provider: "microsoft_graph",
          auth_type: "microsoft_graph_connection",
          name: "SharePoint docs",
          folder_url: "https://contoso.sharepoint.com/:f:/s/TeamDocs/ExampleFolder",
          external_folder_path: "",
          sync_direction: "external_to_portal",
          conflict_policy: "manual",
          enabled: "true",
          auth_config: ""
        }
      }
    end

    it "resolves and saves Microsoft Graph folder metadata" do
      sign_in_as(admin_user)
      resolver = instance_double(
        ExternalFolderSync::MicrosoftGraphFolderResolver,
        resolve: {
          drive_id: "drive-123",
          folder_item_id: "item-456",
          folder_path: "Shared Documents/Policies",
          site_id: "site-789"
        }
      )
      allow(ExternalFolderSync::MicrosoftGraphFolderResolver).to receive(:new).and_return(resolver)

      expect do
        post admin_external_folder_sync_sources_path, params: params
      end.to change(ExternalFolderSyncSource, :count).by(1)

      source = ExternalFolderSyncSource.order(:id).last
      expect(response).to redirect_to(admin_external_folder_sync_source_path(source))
      expect(source.provider).to eq("microsoft_graph")
      expect(source.auth_type).to eq("microsoft_graph_connection")
      expect(source.external_folder_id).to eq("item-456")
      expect(source.external_folder_path).to eq("Shared Documents/Policies")
      expect(source.provider_metadata).to include(
        "drive_id" => "drive-123",
        "folder_item_id" => "item-456",
        "folder_path" => "Shared Documents/Policies",
        "site_id" => "site-789"
      )
      expect(source.auth_config).to eq("{}")

      follow_redirect!
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Drive ID")
      expect(response.body).to include("drive-123")
      expect(response.body).to include("Folder item ID")
      expect(response.body).to include("item-456")
    end

    it "shows a resolver error without creating a source" do
      sign_in_as(admin_user)
      resolver = instance_double(ExternalFolderSync::MicrosoftGraphFolderResolver)
      allow(resolver).to receive(:resolve).and_raise(
        ExternalFolderSync::MicrosoftGraphFolderResolver::Error,
        "共有URLからフォルダ情報を解決できませんでした。共有URLを確認してください。"
      )
      allow(ExternalFolderSync::MicrosoftGraphFolderResolver).to receive(:new).and_return(resolver)

      expect do
        post admin_external_folder_sync_sources_path, params: params
      end.not_to change(ExternalFolderSyncSource, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("共有URLからフォルダ情報を解決できませんでした")
    end
  end

  describe "POST /admin/external_folder_sync_sources/:id/dry_run" do
    it "blocks dry-run for Microsoft Graph metadata-only sources" do
      sign_in_as(admin_user)
      create(:microsoft_graph_connection, project:, enabled: true)
      source = ExternalFolderSyncSource.create!(
        project:,
        created_by: admin_user,
        provider: :microsoft_graph,
        auth_type: :microsoft_graph_connection,
        name: "SharePoint docs",
        folder_url: "https://contoso.sharepoint.com/:f:/s/TeamDocs/ExampleFolder",
        external_folder_id: "item-456",
        external_folder_path: "Shared Documents/Policies",
        sync_direction: :external_to_portal,
        conflict_policy: :manual,
        enabled: true,
        auth_config: {}.to_json,
        provider_metadata: {
          "drive_id" => "drive-123",
          "folder_item_id" => "item-456",
          "folder_path" => "Shared Documents/Policies",
          "site_id" => "site-789"
        }
      )

      post dry_run_admin_external_folder_sync_source_path(source)

      expect(response).to redirect_to(admin_external_folder_sync_source_path(source))
      follow_redirect!
      expect(response.body).to include("後続 issue で対応予定")
      expect(response.body).not_to include("同期プレビュー")
    end
  end
end
