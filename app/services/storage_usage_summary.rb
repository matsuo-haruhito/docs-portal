require "find"

class StorageUsageSummary
  TOP_BREAKDOWN_LIMIT = 5

  BreakdownEntry = Struct.new(:relative_path, :bytes, :file_count, keyword_init: true) do
    def human_size
      ActiveSupport::NumberHelper.number_to_human_size(bytes)
    end
  end

  Area = Struct.new(:key, :label, :relative_path, :description, :bytes, :file_count, :breakdown_entries, keyword_init: true) do
    def human_size
      ActiveSupport::NumberHelper.number_to_human_size(bytes)
    end
  end

  Result = Struct.new(:areas, keyword_init: true) do
    def total_bytes
      areas.sum(&:bytes)
    end

    def total_file_count
      areas.sum(&:file_count)
    end

    def human_total_size
      ActiveSupport::NumberHelper.number_to_human_size(total_bytes)
    end
  end

  AREA_DEFINITIONS = [
    {
      key: :document_files,
      label: "DocumentFile 実体",
      directory: "document_files",
      description: "アップロード、ZIP/Git/外部同期で取り込まれた文書添付の正本"
    },
    {
      key: :docs_sites,
      label: "Docs site build",
      directory: "docs_sites",
      description: "Docusaurus などで生成した文書表示用 site artifact"
    },
    {
      key: :imports,
      label: "Import staging",
      directory: "imports",
      description: "ZIP / manual upload dry-run などの一時確認 artifact"
    }
  ].freeze

  def initialize(storage_root: Rails.root.join("storage"))
    @storage_root = Pathname(storage_root)
  end

  def call
    Result.new(areas: AREA_DEFINITIONS.map { |definition| area_for(definition) })
  end

  private

  attr_reader :storage_root

  def area_for(definition)
    path = storage_root.join(definition.fetch(:directory)).cleanpath
    bytes, file_count = directory_stats(path)

    Area.new(
      key: definition.fetch(:key),
      label: definition.fetch(:label),
      relative_path: Pathname("storage").join(definition.fetch(:directory)).to_s,
      description: definition.fetch(:description),
      bytes:,
      file_count:,
      breakdown_entries: breakdown_entries_for(definition, path)
    )
  end

  def breakdown_entries_for(definition, path)
    child_paths(path).filter_map do |child_path|
      bytes, file_count = entry_stats(child_path)
      next if file_count.zero?

      BreakdownEntry.new(
        relative_path: Pathname("storage").join(definition.fetch(:directory), child_path.basename.to_s).to_s,
        bytes:,
        file_count:
      )
    end.sort_by { |entry| [-entry.bytes, -entry.file_count, entry.relative_path] }.first(TOP_BREAKDOWN_LIMIT)
  end

  def child_paths(path)
    return [] unless path.directory?

    path.children
  rescue Errno::ENOENT, Errno::EACCES
    []
  end

  def entry_stats(path)
    if File.file?(path.to_s)
      [File.size(path.to_s), 1]
    elsif File.directory?(path.to_s)
      directory_stats(path)
    else
      [0, 0]
    end
  rescue Errno::ENOENT, Errno::EACCES
    [0, 0]
  end

  def directory_stats(path)
    return [0, 0] unless path.directory?

    bytes = 0
    file_count = 0

    Find.find(path.to_s) do |entry|
      next unless File.file?(entry)

      bytes += File.size(entry)
      file_count += 1
    rescue Errno::ENOENT, Errno::EACCES
      next
    end

    [bytes, file_count]
  end
end
