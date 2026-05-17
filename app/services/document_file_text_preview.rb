class DocumentFileTextPreview
  DEFAULT_LIMIT = 2_000

  Result = Data.define(:lines, :truncated, :limit, :error) do
    def truncated?
      truncated
    end

    def error?
      error.present?
    end
  end

  def initialize(file:, limit: DEFAULT_LIMIT)
    @file = file
    @limit = limit
  end

  def call
    lines = []

    File.foreach(file.absolute_path, encoding: "UTF-8").with_index do |line, index|
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
