require "base64"
require "json"
require "net/http"
require "pathname"
require "uri"

class MicrosoftGraphSharedFolderResolver
  class ResolutionError < StandardError; end

  Result = Struct.new(:drive_id, :site_id, :preview_folder_path, keyword_init: true)

  GRAPH_SCOPE = "https://graph.microsoft.com/.default"

  def initialize(tenant_id:, client_id:, client_secret:, shared_folder_url:)
    @tenant_id = tenant_id.to_s.strip
    @client_id = client_id.to_s.strip
    @client_secret = client_secret.to_s
    @shared_folder_url = shared_folder_url.to_s.strip
  end

  def resolve
    validate_inputs!

    access_token = fetch_access_token
    drive_item = fetch_drive_item(access_token)

    build_result(drive_item)
  end

  private

  attr_reader :tenant_id, :client_id, :client_secret, :shared_folder_url

  def validate_inputs!
    raise ResolutionError, "共有フォルダURLを入力してください。" if shared_folder_url.blank?
    raise ResolutionError, "Tenant ID を入力してください。" if tenant_id.blank?
    raise ResolutionError, "Client ID を入力してください。" if client_id.blank?
    raise ResolutionError, "Client secret を入力してください。" if client_secret.blank?

    uri = URI.parse(shared_folder_url)
    return if uri.is_a?(URI::HTTP) && uri.host.present?

    raise ResolutionError, "SharePoint / OneDrive の共有フォルダURLを入力してください。"
  rescue URI::InvalidURIError
    raise ResolutionError, "SharePoint / OneDrive の共有フォルダURLを入力してください。"
  end

  def fetch_access_token
    uri = URI("https://login.microsoftonline.com/#{tenant_id}/oauth2/v2.0/token")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/x-www-form-urlencoded"
    request.body = URI.encode_www_form(
      grant_type: "client_credentials",
      client_id: client_id,
      client_secret: client_secret,
      scope: GRAPH_SCOPE
    )

    response = perform_request(uri, request)
    body = parse_json(response)

    unless response.is_a?(Net::HTTPSuccess)
      raise ResolutionError, error_message(body, default: "Microsoft Graph のアクセストークン取得に失敗しました。")
    end

    access_token = body["access_token"].to_s
    raise ResolutionError, "Microsoft Graph のアクセストークン取得に失敗しました。" if access_token.blank?

    access_token
  end

  def fetch_drive_item(access_token)
    uri = URI("https://graph.microsoft.com/v1.0/shares/#{encoded_share_id}/driveItem")
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{access_token}"
    request["Accept"] = "application/json"

    response = perform_request(uri, request)
    body = parse_json(response)

    unless response.is_a?(Net::HTTPSuccess)
      raise ResolutionError, error_message(body, default: "共有URLからDrive情報を解決できませんでした。")
    end

    body
  end

  def build_result(drive_item)
    unless drive_item["folder"].is_a?(Hash)
      raise ResolutionError, "共有フォルダURLを入力してください。ファイル共有URLはまだ解決できません。"
    end

    parent_reference = drive_item.fetch("parentReference", {})
    drive_id = parent_reference["driveId"].to_s
    preview_folder_path = build_preview_folder_path(parent_reference["path"], drive_item["name"])

    raise ResolutionError, "共有URLから Drive ID を取得できませんでした。" if drive_id.blank?

    Result.new(
      drive_id: drive_id,
      site_id: parent_reference["siteId"].to_s.presence,
      preview_folder_path: preview_folder_path
    )
  end

  def build_preview_folder_path(parent_path, item_name)
    relative_parent = parent_path.to_s.split("root:/", 2).last.to_s.delete_prefix("/").delete_suffix("/")
    relative_name = item_name.to_s.strip
    joined_path = [relative_parent.presence, relative_name.presence].compact.join("/")
    normalized_path = Pathname.new(joined_path).cleanpath.to_s.delete_prefix("./")

    if normalized_path.blank? || normalized_path == "." || normalized_path == ".." || normalized_path.start_with?("../")
      raise ResolutionError, "共有URLから preview 用フォルダを特定できませんでした。"
    end

    normalized_path
  end

  def encoded_share_id
    "u!#{Base64.strict_encode64(shared_folder_url).tr("+/", "-_").delete("=")}"
  end

  def perform_request(uri, request)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 10) do |http|
      http.request(request)
    end
  rescue SocketError, SystemCallError, Timeout::Error => e
    raise ResolutionError, "Microsoft Graph との通信に失敗しました: #{e.message}"
  end

  def parse_json(response)
    JSON.parse(response.body.presence || "{}")
  rescue JSON::ParserError
    {}
  end

  def error_message(body, default:)
    graph_error = body["error"]

    message = if graph_error.is_a?(Hash)
      graph_error["message"].presence
    else
      body["error_description"].presence || body["message"].presence
    end

    message.presence || default
  end
end