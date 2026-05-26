require "base64"
require "json"
require "net/http"
require "openssl"
require "uri"

module ExternalFolderSync
  class MicrosoftGraphFolderResolver
    TOKEN_SCOPE = "https://graph.microsoft.com/.default".freeze
    GRAPH_ROOT = "https://graph.microsoft.com/v1.0".freeze

    class Error < StandardError; end

    def initialize(source:)
      @source = source
      @connection = source.microsoft_graph_connection
    end

    def resolve
      raise Error, "有効な Microsoft Graph接続 が見つかりません。" if connection.blank?

      item = request_json(
        "/shares/#{share_token(source.folder_url)}/driveItem",
        query: {
          "$select" => "id,name,folder,parentReference,sharepointIds,webUrl"
        }
      )

      raise Error, "共有URLがフォルダを指していません。" if item["folder"].blank?

      drive_id = item.dig("parentReference", "driveId")
      folder_item_id = item["id"].presence
      folder_path = build_folder_path(item.dig("parentReference", "path"), item["name"])

      if drive_id.blank? || folder_item_id.blank? || folder_path.blank?
        raise Error, "Microsoft Graph から必要なフォルダ metadata を取得できませんでした。"
      end

      {
        drive_id:,
        folder_item_id:,
        folder_path:,
        site_id: item.dig("sharepointIds", "siteId") || item.dig("parentReference", "siteId")
      }
    end

    private

    attr_reader :source, :connection

    def share_token(url)
      encoded = Base64.urlsafe_encode64(url.to_s, padding: false)
      "u!#{encoded}"
    end

    def build_folder_path(parent_path, name)
      parent_segment = parent_path.to_s.split("root:", 2).last.to_s.delete_prefix("/")
      parts = [parent_segment.presence, name.presence].compact
      parts.join("/")
    end

    def access_token
      @access_token ||= begin
        uri = URI("https://login.microsoftonline.com/#{connection.tenant_id}/oauth2/v2.0/token")
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/x-www-form-urlencoded"
        request.body = URI.encode_www_form(
          client_id: connection.client_id,
          client_secret: connection.client_secret,
          scope: TOKEN_SCOPE,
          grant_type: "client_credentials"
        )

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { _1.request(request) }
        body = parse_response_body(response)
        return body.fetch("access_token") if response.is_a?(Net::HTTPSuccess)

        message = body.is_a?(Hash) ? body["error_description"].presence || body["error"] : nil
        raise Error, "Microsoft Graph のアクセストークン取得に失敗しました: #{message || response.message}"
      end
    end

    def request_json(path, query: {})
      uri = URI("#{GRAPH_ROOT}#{path}")
      uri.query = URI.encode_www_form(query) if query.present?

      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{access_token}"

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { _1.request(request) }
      body = parse_response_body(response)
      return body if response.is_a?(Net::HTTPSuccess)

      raise build_error(response, body)
    end

    def build_error(response, body)
      message = body.is_a?(Hash) ? body.dig("error", "message") : nil

      case response.code.to_i
      when 400, 404
        Error.new("共有URLからフォルダ情報を解決できませんでした。共有URLを確認してください。")
      when 401, 403
        Error.new("Microsoft Graph へのアクセス権限が不足しています。接続設定と共有権限を確認してください。")
      else
        Error.new("Microsoft Graph request failed (#{response.code}): #{message || response.message}")
      end
    end

    def parse_response_body(response)
      JSON.parse(response.body.presence || "{}")
    rescue JSON::ParserError
      response.body
    end
  end
end
