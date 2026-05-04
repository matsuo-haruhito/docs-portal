class ImportDryRunValidator
  Entry = Data.define(:source_path, :title, :frontmatter, :content) do
    def file_name
      File.basename(source_path.to_s)
    end
  end

  Item = Data.define(:entry, :action, :attributes, :warnings, :errors, :matched_rules, :existing_document) do
    def valid?
      errors.empty?
    end

    def create?
      action == :create
    end

    def update?
      action == :update
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

    Item.new(
      entry:,
      action: existing_document.present? ? :update : :create,
      attributes:,
      warnings:,
      errors:,
      matched_rules: classification.matched_rules,
      existing_document:
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

    project.documents.includes(:latest_version).find do |document|
      document.latest_version&.source_relative_path == source_path || document.title == title
    end
  end

  def inferred_title(entry)
    File.basename(entry.source_path.to_s, File.extname(entry.source_path.to_s)).presence || "Untitled"
  end
end
