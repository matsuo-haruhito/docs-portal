require "net/http"
require "uri"

class MicrosoftGraphClient
  TOKEN_URL_TEMPLATE = "https://login.microsoftonline.com/%<tenant_id>s/oauth2/v2.0/token".freeze
  GRAPH_ROOT = "https://graph.microsoft.com/v1.0".freeze
  SCOPE = "https://graph.microsoft.com/.default".freeze

  class Error < StandardError; end

  def initialize(connection:)
    @connection = connection
  end

  def preview_url_for_upload(file_path:, file_name:)
    access_token = fetch_access_token
    item = upload_preview_file(access_token:, file_path:, file_name:)
    preview = create_preview(access_token:, item_id: item.fetch("id"))
    preview_get_url(preview)
  rescue KeyError => e
    raise Error, "Microsoft Graph response did not include #{e.key}"
  end

  private

  attr_reader :connection

  def fetch_access_token
    uri = URI(format(TOKEN_URL_TEMPLATE, tenant_id: ERB::Util.url_encode(connection.tenant_id)))
    response = Net::HTTP.post_form(uri, {
      "client_id" => connection.client_id,
      "client_secret" => connection.client_secret,
      "scope" => SCOPE,
      "grant_type" => "client_credentials"
    })
    body = parse_json_response(response)
    body.fetch("access_token")
  end

  def upload_preview_file(access_token:, file_path:, file_name:)
    preview_path = [connection.normalized_preview_folder_path, preview_file_name(file_name)].join("/")
    uri = graph_uri("/drives/#{connection.drive_id}/root:/#{escape_path(preview_path)}:/content")
    request = Net::HTTP::Put.new(uri)
    request["Authorization"] = "Bearer #{access_token}"
    request["Content-Type"] = "application/octet-stream"
    request.body = File.binread(file_path)

    parse_json_response(Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { _1.request(request) })
  end

  def create_preview(access_token:, item_id:)
    uri = graph_uri("/drives/#{connection.drive_id}/items/#{ERB::Util.url_encode(item_id)}/preview")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{access_token}"
    request["Content-Type"] = "application/json"
    request.body = {}.to_json

    parse_json_response(Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { _1.request(request) })
  end

  def preview_get_url(preview)
    get_url = preview["getUrl"].presence
    return get_url if get_url

    raise Error, "Microsoft Graph preview response did not include getUrl"
  end

  def graph_uri(path)
    URI("#{GRAPH_ROOT}#{path}")
  end

  def escape_path(path)
    path.split("/").map { ERB::Util.url_encode(_1) }.join("/")
  end

  def preview_file_name(file_name)
    basename = File.basename(file_name.to_s.presence || "document")
    "#{SecureRandom.uuid}-#{basename}"
  end

  def parse_json_response(response)
    body = JSON.parse(response.body.presence || "{}")
    return body if response.is_a?(Net::HTTPSuccess)

    message = body.dig("error", "message") || body["error_description"] || response.message
    raise Error, "Microsoft Graph request failed (#{response.code}): #{message}"
  rescue JSON::ParserError
    raise Error, "Microsoft Graph request failed (#{response.code}): #{response.body}"
  end
end
