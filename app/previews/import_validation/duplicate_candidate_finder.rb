module ImportValidation
  class DuplicateCandidateFinder
    def initialize(project_documents:, existing_document:, duplicate_candidate_class:)
      @project_documents = project_documents
      @existing_document = existing_document
      @duplicate_candidate_class = duplicate_candidate_class
    end

    def call(source_path:, title:)
      matches = []

      if source_path.present?
        by_path = project_documents.select do |document|
          document.id != existing_document&.id &&
            normalize_path(document.latest_version&.source_relative_path) == normalize_path(source_path)
        end
        matches << duplicate_candidate_class.new(reason: :same_source_relative_path, documents: by_path, value: normalize_path(source_path)) if by_path.any?

        basename = normalize_text(File.basename(source_path, File.extname(source_path)))
        by_basename = project_documents.select do |document|
          document.id != existing_document&.id &&
            normalize_text(document.latest_version&.source_basename) == basename
        end
        matches << duplicate_candidate_class.new(reason: :same_source_basename, documents: by_basename, value: basename) if by_basename.any?
      end

      normalized_title = normalize_text(title)
      if normalized_title.present?
        by_title = project_documents.select do |document|
          document.id != existing_document&.id &&
            normalize_text(document.title) == normalized_title
        end
        matches << duplicate_candidate_class.new(reason: :same_title, documents: by_title, value: normalized_title) if by_title.any?
      end

      matches
    end

    private

    attr_reader :project_documents, :existing_document, :duplicate_candidate_class

    def normalize_text(value)
      value.to_s.unicode_normalize(:nfkc).strip.downcase.presence
    end

    def normalize_path(value)
      normalize_text(value)&.tr("\\", "/")
    end
  end
end
