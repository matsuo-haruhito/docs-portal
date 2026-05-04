class ContentDispositionFilename
  def initialize(file_name, disposition: "attachment")
    @file_name = file_name.to_s
    @disposition = disposition.to_s
  end

  def header
    %(#{safe_disposition}; filename="#{ascii_fallback}"; filename*=UTF-8''#{encoded_file_name})
  end

  def ascii_fallback
    normalized = sanitized_file_name
      .unicode_normalize(:nfkd)
      .encode("US-ASCII", invalid: :replace, undef: :replace, replace: "")
      .to_s
      .force_encoding(Encoding::UTF_8)
      .presence

    safe_ascii_name(normalized || fallback_name)
  end

  def encoded_file_name
    ERB::Util.url_encode(sanitized_file_name).gsub("+", "%20")
  end

  private

  attr_reader :file_name, :disposition

  def safe_disposition
    %w[attachment inline].include?(disposition) ? disposition : "attachment"
  end

  def sanitized_file_name
    @sanitized_file_name ||= begin
      value = file_name.gsub(/[\\\/]/, "_").delete("\0").strip
      value.presence || fallback_name
    end
  end

  def safe_ascii_name(value)
    value.to_s.gsub(/[\\\/]/, "_").delete("\0").strip.presence || fallback_name
  end

  def fallback_name
    "download"
  end
end
