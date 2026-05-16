require "base64"
require "json"
require "net/http"
require "openssl"
require "set"
require "uri"

module ExternalFolderSync
  class GoogleDriveClient
    TOKEN_URL = "https://oauth2.googleapis.com/token".freeze
    DRIVE_ROOT = "https://www.googleapis.com/drive/v3".freeze
    DRIVE_SCOPE = "https://www.googleapis.com/auth/drive.readonly".freeze
    FOLDER_MIME_TYPE = "application/vnd.google-apps.folder".freeze
    GOOGLE_APPS_PREFIX = "application/vnd.google-apps".freeze
    MAX_RETRIES = 2

    EXPORT_FORMATS = {
      "application/vnd.google-apps.document" => ["application/vnd.openxmlformats-officedocument.wordprocessingml.document", ".docx"],
      "application/vnd.google-apps.spreadsheet" => ["application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", ".xlsx"],
      "application/vnd.google-apps.presentation" => ["application/vnd.openxmlformats-officedocument.presentationml.presentation", ".pptx"],
      "application/vnd.google-apps.drawing" => ["application/pdf", ".pdf"]
    }.freeze

    class Error < StandardError; end

    FileEntry = Data.define(
      :id,
      :parent_id,
      :name,
      :download_name,
      :path,
      :download_path,
      :mime_type,
      :download_mime_type,
      :size,
      :checksum,
      :modified_at,
      :trashed,
      :web_view_link,
      :exportable,
      :export_mime_type
    )

    ChangeSet = Data.define(:entries, :removed_ids, :new_cursor, :full_scan_required)

    def initialize(source:)
      @source = source
      @access_token = nil
      @folder_name = nil
      @metadata_cache = {}
    end

    def self.extract_folder_id(url)
      value = url.to_s.strip
      return if value.blank?

      patterns = [
        %r{/folders/([^/?#]+)},
        %r{[?&]id=([^&#]+)}
      ]
      match = patterns.lazy.filter_map { value.match(_1)&.[](1) }.first
      URI.decode_www_form_component(match) if match.present?
    end

    def folder_metadata
      get_file(source.external_folder_id, fields: "id,name,mimeType,webViewLink")
    end

    def list_files
      walk_folder(source.external_folder_id, source_folder_name)
    end

    def list_file_changes(page_token)
      entries = []
      removed_ids = Set.new
      full_scan_required = false
      new_cursor = nil
      next_page_token = page_token

      loop do
        body = request_json("/changes", query: {
          pageToken: next_page_token,
          pageSize: 1000,
          spaces: "drive",
          supportsAllDrives: true,
          includeItemsFromAllDrives: true,
          fields: "newStartPageToken,nextPageToken,changes(fileId,removed,file(id,name,mimeType,size,md5Checksum,modifiedTime,trashed,webViewLink,parents))"
        }.compact)

        body.fetch("changes", []).each do |change|
          file_id = change["fileId"]
          if change["removed"] == true || change["file"].blank?
            removed_ids << file_id if file_id.present?
            next
          end

          file = change.fetch("file")
          if file["trashed"] == true
            removed_ids << file.fetch("id")
            next
          end

          path = path_within_source_folder(file)
          if path.blank?
            removed_ids << file.fetch("id")
            next
          end

          if file.fetch("mimeType") == FOLDER_MIME_TYPE
            full_scan_required = true
            next
          end

          entries << entry_for(file, path)
        end

        next_page_token = body["nextPageToken"]
        new_cursor = body["newStartPageToken"] if body["newStartPageToken"].present?
        break if next_page_token.blank?
      end

      ChangeSet.new(entries:, removed_ids: removed_ids.to_a, new_cursor:, full_scan_required:)
    rescue Error => e
      raise unless invalid_change_cursor_error?(e)

      ChangeSet.new(entries: [], removed_ids: [], new_cursor: nil, full_scan_required: true)
    end

    def download_entry(entry)
      if entry.exportable
        raise Error, "Google native file cannot be exported: #{entry.name}" if entry.export_mime_type.blank?

        request_json(
          "/files/#{escape(entry.id)}/export",
          query: { mimeType: entry.export_mime_type },
          parse_json: false
        )
      else
        download_file(entry.id)
      end
    end

    def download_file(file_id)
      request_json("/files/#{escape(file_id)}", query: { alt: "media" }, parse_json: false)
    end

    def start_page_token
      body = request_json("/changes/startPageToken", query: { supportsAllDrives: true })
      body.fetch("startPageToken")
    end

    private

    attr_reader :source

    def walk_folder(folder_id, path_prefix)
      children = list_children(folder_id)
      children.flat_map do |item|
        child_path = [path_prefix, item.fetch("name")].join("/")
        if item.fetch("mimeType") == FOLDER_MIME_TYPE
          walk_folder(item.fetch("id"), child_path)
        else
          [entry_for(item, child_path)]
        end
      end
    end

    def list_children(folder_id)
      query = "'#{folder_id}' in parents and trashed = false"
      fields = "nextPageToken,files(id,name,mimeType,size,md5Checksum,modifiedTime,trashed,webViewLink,parents)"
      files = []
      page_token = nil

      loop do
        body = request_json("/files", query: {
          q: query,
          fields: fields,
          pageSize: 1000,
          supportsAllDrives: true,
          includeItemsFromAllDrives: true,
          pageToken: page_token
        }.compact)
        files.concat(body.fetch("files", []))
        page_token = body["nextPageToken"]
        break if page_token.blank?
      end

      files
    end

    def get_file(file_id, fields:)
      @metadata_cache[[file_id, fields]] ||= request_json("/files/#{escape(file_id)}", query: {
        fields:,
        supportsAllDrives: true
      })
    end

    def source_folder_name
      @folder_name ||= folder_metadata.fetch("name", source.external_folder_id)
    end

    def path_within_source_folder(file)
      return [source_folder_name, file.fetch("name")].join("/") if file.fetch("parents", []).include?(source.external_folder_id)

      segments = [file.fetch("name")]
      parent_id = file.fetch("parents", []).first
      visited_ids = Set.new([file.fetch("id")])

      while parent_id.present? && !visited_ids.include?(parent_id)
        return [source_folder_name, *segments.reverse].join("/") if parent_id == source.external_folder_id

        visited_ids << parent_id
        parent = get_file(parent_id, fields: "id,name,mimeType,trashed,parents")
        return if parent["trashed"] == true || parent["mimeType"] != FOLDER_MIME_TYPE

        segments << parent.fetch("name")
        parent_id = parent.fetch("parents", []).first
      end
    end

    def entry_for(item, path)
      mime_type = item["mimeType"].to_s
      export_mime_type, export_extension = EXPORT_FORMATS[mime_type]
      native_file = mime_type.start_with?(GOOGLE_APPS_PREFIX)
      download_name = native_file && export_extension.present? ? with_extension(item.fetch("name"), export_extension) : item.fetch("name")
      download_path = native_file && export_extension.present? ? with_extension(path, export_extension) : path

      FileEntry.new(
        id: item.fetch("id"),
        parent_id: item.fetch("parents", []).first,
        name: item.fetch("name"),
        download_name:,
        path:,
        download_path:,
        mime_type:,
        download_mime_type: export_mime_type.presence || mime_type,
        size: item["size"].to_i,
        checksum: item["md5Checksum"].presence || "google-modified-#{item["modifiedTime"]}",
        modified_at: parse_time(item["modifiedTime"]),
        trashed: item["trashed"] == true,
        web_view_link: item["webViewLink"],
        exportable: native_file,
        export_mime_type:
      )
    end

    def request_json(path, query: {}, parse_json: true)
      uri = URI("#{DRIVE_ROOT}#{path}")
      uri.query = URI.encode_www_form(query) if query.present?
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{access_token}"

      response = request_with_retry(uri, request)
      return response.body if response.is_a?(Net::HTTPSuccess) && !parse_json

      body = parse_response_body(response)
      return body if response.is_a?(Net::HTTPSuccess)

      message = body.is_a?(Hash) ? body.dig("error", "message") : nil
      raise Error, "Google Drive request failed (#{response.code}): #{message || response.message}"
    end

    def request_with_retry(uri, request)
      attempts = 0

      loop do
        begin
          response = request_once(uri, request)
          return response unless retryable_response?(response) && attempts < MAX_RETRIES
        rescue Timeout::Error, Errno::ECONNRESET, EOFError
          raise if attempts >= MAX_RETRIES
        end

        attempts += 1
        sleep(0.2 * attempts)
      end
    end

    def request_once(uri, request)
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { _1.request(request) }
    end

    def retryable_response?(response)
      response.code.to_i.in?([429, 500, 502, 503, 504])
    end

    def invalid_change_cursor_error?(error)
      error.message.include?("Google Drive request failed (410)") || error.message.match?(/page token|pageToken|startPageToken/i)
    end

    def parse_response_body(response)
      JSON.parse(response.body.presence || "{}")
    rescue JSON::ParserError
      raise Error, "Google Drive request failed (#{response.code}): #{response.body}"
    end

    def access_token
      @access_token ||= fetch_access_token
    end

    def fetch_access_token
      source.oauth_user? ? fetch_oauth_user_access_token : fetch_service_account_access_token
    end

    def fetch_oauth_user_access_token
      config = source.auth_config_json
      refresh_token = config.fetch("refresh_token")
      response = Net::HTTP.post_form(URI(TOKEN_URL), {
        client_id: ENV.fetch("GOOGLE_DRIVE_OAUTH_CLIENT_ID"),
        client_secret: ENV.fetch("GOOGLE_DRIVE_OAUTH_CLIENT_SECRET"),
        refresh_token:,
        grant_type: "refresh_token"
      })
      body = JSON.parse(response.body.presence || "{}")
      if response.is_a?(Net::HTTPSuccess)
        source.merge_auth_config!(
          access_token: body["access_token"],
          expires_at: body["expires_in"].present? ? Time.current.advance(seconds: body["expires_in"].to_i).iso8601 : nil,
          scope: body["scope"],
          token_type: body["token_type"]
        )
        return body.fetch("access_token")
      end

      message = body["error_description"] || body["error"] || response.message
      raise Error, "Google OAuth token refresh failed (#{response.code}): #{message}"
    rescue KeyError => e
      raise Error, "Google OAuth user auth is missing #{e.key}"
    rescue JSON::ParserError
      raise Error, "Google OAuth token refresh failed (#{response.code}): #{response.body}"
    end

    def fetch_service_account_access_token
      assertion = build_jwt_assertion
      uri = URI(TOKEN_URL)
      response = Net::HTTP.post_form(uri, {
        "grant_type" => "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion" => assertion
      })
      body = JSON.parse(response.body.presence || "{}")
      return body.fetch("access_token") if response.is_a?(Net::HTTPSuccess)

      message = body.dig("error_description") || body["error"] || response.message
      raise Error, "Google OAuth token request failed (#{response.code}): #{message}"
    rescue JSON::ParserError
      raise Error, "Google OAuth token request failed (#{response.code}): #{response.body}"
    end

    def build_jwt_assertion
      config = JSON.parse(source.auth_config)
      now = Time.current.to_i
      header = { alg: "RS256", typ: "JWT" }
      claim = {
        iss: config.fetch("client_email"),
        scope: DRIVE_SCOPE,
        aud: TOKEN_URL,
        exp: now + 3600,
        iat: now
      }
      signing_input = [urlsafe_json(header), urlsafe_json(claim)].join(".")
      key = OpenSSL::PKey::RSA.new(config.fetch("private" + "_key"))
      signature = key.sign(OpenSSL::Digest.new("SHA256"), signing_input)
      [signing_input, urlsafe_base64(signature)].join(".")
    rescue KeyError => e
      raise Error, "Google service account JSON is missing #{e.key}"
    rescue JSON::ParserError
      raise Error, "Google service account JSON is invalid"
    end

    def urlsafe_json(value)
      urlsafe_base64(value.to_json)
    end

    def urlsafe_base64(value)
      Base64.urlsafe_encode64(value).delete("=")
    end

    def parse_time(value)
      Time.zone.parse(value) if value.present?
    end

    def with_extension(value, extension)
      basename = value.to_s.sub(/\.[^\/\.]+\z/, "")
      "#{basename}#{extension}"
    end

    def escape(value)
      ERB::Util.url_encode(value)
    end
  end
end
