class DocumentFileArchivePreview
  DEFAULT_LIMIT = 300
  TEXT_PREVIEW_EXTENSIONS = %w[.csv .json .log .md .markdown .txt .tsv .yaml .yml].freeze

  Entry = Data.define(:name, :directory, :size) do
    def directory?
      directory
    end

    def parent_directory
      parent = File.dirname(normalized_name.delete_suffix("/"))
      parent == "." ? "/" : "#{parent}/"
    end

    def extension
      File.extname(normalized_name).downcase
    end

    def safe_path?
      return false if normalized_name.blank?
      return false if normalized_name.start_with?("/", "\\")
      return false if normalized_name.split("/").include?("..")

      true
    end

    def actionable?
      action_unavailable_reason.nil?
    end

    def download_candidate?
      actionable?
    end

    def text_preview_candidate?
      actionable? && extension.in?(TEXT_PREVIEW_EXTENSIONS)
    end

    def action_unavailable_reason
      return "directory entry は操作対象外です" if directory?
      return "unsafe path のため操作できません" unless safe_path?

      nil
    end

    private

    def normalized_name
      name.to_s.tr("\\", "/")
    end
  end

  DirectorySummary = Data.define(:path, :file_count, :folder_count, :total_file_size)

  Result = Data.define(:entries, :truncated, :limit, :error) do
    def truncated?
      truncated
    end

    def error?
      error.present?
    end

    def file_entries
      entries.reject(&:directory?)
    end

    def file_count
      file_entries.count
    end

    def folder_count
      entries.count(&:directory?)
    end

    def total_file_size
      file_entries.sum(&:size)
    end

    def actionable_entries
      entries.select(&:actionable?)
    end

    def text_preview_candidate_entries
      entries.select(&:text_preview_candidate?)
    end

    def download_candidate_entries
      entries.select(&:download_candidate?)
    end

    def directory_summaries
      summaries = Hash.new do |hash, path|
        hash[path] = { file_count: 0, folder_count: 0, total_file_size: 0 }
      end

      entries.each do |entry|
        summary = summaries[entry.parent_directory]

        if entry.directory?
          summary[:folder_count] += 1
        else
          summary[:file_count] += 1
          summary[:total_file_size] += entry.size
        end
      end

      summaries.map do |path, values|
        DirectorySummary.new(path:, **values)
      end.sort_by(&:path)
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
