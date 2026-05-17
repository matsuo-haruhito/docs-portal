class DocumentFileTextPreview
  DEFAULT_LIMIT = 2_000

  Result = Data.define(:lines, :truncated, :limit, :error) do
    include DocumentFilePreviewResultHelpers

    def line_count
      lines.count
    end
  end

  def initialize(file:, limit: DEFAULT_LIMIT)
    @file = file
    @limit = limit
  end

  def call
    content = File.binread(file.absolute_path)
    content.force_encoding("UTF-8")
    raise Encoding::InvalidByteSequenceError, "invalid byte sequence in UTF-8" unless content.valid_encoding?

    lines = []
    content.each_line.with_index do |line, index|
      return Result.new(lines:, truncated: true, limit:, error: nil) if index >= limit

      lines << line.chomp
    end

    Result.new(lines:, truncated: false, limit:, error: nil)
  rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError => e
    Result.new(lines: [], truncated: false, limit:, error: e.message)
  end

  private

  attr_reader :file, :limit
end
