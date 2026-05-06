class DocumentImportTargetResolver
  def initialize(project:, scope: nil)
    @project = project
    @scope = scope
  end

  def call(source_path:, slug: nil)
    by_source_path(source_path) ||
      by_slug(slug) ||
      unique_same_file_name(source_path)
  end

  private

  attr_reader :project, :scope

  def documents
    @documents ||= begin
      document_scope = scope || project.documents
      if document_scope.respond_to?(:includes)
        document_scope.includes(:latest_version).to_a
      else
        Array(document_scope)
      end
    end
  end

  def by_source_path(source_path)
    return if source_path.blank?

    normalized_source_path = normalize_path(source_path)
    documents.find do |document|
      normalize_path(document.latest_version&.source_relative_path) == normalized_source_path
    end
  end

  def by_slug(slug)
    return if slug.blank?

    documents.find { _1.slug == slug }
  end

  def unique_same_file_name(source_path)
    return if source_path.blank?

    file_name = File.basename(source_path)
    matches = documents.select { _1.latest_version&.source_file_name == file_name }
    matches.one? ? matches.first : nil
  end

  def normalize_path(value)
    value.to_s.unicode_normalize(:nfkc).strip.downcase.tr("\\", "/")
  end
end
