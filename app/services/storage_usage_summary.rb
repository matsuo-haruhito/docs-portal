require "find"

class StorageUsageSummary
  TOP_BREAKDOWN_LIMIT = 5

  BreakdownEntry = Struct.new(:relative_path, :bytes, :file_count, :latest_updated_at, keyword_init: true) do
    def human_size
      ActiveSupport::NumberHelper.number_to_human_size(bytes)
    end
  end

  DocumentFileBreakdownEntry = Struct.new(
    :project_code,
    :project_name,
    :document_title,
    :document_slug,
    :bytes,
    :file_count,
    :missing_file_count,
    :latest_updated_at,
    keyword_init: true
  ) do
    def human_size
      ActiveSupport::NumberHelper.number_to_human_size(bytes)
    end
  end

  Area = Struct.new(:key, :label, :relative_path, :description, :bytes, :file_count, :breakdown_entries, keyword_init: true) do
    def human_size
      ActiveSupport::NumberHelper.number_to_human_size(bytes)
    end
  end

  Result = Struct.new(:areas, :document_file_breakdown_entries, keyword_init: true) do
    def total_bytes
      areas.sum(&:bytes)
    end

    def total_file_count
      areas.sum(&:file_count)
    end

    def human_total_size
      ActiveSupport::NumberHelper.number_to_human_size(total_bytes)
    end

    def document_file_breakdown_entries
      self[:document_file_breakdown_entries] || []
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
    Result.new(
      areas: AREA_DEFINITIONS.map { |definition| area_for(definition) },
      document_file_breakdown_entries: document_file_breakdown_entries
    )
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
      bytes, file_count, latest_updated_at = entry_stats(child_path)
      next if file_count.zero?

      BreakdownEntry.new(
        relative_path: Pathname("storage").join(definition.fetch(:directory), child_path.basename.to_s).to_s,
        bytes:,
        file_count:,
        latest_updated_at:
      )
    end.sort_by { |entry| [-entry.bytes, -entry.file_count, entry.relative_path] }.first(TOP_BREAKDOWN_LIMIT)
  end

  def document_file_breakdown_entries
    groups = {}

    DocumentFile.includes(document_version: { document: :project }).find_each do |file|
      version = file.document_version
      document = version.document
      project = document.project
      key = [project.id, document.id]
      group = groups[key] ||= {
        project:,
        document:,
        bytes: 0,
        file_count: 0,
        missing_file_count: 0,
        latest_updated_at: nil
      }

      group[:file_count] += 1
      group[:latest_updated_at] = [group[:latest_updated_at], file.updated_at, version.updated_at, document.updated_at].compact.max

      path = file.absolute_path
      if File.file?(path.to_s)
        group[:bytes] += File.size(path.to_s)
      else
        group[:missing_file_count] += 1
      end
    rescue ActiveRecord::RecordNotFound, Errno::ENOENT, Errno::EACCES
      group[:missing_file_count] += 1 if group
    end

    groups.values.map do |group|
      project = group.fetch(:project)
      document = group.fetch(:document)

      DocumentFileBreakdownEntry.new(
        project_code: project.code,
        project_name: project.name,
        document_title: document.title,
        document_slug: document.slug,
        bytes: group.fetch(:bytes),
        file_count: group.fetch(:file_count),
        missing_file_count: group.fetch(:missing_file_count),
        latest_updated_at: group.fetch(:latest_updated_at)
      )
    end.sort_by { |entry| [-entry.bytes, -entry.file_count, entry.project_code.to_s, entry.document_title.to_s] }.first(TOP_BREAKDOWN_LIMIT)
  end

  def child_paths(path)
    return [] unless path.directory?

    path.children
  rescue Errno::ENOENT, Errno::EACCES
    []
  end

  def entry_stats(path)
    if File.file?(path.to_s)
      [File.size(path.to_s), 1, File.mtime(path.to_s)]
    elsif File.directory?(path.to_s)
      directory_stats(path, include_latest_updated_at: true)
    else
      [0, 0, nil]
    end
  rescue Errno::ENOENT, Errno::EACCES
    [0, 0, nil]
  end

  def directory_stats(path, include_latest_updated_at: false)
    empty_directory_stats = include_latest_updated_at ? [0, 0, nil] : [0, 0]
    return empty_directory_stats unless path.directory?

    bytes = 0
    file_count = 0
    latest_updated_at = nil

    Find.find(path.to_s) do |entry|
      next unless File.file?(entry)

      bytes += File.size(entry)
      file_count += 1
      latest_updated_at = [latest_updated_at, File.mtime(entry)].compact.max if include_latest_updated_at
    rescue Errno::ENOENT, Errno::EACCES
      next
    end

    include_latest_updated_at ? [bytes, file_count, latest_updated_at] : [bytes, file_count]
  end
end
