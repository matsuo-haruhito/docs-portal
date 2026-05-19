require "net/http"
require "tempfile"
require "uri"

class DocusaurusRendererClient
  Result = Struct.new(:archive_path, :site_path, keyword_init: true)

  DEFAULT_ENDPOINT = "http://docusaurus:3000"
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 90

  def initialize(endpoint: ENV.fetch("DOCUSAURUS_RENDERER_ENDPOINT", DEFAULT_ENDPOINT))
    @endpoint = endpoint.to_s.delete_suffix("/")
  end

  def build(archive_file:, entry_path:)
    uri = URI.join("#{endpoint}/", "build")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/gzip"
    request["X-Docs-Entry-Path"] = entry_path
    archive_file.rewind
    request.body_stream = archive_file
    request.content_length = archive_file.size

    response = http_for(uri).request(request)
    unless response.is_a?(Net::HTTPSuccess)
      raise ApplicationError::BadRequest, renderer_error_message(response)
    end

    output = Tempfile.new(["docusaurus-build", ".tar.gz"])
    output.binmode
    output.write(response.body)
    output.rewind

    Result.new(
      archive_path: output.path,
      site_path: safe_site_path(response["X-Docs-Site-Path"].presence || entry_path)
    )
  ensure
    output&.close
  end

  private

  attr_reader :endpoint

  def http_for(uri)
    Net::HTTP.new(uri.host, uri.port).tap do |http|
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT
    end
  end

  def renderer_error_message(response)
    body = response.body.to_s
    json = JSON.parse(body) rescue nil
    message = json&.fetch("error", nil).presence || body.presence || response.message
    "Docusaurus preview build failed: #{message}"
  end

  def safe_site_path(value)
    path = value.to_s.tr("\\", "/").delete_prefix("/")
    normalized = Pathname.new(path.presence || "index").cleanpath.to_s
    invalid = normalized.blank? || normalized == "." || normalized == ".." || normalized.start_with?("../") || normalized.include?("\0")
    raise ApplicationError::BadRequest, "Docusaurus renderer returned invalid site path: #{value}" if invalid

    normalized
  end
end
