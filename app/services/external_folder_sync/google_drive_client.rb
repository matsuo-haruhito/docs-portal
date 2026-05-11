require "base64"
require "json"
require "net/http"
require "openssl"
require "uri"

module ExternalFolderSync
  class GoogleDriveClient
    TOKEN_URL = "https://oauth2.googleapis.com/token".freeze
    DRIVE_ROOT = "https://www.googleapis.com/drive/v3".freeze
    DRIVE_SCOPE = "https://www.googleapis.com/auth/drive.readonly".freeze
    FOLDER_MIME_TYPE = "application/vnd.google-apps.folder".freeze
    GOOGLE_APPS_PREFIX = "application/vnd.google-apps".freeze

    class Error < StandardError; end

    FileEntry = Data.define(
      :id,
      :parent_id,
      :name,
      :path,
      :mime_type,
      :size,
      :checksum,
      :modified_at,
      :trashed,
      :web_view_link,
      :exportable
    )

    def initialize(source:)
      @source = source
      @access_token = nil
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
      folder_name = folder_metadata.fetch("name", source.external_folder_id)
      walk_folder(source.external_folder_id, folder_name)
    end

    def download_file(file_id)
      request_json("/files/#{escape(file_id)}", query: { alt: "media" }, parse_json: false)
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
      request_json("/files/#{escape(file_id)}", query: {
        fields:,
        supportsAllDrives: true
      })
    end

    def entry_for(item, path)
      mime_type = item["mimeType"].to_s
      FileEntry.new(
        id: item.fetch("id"),
        parent_id: item.fetch("parents", []).first,
        name: item.fetch("name"),
        path:,
        mime_type:,
        size: item["size"].to_i,
        checksum: item["md5Checksum"],
        modified_at: parse_time(item["modifiedTime"]),
        trashed: item["trashed"] == true,
        web_view_link: item["webViewLink"],
        exportable: mime_type.start_with?(GOOGLE_APPS_PREFIX)
      )
    end

    def request_json(path, query: {}, parse_json: true)
      uri = URI("#{DRIVE_ROOT}#{path}")
      uri.query = URI.encode_www_form(query) if query.present?
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{access_token}"

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { _1.request(request) }
      return response.body if response.is_a?(Net::HTTPSuccess) && !parse_json

      body = parse_response_body(response)
      return body if response.is_a?(Net::HTTPSuccess)

      message = body.is_a?(Hash) ? body.dig("error", "message") : nil
      raise Error, "Google Drive request failed (#{response.code}): #{message || response.message}"
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
      key = OpenSSL::PKey::RSA.new(config.fetch("private_key"))
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

    def escape(value)
      ERB::Util.url_encode(value)
    end
  end
end
