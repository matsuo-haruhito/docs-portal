class DocumentFileHealthCheck
  Result = Data.define(:total_count, :missing_files, :missing_count, :filtered_missing_count, :filters) do
    def healthy?
      missing_count.zero?
    end

    def filtered?
      filters.values.any?(&:present?)
    end
  end

  def initialize(scope = DocumentFile.all)
    @scope = scope
  end

  def call(limit: 20, filters: {})
    normalized_filters = normalize_filters(filters)
    missing = []
    total = 0
    missing_count = 0
    filtered_missing_count = 0

    files.find_each do |file|
      total += 1
      next unless missing_file?(file)

      missing_count += 1
      next unless matches_filters?(file, normalized_filters)

      filtered_missing_count += 1
      missing << file if missing.length < limit
    end

    Result.new(
      total_count: total,
      missing_files: missing,
      missing_count:,
      filtered_missing_count:,
      filters: normalized_filters
    )
  end

  private

  attr_reader :scope

  def files
    scope.includes(document_version: { document: :project }).order(:id)
  end

  def missing_file?(file)
    !File.file?(file.absolute_path)
  end

  def normalize_filters(filters)
    {
      project_id: filters[:project_id].presence,
      document_q: filters[:document_q].to_s.strip.downcase.presence,
      file_q: filters[:file_q].to_s.strip.downcase.presence
    }
  end

  def matches_filters?(file, filters)
    version = file.document_version
    document = version.document

    return false if filters[:project_id].present? && document.project_id.to_s != filters[:project_id].to_s
    return false if filters[:document_q].present? && !document_matches?(document, filters[:document_q])
    return false if filters[:file_q].present? && !file_matches?(file, filters[:file_q])

    true
  end

  def document_matches?(document, query)
    [document.title, document.slug].any? { |value| value.to_s.downcase.include?(query) }
  end

  def file_matches?(file, query)
    [file.storage_key, file.file_name].any? { |value| value.to_s.downcase.include?(query) }
  end
end
