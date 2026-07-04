require "rails_helper"
require "uri"

RSpec.describe "Admin external folder sync OAuth connection maintenance mode", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "SYNC-OAUTH", name: "Sync OAuth") }
  let(:source) do
    create(
      :external_folder_sync_source,
      project:,
      created_by: admin_user,
      provider: :google_drive,
      auth_type: :oauth_user,
      name: "Drive OAuth",
      auth_config:
    )
  end
  let(:auth_config) { {}.to_json }

  around do |example|
    original_maintenance = ENV[Admin::ExternalFolderSyncOauthConnectionsController::READ_ONLY_MAINTENANCE_ENV]
    original_client_id = ENV["GOOGLE_DRIVE_OAUTH_CLIENT_ID"]
    original_client_secret = ENV["GOOGLE_DRIVE_OAUTH_CLIENT_SECRET"]

    ENV[Admin::ExternalFolderSyncOauthConnectionsController::READ_ONLY_MAINTENANCE_ENV] = maintenance_env_value
    ENV["GOOGLE_DRIVE_OAUTH_CLIENT_ID"] = "client-id"
    ENV["GOOGLE_DRIVE_OAUTH_CLIENT_SECRET"] = "client-secret"

    example.run
  ensure
    restore_env(Admin::ExternalFolderSyncOauthConnectionsController::READ_ONLY_MAINTENANCE_ENV, original_maintenance)
    restore_env("GOOGLE_DRIVE_OAUTH_CLIENT_ID", original_client_id)
    restore_env("GOOGLE_DRIVE_OAUTH_CLIENT_SECRET", original_client_secret)
  end

  describe "when read-only maintenance is enabled" do
    let(:maintenance_env_value) { "1" }

    it "keeps source detail readable" do
      sign_in_as(admin_user)

      get admin_external_folder_sync_source_path(source)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Drive OAuth")
    end

    it "blocks starting the OAuth connection before redirecting to Google" do
      sign_in_as(admin_user)

      get new_admin_external_folder_sync_source_external_folder_sync_oauth_connection_path(source)

      expect(response).to redirect_to(admin_external_folder_sync_source_path(source))
      expect(response.location).to end_with("/admin/external_folder_sync_sources/#{source.public_id}")
      expect(flash[:alert]).to include("メンテナンス中")
    end

    it "blocks callback token exchange and preserves the existing auth config" do
      sign_in_as(admin_user)

      with_read_only_maintenance(nil) do
        get new_admin_external_folder_sync_source_external_folder_sync_oauth_connection_path(source)
      end
      state = oauth_state_from_redirect

      expect(Net::HTTP).not_to receive(:post_form)

      get admin_callback_external_folder_sync_oauth_connections_path, params: { state:, code: "oauth-code" }

      expect(response).to redirect_to(admin_external_folder_sync_source_path(source))
      expect(flash[:alert]).to include("メンテナンス中")
      expect(source.reload.auth_config_json).to eq({})
    end

    it "blocks disconnecting an existing OAuth token" do
      source.update!(auth_config: { refresh_token: "refresh-token", access_token: "access-token" }.to_json)
      sign_in_as(admin_user)

      delete admin_external_folder_sync_source_external_folder_sync_oauth_connection_path(source)

      expect(response).to redirect_to(admin_external_folder_sync_source_path(source))
      expect(flash[:alert]).to include("メンテナンス中")
      expect(source.reload.auth_config_json).to include(
        "refresh_token" => "refresh-token",
        "access_token" => "access-token"
      )
    end
  end

  describe "when read-only maintenance is disabled" do
    let(:maintenance_env_value) { nil }
    let(:auth_config) { { refresh_token: "refresh-token", access_token: "access-token" }.to_json }

    it "keeps the existing disconnect behavior" do
      sign_in_as(admin_user)

      delete admin_external_folder_sync_source_external_folder_sync_oauth_connection_path(source)

      expect(response).to redirect_to(admin_external_folder_sync_source_path(source))
      expect(flash[:notice]).to include("解除しました")
      expect(source.reload.auth_config_json).to eq({})
    end
  end

  private

  def oauth_state_from_redirect
    Rack::Utils.parse_query(URI(response.location).query).fetch("state")
  end

  def with_read_only_maintenance(value)
    original = ENV[Admin::ExternalFolderSyncOauthConnectionsController::READ_ONLY_MAINTENANCE_ENV]
    ENV[Admin::ExternalFolderSyncOauthConnectionsController::READ_ONLY_MAINTENANCE_ENV] = value
    yield
  ensure
    restore_env(Admin::ExternalFolderSyncOauthConnectionsController::READ_ONLY_MAINTENANCE_ENV, original)
  end

  def restore_env(key, value)
    if value.nil?
      ENV.delete(key)
    else
      ENV[key] = value
    end
  end
end
