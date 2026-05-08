module DocumentVersionQuality
  class MetadataChecks
    def initialize(document_version:, check_class:)
      @document_version = document_version
      @document = document_version.document
      @check_class = check_class
    end

    def call
      [
        title_check,
        category_check,
        document_kind_check,
        visibility_policy_check,
        source_path_check,
        rendered_site_check,
        attachment_count_check,
        internal_only_text_check
      ].compact
    end

    private

    attr_reader :document_version, :document, :check_class

    def title_check
      return info(:title, "Document title is present", document.title) if document.title.present?

      error(:title, "Document title is missing")
    end

    def category_check
      return info(:category, "Document category is set", document.category) if document.category.present?

      warning(:category, "Document category is missing")
    end

    def document_kind_check
      return info(:document_kind, "Document kind is set", document.document_kind) if document.document_kind.present?

      warning(:document_kind, "Document kind is missing")
    end

    def visibility_policy_check
      return info(:visibility_policy, "Visibility policy is set", document.visibility_policy) if document.visibility_policy.present?

      warning(:visibility_policy, "Visibility policy is missing")
    end

    def source_path_check
      return info(:source_relative_path, "Source path is set", document_version.source_relative_path) if document_version.source_relative_path.present?

      info(:source_relative_path, "Source path is not set")
    end

    def rendered_site_check
      return if document_version.site_build_path.blank?
      return info(:rendered_site, "Rendered site entry exists", document_version.site_entry_relative_path) if document_version.rendered_site_available?

      error(:rendered_site, "Rendered site entry is missing", document_version.site_entry_relative_path)
    end

    def attachment_count_check
      count = document_version.document_files.size
      return warning(:document_files, "No document files are attached") if count.zero?

      info(:document_files, "Document files are attached", count)
    end

    def internal_only_text_check
      text = [document.title, document_version.search_body_text].compact.join("\n")
      pattern = DocumentVersionQualityChecker::INTERNAL_ONLY_PATTERNS.find { text.match?(_1) }
      return unless pattern

      warning(:internal_only_text, "Document contains internal-only wording", pattern.source)
    end

    def info(key, message, detail = nil)
      check_class.new(key:, severity: :info, message:, detail:)
    end

    def warning(key, message, detail = nil)
      check_class.new(key:, severity: :warning, message:, detail:)
    end

    def error(key, message, detail = nil)
      check_class.new(key:, severity: :error, message:, detail:)
    end
  end
end
