class DocumentFileArchivePreview
  DEFAULT_LIMIT = 300

  Entry = Data.define(:name, :directory, :size) do
    def directory?
      directory
    end
  end

  Result = Data.define(:entries, :truncated, :limit, :error) do
    def truncated?
      truncated
    end

    def error?
      error.present?
    end

    def file_count
      entries.count { !_1.directory? }
    end

    def folder_count
      entries.count(&:directory?)
    end

    def total_file_size
      entries.reject(&:directory?).sum(&:size)
    end
  end

  def initialize(file:, limit: DEFAULT_LIMIT)
    @file = file
    @limit = limit
  end

  def call
    return unsupported_result unless zip?

    entries = []

    Zip::File.open(file.absolute_path) do |zip_file|
      zip_file.each.with_index do |entry, index|
        return Result.new(entries:, truncated: true, limit:, error: nil) if index >= limit

        entries << Entry.new(name: entry.name.to_s, directory: entry.directory?, size: entry.size.to_i)
      end
    end

    Result.new(entries:, truncated: false, limit:, error: nil)
  rescue Zip::Error, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError => e
    Result.new(entries: [], truncated: false, limit:, error: e.message)
  end

  private

  attr_reader :file, :limit

  def zip?
    File.extname(file.file_name.to_s).downcase == ".zip" || file.effective_content_type == "application/zip"
  end

  def unsupported_result
    Result.new(entries: [], truncated: false, limit:, error: "この archive 形式の一覧 preview は未対応です")
  end
end
