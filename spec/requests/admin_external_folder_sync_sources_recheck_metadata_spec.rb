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
      external_folder_id: "item-original",
      external_folder_path: "Shared Documents/Original",
      sync_direction: :external_to_portal,
      conflict_policy: :manual,
      enabled: true,
      auth_config: {}.to_json,
      provider_metadata: {
        "drive_id" => "drive-original",
        "folder_item_id" => "item-original",
        "folder_path" => "Shared Documents/Original",
        "site_id" => "site-original"
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

  def stub_graph_resolver(resolved_metadata)
    resolver = instance_double(
      ExternalFolderSync::MicrosoftGraphFolderResolver,
      resolve: resolved_metadata
    )
    allow(ExternalFolderSync::MicrosoftGraphFolderResolver).to receive(:new).and_return(resolver)
  end

  it "shows field-level matches when saved metadata still matches Microsoft Graph" do
    sign_in_as(admin_user)
    source = create_microsoft_graph_source
    stub_graph_resolver(
      drive_id: "drive-original",
      folder_item_id: "item-original",
      folder_path: "Shared Documents/Original",
      site_id: "site-original"
    )

    post recheck_metadata_admin_external_folder_sync_source_path(source)

    expect(response).to redirect_to(admin_external_folder_sync_source_path(source, return_to: admin_external_folder_sync_sources_path))
    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("保存済み metadata 再確認結果")
    expect(response.body).to include("保存済み metadata は現在の Microsoft Graph 解決結果と一致しています。")
    expect(response.body).to include("一致: Drive ID / Folder item ID / Folder path / Site ID")
  end

  it "shows changed field labels without rewriting the saved metadata" do
    sign_in_as(admin_user)
    source = create_microsoft_graph_source
    saved_external_folder_id = source.external_folder_id
    saved_external_folder_path = source.external_folder_path
    saved_provider_metadata = source.provider_metadata.deep_dup
    stub_graph_resolver(
      drive_id: "drive-current",
      folder_item_id: "item-original",
      folder_path: "Shared Documents/Current",
      site_id: "site-original"
    )

    post recheck_metadata_admin_external_folder_sync_source_path(source)

    expect(response).to redirect_to(admin_external_folder_sync_source_path(source, return_to: admin_external_folder_sync_sources_path))
    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("差分あり: Drive ID / Folder path")
    expect(response.body).to include("一致: Folder item ID / Site ID")
    expect(response.body).to include("保存済み値は変更していません。必要なら設定を編集して保存し直してください。")
    expect(source.reload.external_folder_id).to eq(saved_external_folder_id)
    expect(source.external_folder_path).to eq(saved_external_folder_path)
    expect(source.provider_metadata).to eq(saved_provider_metadata)
  end

  it "keeps Google Drive sources on the provider boundary without resolving Microsoft Graph metadata" do
    sign_in_as(admin_user)
    source = create_google_drive_source
    expect(ExternalFolderSync::MicrosoftGraphFolderResolver).not_to receive(:new)

    post recheck_metadata_admin_external_folder_sync_source_path(source)

    expect(response).to redirect_to(admin_external_folder_sync_source_path(source, return_to: admin_external_folder_sync_sources_path))
    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("保存済み metadata の再確認は SharePoint / OneDrive の metadata-only source で利用できます。")
    expect(response.body).not_to include("同期しました")
    expect(response.body).not_to include("バックグラウンド同期を登録しました")
  end

  it "shows a bounded resolver error message without exposing raw Graph payloads" do
    sign_in_as(admin_user)
    source = create_microsoft_graph_source
    saved_external_folder_id = source.external_folder_id
    saved_external_folder_path = source.external_folder_path
    saved_provider_metadata = source.provider_metadata.deep_dup
    unsafe_error_message = <<~MESSAGE.squish
      Microsoft Graph returned 403 Authorization: Bearer secret-access-token
      client_secret=super-secret-value {"error":{"message":"rawGraphPayload"}}
    MESSAGE
    resolver = instance_double(ExternalFolderSync::MicrosoftGraphFolderResolver)
    allow(resolver).to receive(:resolve).and_raise(
      ExternalFolderSync::MicrosoftGraphFolderResolver::Error,
      unsafe_error_message
    )
    allow(ExternalFolderSync::MicrosoftGraphFolderResolver).to receive(:new).and_return(resolver)

    post recheck_metadata_admin_external_folder_sync_source_path(source)

    expect(response).to redirect_to(admin_external_folder_sync_source_path(source, return_to: admin_external_folder_sync_sources_path))
    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("保存済み metadata を再確認できませんでした。Microsoft Graph接続・共有URL・権限を確認してください。")
    expect(response.body).not_to include("Authorization: Bearer")
    expect(response.body).not_to include("secret-access-token")
    expect(response.body).not_to include("client_secret")
    expect(response.body).not_to include("super-secret-value")
    expect(response.body).not_to include("rawGraphPayload")
    expect(source.reload.external_folder_id).to eq(saved_external_folder_id)
    expect(source.external_folder_path).to eq(saved_external_folder_path)
    expect(source.provider_metadata).to eq(saved_provider_metadata)
  end
end
