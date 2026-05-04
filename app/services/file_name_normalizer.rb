class FileNameNormalizer
  WINDOWS_RESERVED_NAMES = %w[
    con prn aux nul
    com1 com2 com3 com4 com5 com6 com7 com8 com9
    lpt1 lpt2 lpt3 lpt4 lpt5 lpt6 lpt7 lpt8 lpt9
  ].freeze

  def initialize(file_name, fallback: "file")
    @file_name = file_name.to_s
    @fallback = fallback.to_s.presence || "file"
  end

  def call
    normalized = normalize_unicode(file_name)
      .delete("\0")
      .gsub(/[\\\/]/, "_")
      .gsub(/[[:cntrl:]]/, "")
      .strip
      .gsub(/[. ]+\z/, "")
      .presence || fallback

    avoid_reserved_name(normalized)
  end

  private

  attr_reader :file_name, :fallback

  def normalize_unicode(value)
    value.unicode_normalize(:nfc)
  rescue Encoding::CompatibilityError, ArgumentError
    value.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
  end

  def avoid_reserved_name(value)
    base = File.basename(value, File.extname(value)).downcase
    return value unless WINDOWS_RESERVED_NAMES.include?(base)

    "_#{value}"
  end
end
