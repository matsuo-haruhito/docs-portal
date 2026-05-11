require "json"
require "net/http"
require "securerandom"
require "uri"

class DocumentFileGoogleDriveUploadPreview
  TOKEN_URL = "https://oauth2.googleapis.com/token".freeze
  UPLOAD_ROOT = "https://www.googleapis.com/upload/drive/v3".freeze
  DRIVE_ROOT = "https://www.googleapis.com/drive/v3".freeze
  PREVIEW_FOLDER_ENV_KEY = "GOOGLE_DRIVE_PREVIEW_FOLDER_ID".freeze

  class Error < StandardError; end

  def initialize(file:)
    @file = file
  end

  def available?
    preview_folder_id.present? && refresh_token.present?
  end

  def url
    raise Error, unavailable_message unless available?
    raise Error, "File not found" unless File.exist?(file.absolute_path)

    drive_file_id = upload_file!
    "https://drive.google.com/file/d/#{ERB::Util.url_encode(drive_file_id)}/preview"
  end

  def unavailable_message
    missing = []
    missing << PREVIEW_FOLDER_ENV_KEY if preview_folder_id.blank?
    missing << "Google Drive OAuth refresh_token" if refresh_token.blank?
    "Google Drive upload preview is not available: #{missing.join(', ')}"
  end

  private

  attr_reader :file

  def upload_file!
    uri = URI("#{UPLOAD_ROOT}/files")
    uri.query = URI.encode_www_form(uploadType: "multipart", supportsAllDrives: true, fields: "id,webViewLink")
    boundary = "docs-portal-google-preview-#{SecureRandom.hex(16)}"
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{access_token}"
    request["Content-Type"] = "multipart/related; boundary=#{boundary}"
    request.body = multipart_body(boundary)

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { _1.request(request) }
    body = JSON.parse(response.body.presence || "{}")
    return body.fetch("id") if response.is_a?(Net::HTTPSuccess)

    message = body.is_a?(Hash) ? body.dig("error", "message") : nil
    raise Error, "Google Drive preview upload failed (#{response.code}): #{message || response.message}"
  rescue JSON::ParserError
    raise Error, "Google Drive preview upload failed: #{response&.body}"
  end

  def multipart_body(boundary)
    metadata = {
      name: upload_file_name,
      parents: [preview_folder_id]
    }

    body = String.new(capacity: file.file_size.to_i + 1024, encoding: Encoding::BINARY)
    body << "--#{boundary}\r\n".b
    body << "Content-Type: application/json; charset=UTF-8\r\n\r\n".b
    body << metadata.to_json.b
    body << "\r\n--#{boundary}\r\n".b
    body << "Content-Type: #{file.effective_content_type}\r\n\r\n".b
    body << File.binread(file.absolute_path)
    body << "\r\n--#{boundary}--\r\n".b
    body
  end

  def upload_file_name
    base = file.file_name.to_s.presence || "document-file"
    "docs-portal-preview-#{file.public_id}-#{Time.current.strftime('%Y%m%d%H%M%S')}-#{base}"
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
    raise Error, "Google Drive upload preview is missing #{e.key}"
  rescue JSON::ParserError
    raise Error, "Google OAuth token refresh failed: #{response&.body}"
  end

  def refresh_token
    preview_oauth_source&.auth_config_json&.fetch("refresh_token", nil).presence
  end

  def preview_oauth_source
    @preview_oauth_source ||= project_preview_oauth_source || global_preview_oauth_source
  end

  def project_preview_oauth_source
    oauth_sources.where(project: file.document_version.document.project).detect(&:oauth_connected?)
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

  def preview_folder_id
    ENV[PREVIEW_FOLDER_ENV_KEY].presence
  end
end
