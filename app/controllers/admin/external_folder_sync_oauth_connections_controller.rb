class Admin::ExternalFolderSyncOauthConnectionsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_external_folder_sync_source, only: %i[new destroy]

  GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth".freeze
  GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token".freeze
  DRIVE_SCOPE = "https://www.googleapis.com/auth/drive.readonly".freeze

  def new
    unless @external_folder_sync_source.google_drive? && @external_folder_sync_source.oauth_user?
      redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), alert: "OAuth認可はGoogle DriveのOAuth user認証でのみ利用できます。"
      return
    end

    state = oauth_state_for(@external_folder_sync_source)
    session[:external_folder_sync_oauth_state] = state

    redirect_to oauth_authorization_url(state), allow_other_host: true
  end

  def callback
    state = verified_state!
    source = ExternalFolderSyncSource.find_by!(public_id: state.fetch("source_public_id"))
    token = exchange_code!(params.require(:code))
    source.merge_auth_config!(
      refresh_token: token.fetch("refresh_token", source.auth_config_json["refresh_token"]),
      access_token: token["access_token"],
      expires_at: token["expires_in"].present? ? Time.current.advance(seconds: token["expires_in"].to_i).iso8601 : nil,
      scope: token["scope"],
      token_type: token["token_type"]
    )

    redirect_to admin_external_folder_sync_source_path(source), notice: "Google Drive OAuth認可を接続しました。"
  rescue ActiveSupport::MessageVerifier::InvalidSignature, KeyError, ActionController::ParameterMissing => e
    redirect_to admin_external_folder_sync_sources_path, alert: "OAuth認可に失敗しました: #{e.message}"
  end

  def destroy
    @external_folder_sync_source.update!(auth_config: {}.to_json)
    redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), notice: "Google Drive OAuth認可を解除しました。"
  end

  private

  def set_external_folder_sync_source
    @external_folder_sync_source = ExternalFolderSyncSource.find_by!(public_id: params[:external_folder_sync_source_id])
  end

  def oauth_authorization_url(state)
    uri = URI(GOOGLE_AUTH_URL)
    uri.query = URI.encode_www_form(
      client_id: google_client_id,
      redirect_uri: callback_admin_external_folder_sync_oauth_connections_url,
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
      redirect_uri: callback_admin_external_folder_sync_oauth_connections_url,
      grant_type: "authorization_code"
    })
    body = JSON.parse(response.body.presence || "{}")
    return body if response.is_a?(Net::HTTPSuccess)

    raise KeyError, body["error_description"] || body["error"] || response.message
  end

  def oauth_state_for(source)
    verifier.generate(
      source_public_id: source.public_id,
      nonce: SecureRandom.hex(16),
      issued_at: Time.current.to_i
    )
  end

  def verified_state!
    state = params.require(:state)
    expected = session.delete(:external_folder_sync_oauth_state).to_s
    unless expected.present? && ActiveSupport::SecurityUtils.secure_compare(expected, state)
      raise ActiveSupport::MessageVerifier::InvalidSignature, "OAuth state mismatch"
    end

    verifier.verify(state)
  end

  def verifier
    ActiveSupport::MessageVerifier.new(Rails.application.secret_key_base, digest: "SHA256")
  end

  def google_client_id
    ENV.fetch("GOOGLE_DRIVE_OAUTH_CLIENT_ID")
  end

  def google_client_secret
    ENV.fetch("GOOGLE_DRIVE_OAUTH_CLIENT_SECRET")
  end
end
