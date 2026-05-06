class ImportDryRunValidator
  Entry = Data.define(:source_path, :title, :frontmatter, :content) do
    def file_name
      File.basename(source_path.to_s)
    end
  end

  DuplicateCandidate = Data.define(:reason, :documents, :value)

  Item = Data.define(:entry, :action, :attributes, :warnings, :errors, :matched_rules, :existing_document, :duplicate_candidates) do
    def valid?
      errors.empty?
    end

    def create?
      action == :create
    end

    def update?
      action == :update
    end

    def source_path
      attributes[:source_relative_path].presence || entry.source_path
    end
  end

  Summary = Data.define(:total, :create_count, :update_count, :valid_count, :invalid_count, :warning_count, :error_count, :source_paths) do
    def valid?
      invalid_count.zero?
    end
  end

  Result = Data.define(:items) do
    def valid?
      errors.empty?
    end

    def errors
      items.flat_map(&:errors)
    end

    def warnings
      items.flat_map(&:warnings)
    end

    def creates
      items.select(&:create?)
    end

    def updates
      items.select(&:update?)
    end

    def invalid_items
      items.reject(&:valid?)
    end

    def summary
      Summary.new(
        total: items.size,
        create_count: creates.size,
        update_count: updates.size,
        valid_count: items.count(&:valid?),
        invalid_count: invalid_items.size,
        warning_count: warnings.size,
        error_count: errors.size,
        source_paths: items.map(&:source_path)
      )
    end
  end

  def initialize(project:, entries:, classifier: DocumentClassificationSuggester.new)
    @project = project
    @entries = entries.map { normalize_entry(_1) }
    @classifier = classifier
  end

  def call
    Result.new(items: entries.map { build_item(_1) })
  end

  private

  attr_reader :project, :entries, :classifier

  def build_item(entry)
    errors = []
    warnings = []
    source_path = normalize_source_path(entry.source_path, errors)
    existing_document = existing_document_for(source_path, entry.title)
    classification = classifier.suggest(
      source_path: source_path.presence || entry.source_path,
      file_name: entry.file_name,
      frontmatter: entry.frontmatter
    )

    attributes = classification.attributes.merge(
      title: entry.title.presence || inferred_title(entry),
      source_relative_path: source_path
    )

    errors << "source_path is required" if source_path.blank?
    warnings << "title is inferred from file name" if entry.title.blank?
    warnings << "existing document will receive a new version" if existing_document.present?
    duplicate_candidates = duplicate_candidates_for(source_path:, title: attributes[:title], existing_document:)
    warnings << "similar documents found" if duplicate_candidates.any? && existing_document.blank?

    Item.new(
      entry:,
      action: existing_document.present? ? :update : :create,
      attributes:,
      warnings:,
      errors:,
      matched_rules: classification.matched_rules,
      existing_document:,
      duplicate_candidates:
    )
  end

  def normalize_entry(value)
    return value if value.is_a?(Entry)

    Entry.new(
      source_path: value.fetch(:source_path),
      title: value[:title],
      frontmatter: value.fetch(:frontmatter, {}),
      content: value[:content]
    )
  end

  def normalize_source_path(source_path, errors)
    DocumentVersion.normalize_source_relative_path!(source_path)
  rescue ApplicationError::BadRequest => e
    errors << e.message
    nil
  end

  def existing_document_for(source_path, title)
    return if source_path.blank?

    exact_match = project_documents.find do |document|
      normalize_path(document.latest_version&.source_relative_path) == normalize_path(source_path)
    end
    return exact_match if exact_match.present?

    file_name = File.basename(source_path)
    same_file_name_documents = project_documents.select do |document|
      document.latest_version&.source_file_name == file_name
    end

    same_file_name_documents.one? ? same_file_name_documents.first : nil
  end

  def inferred_title(entry)
    File.basename(entry.source_path.to_s, File.extname(entry.source_path.to_s)).presence || "Untitled"
  end

  def duplicate_candidates_for(source_path:, title:, existing_document:)
    matches = []

    if source_path.present?
      by_path = project_documents.select do |document|
        document.id != existing_document&.id &&
          normalize_path(document.latest_version&.source_relative_path) == normalize_path(source_path)
      end
      matches << DuplicateCandidate.new(reason: :same_source_relative_path, documents: by_path, value: normalize_path(source_path)) if by_path.any?

      basename = normalize_text(File.basename(source_path, File.extname(source_path)))
      by_basename = project_documents.select do |document|
        document.id != existing_document&.id &&
          normalize_text(document.latest_version&.source_basename) == basename
      end
      matches << DuplicateCandidate.new(reason: :same_source_basename, documents: by_basename, value: basename) if by_basename.any?
    end

    normalized_title = normalize_text(title)
    if normalized_title.present?
      by_title = project_documents.select do |document|
        document.id != existing_document&.id &&
          normalize_text(document.title) == normalized_title
      end
      matches << DuplicateCandidate.new(reason: :same_title, documents: by_title, value: normalized_title) if by_title.any?
    end

    matches
  end

  def project_documents
    @project_documents ||= project.documents.includes(:latest_version).to_a
  end

  def normalize_text(value)
    value.to_s.unicode_normalize(:nfkc).strip.downcase.presence
  end

  def normalize_path(value)
    normalize_text(value)&.tr("\\", "/")
  end
end
