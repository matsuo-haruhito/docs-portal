require "csv"

class DocumentFileCsvPreview
  DEFAULT_LIMIT = 200

  Result = Data.define(:rows, :truncated, :limit, :error) do
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
    rows = []

    CSV.foreach(file.absolute_path, col_sep:, liberal_parsing: true).with_index do |row, index|
      return Result.new(rows:, truncated: true, limit:, error: nil) if index >= limit

      rows << row.fields.map(&:to_s)
    end

    Result.new(rows:, truncated: false, limit:, error: nil)
  rescue CSV::MalformedCSVError, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError => e
    Result.new(rows: [], truncated: false, limit:, error: e.message)
  end

  private

  attr_reader :file, :limit

  def col_sep
    tsv? ? "\t" : ","
  end

  def tsv?
    File.extname(file.file_name.to_s).downcase == ".tsv" ||
      file.effective_content_type.delete_suffix("; charset=utf-8") == "text/tab-separated-values"
  end
end
