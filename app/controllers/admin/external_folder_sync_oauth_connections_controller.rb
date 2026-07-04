require "json"
require "net/http"
require "uri"

class Admin::ExternalFolderSyncOauthConnectionsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_external_folder_sync_source, only: %i[new destroy]

  GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth".freeze
  GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token".freeze
  DRIVE_SCOPE = "https://www.googleapis.com/auth/drive.readonly https://www.googleapis.com/auth/drive.file".freeze
  READ_ONLY_MAINTENANCE_ENV = "READ_ONLY_MAINTENANCE".freeze
  READ_ONLY_MAINTENANCE_MESSAGE = "メンテナンス中のためGoogle Drive OAuth接続の開始・完了・解除は停止しています。外部フォルダ同期設定と同期履歴は閲覧できます。".freeze
  GOOGLE_OAUTH_ENV_KEYS = %w[
    GOOGLE_DRIVE_OAUTH_CLIENT_ID
    GOOGLE_DRIVE_OAUTH_CLIENT_SECRET
  ].freeze

  def new
    unless @external_folder_sync_source.google_drive? && @external_folder_sync_source.oauth_user?
      redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), alert: "OAuth接続はGoogle DriveのOAuthユーザー方式でのみ利用できます。"
      return
    end

    if read_only_maintenance?
      redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), alert: READ_ONLY_MAINTENANCE_MESSAGE
      return
    end

    missing_keys = missing_google_oauth_env_keys
    if missing_keys.any?
      redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), alert: "Google Drive OAuth設定が未設定です: #{missing_keys.join(', ')}"
      return
    end

    state = oauth_state_for(@external_folder_sync_source)
    session[:external_folder_sync_oauth_state] = state

    redirect_to oauth_authorization_url(state), allow_other_host: true
  end

  def callback
    state = verified_state!
    source = ExternalFolderSyncSource.find_by!(public_id: state.fetch("source_public_id"))

    if read_only_maintenance?
      redirect_to admin_external_folder_sync_source_path(source), alert: READ_ONLY_MAINTENANCE_MESSAGE
      return
    end

    token = exchange_code!(params.require(:code))
    source.merge_auth_config!(
      refresh_token: token.fetch("refresh_token", source.auth_config_json["refresh_token"]),
      access_token: token["access_token"],
      expires_at: token["expires_in"].present? ? Time.current.advance(seconds: token["expires_in"].to_i).iso8601 : nil,
      scope: token["scope"],
      token_type: token["token_type"]
    )

    redirect_to admin_external_folder_sync_source_path(source), notice: "Google Drive OAuth接続を完了しました。"
  rescue ActiveSupport::MessageVerifier::InvalidSignature, KeyError, ActionController::ParameterMissing => e
    redirect_to admin_external_folder_sync_sources_path, alert: "OAuth接続に失敗しました: #{e.message}"
  end

  def destroy
    if read_only_maintenance?
      redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), alert: READ_ONLY_MAINTENANCE_MESSAGE
      return
    end

    @external_folder_sync_source.update!(auth_config: {}.to_json)
    redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), notice: "Google Drive OAuth接続を解除しました。"
  end

  private

  def set_external_folder_sync_source
    @external_folder_sync_source = ExternalFolderSyncSource.find_by!(public_id: params[:external_folder_sync_source_public_id])
  end

  def oauth_authorization_url(state)
    uri = URI(GOOGLE_AUTH_URL)
    uri.query = URI.encode_www_form(
      client_id: google_client_id,
      redirect_uri: oauth_callback_url,
      response_type: "code",
      scope: DRIVE_SCOPE,
      access_type: "offline",
      prompt: "consent",
      state:
    )
    uri.to_s
  end

  def exchange_code!(code)
    response = Net::HTTP.post_form(URI(GOOGLE_TOKEN_URL), {
      code:,
      client_id: google_client_id,
      client_secret: google_client_secret,
      redirect_uri: oauth_callback_url,
      grant_type: "authorization_code"
    })
    body = JSON.parse(response.body.presence || "{}")
    return body if response.is_a?(Net::HTTPSuccess)

    raise KeyError, body["error_description"] || body["error"] || response.message
  end

  def oauth_callback_url
    admin_callback_external_folder_sync_oauth_connections_url
  end

  def oauth_state_for(source)
    verifier.generate({
      source_public_id: source.public_id,
      nonce: SecureRandom.hex(16),
      issued_at: Time.current.to_i
    })
  end

  def verified_state!
    state = params.require(:state)
    expected = session.delete(:external_folder_sync_oauth_state).to_s
    unless expected.present? && ActiveSupport::SecurityUtils.secure_compare(expected, state)
      raise ActiveSupport::MessageVerifier::InvalidSignature, "OAuth state mismatch"
    end

    verifier.verify(state).with_indifferent_access
  end

  def verifier
    ActiveSupport::MessageVerifier.new(Rails.application.secret_key_base, digest: "SHA256")
  end

  def missing_google_oauth_env_keys
    GOOGLE_OAUTH_ENV_KEYS.reject { |key| ENV[key].present? }
  end

  def google_client_id
    ENV.fetch("GOOGLE_DRIVE_OAUTH_CLIENT_ID")
  end

  def google_client_secret
    ENV.fetch("GOOGLE_DRIVE_OAUTH_CLIENT_SECRET")
  end

  def read_only_maintenance?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(READ_ONLY_MAINTENANCE_ENV, nil))
  end
end
