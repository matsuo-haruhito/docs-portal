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
  DEFAULT_READ_TIMEOUT = 210

  def initialize(
    endpoint: ENV.fetch("DOCUSAURUS_RENDERER_ENDPOINT", DEFAULT_ENDPOINT),
    read_timeout: ENV.fetch("DOCUSAURUS_RENDERER_READ_TIMEOUT_SECONDS", DEFAULT_READ_TIMEOUT)
  )
    @endpoint = endpoint.to_s.delete_suffix("/")
    @read_timeout = Integer(read_timeout.to_s, 10)
    raise ArgumentError, "renderer read timeout must be positive" unless @read_timeout.positive?
  end

  def build(archive_file:, entry_path:)
    uri = URI.join("#{endpoint}/", "build")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/gzip"
    request["X-Docs-Entry-Path"] = URI::RFC2396_PARSER.escape(entry_path)
    archive_file.rewind
    request.body_stream = archive_file
    request.content_length = archive_file.size

    response = http_for(uri).request(request)
    if response.is_a?(Net::HTTPTooManyRequests)
      raise TransientError, renderer_error_message(response)
    end
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
      site_path: safe_site_path(decode_site_path_header(response["X-Docs-Site-Path"]) || normalize_site_page_path(entry_path))
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

  attr_reader :endpoint, :read_timeout

  def http_for(uri)
    Net::HTTP.new(uri.host, uri.port).tap do |http|
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = read_timeout
    end
  end

  def renderer_error_message(response)
    body = response.body.to_s
    json = JSON.parse(body) rescue nil
    message = renderer_error_from_json(json).presence || body.presence || response.message
    "Docusaurus preview build failed: #{message}"
  end

  def renderer_error_from_json(json)
    return unless json.is_a?(Hash)

    json["error"].presence || json["message"].presence || Array(json["errors"]).compact_blank.join(", ").presence
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

  def decode_site_path_header(raw)
    return nil if raw.blank?

    URI.decode_www_form_component(raw).presence
  rescue ArgumentError
    raw.presence
  end
end
