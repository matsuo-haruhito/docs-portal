require "json"
require "net/http"
require "pathname"
require "tempfile"
require "timeout"
require "uri"

class DocusaurusRendererClient
  class TransientError < StandardError; end

  Result = Struct.new(:archive_file, :site_path, keyword_init: true)

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

    body = response.body.to_s
    raise ApplicationError::BadRequest, "Docusaurus preview build failed: renderer returned empty artifact" if body.blank?

    output = Tempfile.new(["docusaurus-build", ".tar.gz"])
    output.binmode
    output.write(body)
    output.rewind

    Result.new(
      archive_file: output,
      site_path: safe_site_path(response["X-Docs-Site-Path"].presence || normalize_site_page_path(entry_path))
    )
  rescue ApplicationError::BadRequest
    output&.close!
    raise
  rescue SystemCallError, Timeout::Error, SocketError, IOError => e
    output&.close!
    raise TransientError, "Docusaurus preview renderer did not respond: #{e.message}"
  rescue
    output&.close!
    raise
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
    raw_path = value.to_s.tr("\\", "/")
    invalid_absolute = raw_path.start_with?("/") || raw_path.match?(/\A[A-Za-z]:\//)
    normalized = Pathname.new(raw_path.presence || "index").cleanpath.to_s
    invalid = invalid_absolute || normalized.blank? || normalized == "." || normalized == ".." || normalized.start_with?("../") || normalized.include?("\0")
    raise ApplicationError::BadRequest, "Docusaurus renderer returned invalid site path: #{value}" if invalid

    normalized
  end

  def normalize_site_page_path(path)
    value = path.to_s.delete_prefix("/").sub(%r{\A/+}, "")
    value = value.sub(%r{/(?:index|README)\.(?:md|markdown|mdx)\z}i, "")
    value = value.sub(/\.(md|markdown|mdx)\z/i, "")
    value = value.delete_suffix("/index.html")
    value = value.delete_suffix(".html")
    value.presence || "index"
  end
end
