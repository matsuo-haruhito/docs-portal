require "json"
require "net/http"
require "uri"

class DocumentFileGoogleDrivePreviewUploadCleanup
  TOKEN_URL = "https://oauth2.googleapis.com/token".freeze
  DRIVE_ROOT = "https://www.googleapis.com/drive/v3".freeze

  class Error < StandardError; end

  def initialize(upload:)
    @upload = upload
  end

  def call
    delete_drive_file!
    upload.update!(deleted_at: Time.current, last_error_message: nil)
  rescue Error => e
    upload.update!(last_error_message: e.message)
    raise
  end

  private

  attr_reader :upload

  def delete_drive_file!
    uri = URI("#{DRIVE_ROOT}/files/#{ERB::Util.url_encode(upload.drive_file_id)}")
    uri.query = URI.encode_www_form(supportsAllDrives: true)
    request = Net::HTTP::Delete.new(uri)
    request["Authorization"] = "Bearer #{access_token}"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { _1.request(request) }
    return if response.is_a?(Net::HTTPSuccess) || response.code.to_i == 404

    body = JSON.parse(response.body.presence || "{}")
    message = body.is_a?(Hash) ? body.dig("error", "message") : nil
    raise Error, "Google Drive preview delete failed (#{response.code}): #{message || response.message}"
  rescue JSON::ParserError
    raise Error, "Google Drive preview delete failed: #{response&.body}"
  end

  def access_token
    @access_token ||= begin
      response = Net::HTTP.post_form(URI(TOKEN_URL), {
        client_id: ENV.fetch("GOOGLE_DRIVE_OAUTH_CLIENT_ID"),
        client_secret: ENV.fetch("GOOGLE_DRIVE_OAUTH_CLIENT_SECRET"),
        refresh_token:,
        grant_type: "refresh_token"
      })
      body = JSON.parse(response.body.presence || "{}")
      return body.fetch("access_token") if response.is_a?(Net::HTTPSuccess)

      message = body["error_description"] || body["error"] || response.message
      raise Error, "Google OAuth token refresh failed (#{response.code}): #{message}"
    end
  rescue KeyError => e
    raise Error, "Google Drive preview cleanup is missing #{e.key}"
  rescue JSON::ParserError
    raise Error, "Google OAuth token refresh failed: #{response&.body}"
  end

  def refresh_token
    source = project_preview_oauth_source || global_preview_oauth_source
    token = source&.auth_config_json&.fetch("refresh_token", nil).presence
    raise Error, "Google Drive OAuth refresh_token is missing" if token.blank?

    token
  end

  def project_preview_oauth_source
    project = upload.document_file.document_version.document.project
    oauth_sources.where(project:).detect(&:oauth_connected?)
  end

  def global_preview_oauth_source
    oauth_sources.detect(&:oauth_connected?)
  end

  def oauth_sources
    ExternalFolderSyncSource
      .google_drive
      .oauth_user
      .enabled_only
      .order(:id)
  end
end
