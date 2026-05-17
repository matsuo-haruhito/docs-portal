class DocumentFileArchiveEntryLookup
  DEFAULT_MAX_SIZE = 1.megabyte

  Result = Data.define(:entry_path, :found, :directory, :safe_path, :size, :content_type, :filename, :reason) do
    def found?
      found
    end

    def directory?
      directory
    end

    def safe_path?
      safe_path
    end

    def error?
      reason.present?
    end

    def previewable?
      found? && safe_path? && !directory? && text_preview_candidate? && !size_over_limit?
    end

    def downloadable?
      found? && safe_path? && !directory? && !size_over_limit?
    end

    def text_preview_candidate?
      File.extname(entry_path.to_s).downcase.in?(DocumentFileArchivePreview::TEXT_PREVIEW_EXTENSIONS)
    end

    def size_over_limit?
      size.to_i > DEFAULT_MAX_SIZE
    end
  end

  def initialize(file:, entry_path:, max_size: DEFAULT_MAX_SIZE)
    @file = file
    @entry_path = entry_path
    @max_size = max_size
  end

  def call
    normalized_path = normalize_path(entry_path)
    return failure(normalized_path, safe_path: false, reason: "unsafe path のため操作できません") unless safe_path?(normalized_path)
    return unsupported_result(normalized_path) unless zip?

    Zip::File.open(file.absolute_path) do |zip_file|
      zip_entry = zip_file.find_entry(normalized_path)
      return failure(normalized_path, reason: "entry が見つかりません") unless zip_entry

      result_for(zip_entry, normalized_path)
    end
  rescue Zip::Error, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError => e
    failure(normalize_path(entry_path), reason: e.message)
  end

  private

  attr_reader :file, :entry_path, :max_size

  def result_for(zip_entry, normalized_path)
    directory = zip_entry.directory?
    size = zip_entry.size.to_i
    reason = unavailable_reason(normalized_path, directory:, size:)

    Result.new(
      entry_path: normalized_path,
      found: true,
      directory:,
      safe_path: true,
      size:,
      content_type: content_type_for(normalized_path),
      filename: File.basename(normalized_path.delete_suffix("/")),
      reason:
    )
  end

  def unavailable_reason(normalized_path, directory:, size:)
    return "directory entry は操作対象外です" if directory
    return "entry size が上限を超えています" if size.to_i > max_size
    return "text preview 対象外です" unless text_preview_candidate?(normalized_path)

    nil
  end

  def failure(normalized_path, safe_path: safe_path?(normalized_path), reason:)
    Result.new(
      entry_path: normalized_path,
      found: false,
      directory: false,
      safe_path:,
      size: 0,
      content_type: nil,
      filename: nil,
      reason:
    )
  end

  def unsupported_result(normalized_path)
    failure(normalized_path, reason: "この archive 形式の entry lookup は未対応です")
  end

  def content_type_for(normalized_path)
    case File.extname(normalized_path).downcase
    when ".csv"
      "text/csv"
    when ".json"
      "application/json"
    when ".tsv"
      "text/tab-separated-values"
    when ".yaml", ".yml"
      "text/yaml"
    else
      "text/plain"
    end
  end

  def text_preview_candidate?(normalized_path)
    File.extname(normalized_path.to_s).downcase.in?(DocumentFileArchivePreview::TEXT_PREVIEW_EXTENSIONS)
  end

  def normalize_path(value)
    value.to_s.tr("\\", "/").delete_prefix("/")
  end

  def safe_path?(normalized_path)
    normalized_path.present? && !normalized_path.start_with?("/", "\\") && !normalized_path.split("/").include?("..")
  end

  def zip?
    File.extname(file.file_name.to_s).downcase == ".zip" || file.effective_content_type == "application/zip"
  end
end
