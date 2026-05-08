module ImportValidation
  class ItemBuilder
    def initialize(project:, entry:, classifier:, item_class:, duplicate_candidate_class:, project_documents:)
      @project = project
      @entry = entry
      @classifier = classifier
      @item_class = item_class
      @duplicate_candidate_class = duplicate_candidate_class
      @project_documents = project_documents
    end

    def call
      errors = []
      warnings = []
      source_path = normalize_source_path(entry.source_path, errors)
      existing_document = existing_document_for(source_path)
      classification = classifier.suggest(
        source_path: source_path.presence || entry.source_path,
        file_name: entry.file_name,
        frontmatter: entry.frontmatter
      )

      attributes = classification.attributes.merge(
        title: entry.title.presence || inferred_title,
        source_relative_path: source_path
      )

      errors << "source_path is required" if source_path.blank?
      warnings << "title is inferred from file name" if entry.title.blank?
      warnings << "existing document will receive a new version" if existing_document.present?
      duplicate_candidates = duplicate_candidate_finder(existing_document).call(
        source_path:,
        title: attributes[:title]
      )
      warnings << "similar documents found" if duplicate_candidates.any? && existing_document.blank?

      item_class.new(
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

    private

    attr_reader :project, :entry, :classifier, :item_class, :duplicate_candidate_class, :project_documents

    def normalize_source_path(source_path, errors)
      DocumentVersion.normalize_source_relative_path!(source_path)
    rescue ApplicationError::BadRequest => e
      errors << e.message
      nil
    end

    def existing_document_for(source_path)
      DocumentImportTargetResolver.new(project:, scope: project_documents).call(source_path:, slug: nil)
    end

    def inferred_title
      File.basename(entry.source_path.to_s, File.extname(entry.source_path.to_s)).presence || "Untitled"
    end

    def duplicate_candidate_finder(existing_document)
      DuplicateCandidateFinder.new(
        project_documents:,
        existing_document:,
        duplicate_candidate_class:
      )
    end
  end
end
