class DocumentFileContentDisposition
  def initialize(document_file, disposition: "attachment")
    @document_file = document_file
    @disposition = disposition.to_s
  end

  def header
    %(#{safe_disposition}; filename="#{ascii_fallback}"; filename*=UTF-8''#{encoded_file_name})
  end

  def inline_header
    self.class.new(document_file, disposition: "inline").header
  end

  def attachment_header
    self.class.new(document_file, disposition: "attachment").header
  end

  private

  attr_reader :document_file, :disposition

  def safe_disposition
    %w[attachment inline].include?(disposition) ? disposition : "attachment"
  end

  def file_name
    document_file.file_name.to_s
  end

  def sanitized_file_name
    @sanitized_file_name ||= begin
      value = file_name.gsub(/[\\\/]/, "_").delete("\0").strip
      value.presence || "download"
    end
  end

  def ascii_fallback
    sanitized_file_name
      .unicode_normalize(:nfkd)
      .encode("US-ASCII", invalid: :replace, undef: :replace, replace: "")
      .to_s
      .force_encoding(Encoding::UTF_8)
      .gsub(/[\\\/]/, "_")
      .delete("\0")
      .strip
      .presence || "download"
  end

  def encoded_file_name
    ERB::Util.url_encode(sanitized_file_name).gsub("+", "%20")
  end
end
