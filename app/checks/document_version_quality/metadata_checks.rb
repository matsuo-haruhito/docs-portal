module DocumentVersionQuality
  class MetadataChecks
    MARKDOWN_EXTENSIONS = %w[.md .markdown .mdx].freeze

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
        internal_only_text_check,
        path_history_check,
        path_history_metadata_source_check,
        path_history_metadata_status_entries_check,
        *path_history_metadata_warning_checks,
        preview_target_metadata_source_check,
        *preview_target_metadata_warning_checks,
        docusaurus_build_manifest_source_check,
        *docusaurus_build_manifest_warning_checks
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
      if document_version.site_build_path.blank?
        return warning(:rendered_site, "Markdown preview site is not built yet", document_version.source_relative_path) if markdown_source?

        return
      end

      return info(:rendered_site, "Rendered site entry exists", document_version.site_entry_relative_path) if document_version.rendered_site_available?

      error(:rendered_site, "Rendered site entry is missing", document_version.site_entry_relative_path)
    end

    def markdown_source?
      File.extname(document_version.source_relative_path.to_s).downcase.in?(MARKDOWN_EXTENSIONS)
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

    def path_history_check
      return unless path_history_summary.present?

      warning(
        :path_history,
        "Document has historical preview paths that redirect to the current path",
        "#{path_history_summary.paths.join(', ')} -> #{path_history_summary.canonical_path}"
      )
    end

    def path_history_metadata_source_check
      return info(:path_history_metadata, "Path history metadata source is not set") unless path_history_metadata.source_file?

      info(:path_history_metadata, "Path history metadata source is set", path_history_metadata.source_file.tree_path)
    end

    def path_history_metadata_status_entries_check
      return unless path_history_metadata.status_entries.any?

      counts = path_history_metadata.status_entries.group_by(&:status).transform_values(&:count)
      detail = counts.sort.map { |status, count| "#{status}=#{count}" }.join(", ")
      info(:path_history_metadata_status, "Path history metadata status entries are set", detail)
    end

    def path_history_metadata_warning_checks
      path_history_metadata.warnings.map do |metadata_warning|
        warning(:path_history_metadata, metadata_warning.message, metadata_warning.detail)
      end
    end

    def preview_target_metadata_source_check
      return info(:preview_target_metadata, "Preview target metadata source is not set") unless preview_target_metadata.source_file?

      info(:preview_target_metadata, "Preview target metadata source is set", preview_target_metadata.source_file.tree_path)
    end

    def preview_target_metadata_warning_checks
      preview_target_metadata.warnings.map do |metadata_warning|
        warning(:preview_target_metadata, metadata_warning.message, metadata_warning.path)
      end
    end

    def docusaurus_build_manifest_source_check
      return if document_version.site_build_path.blank?
      return info(:docusaurus_build_manifest, "Docusaurus build manifest source is not set") unless docusaurus_build_manifest.source_file?

      info(:docusaurus_build_manifest, "Docusaurus build manifest source is set", docusaurus_build_manifest.source_path)
    end

    def docusaurus_build_manifest_warning_checks
      return [] if document_version.site_build_path.blank?

      docusaurus_build_manifest.warnings.map do |manifest_warning|
        warning(:docusaurus_build_manifest, manifest_warning.message, manifest_warning.detail)
      end
    end

    def path_history_summary
      @path_history_summary ||= DocumentPathHistorySummary.new(document_version).call
    end

    def path_history_metadata
      @path_history_metadata ||= DocumentPathHistoryMetadata.new(document_version).call
    end

    def preview_target_metadata
      @preview_target_metadata ||= DocumentVersionPreviewTargetMetadata.new(document_version).call
    end

    def docusaurus_build_manifest
      @docusaurus_build_manifest ||= DocusaurusBuildManifest.new(document_version).call
    end

    def info(key, message, detail = nil)
      check_class.new(key:, severity: :info, message:, detail:)
    end

    def warning(key, message, detail = nil)
      check_class.new(key:, severity: :warning, message:, detail:)
    end

    def error(key, message, detail = nil)
      check_class.new(key:, severity: :error, detail:, message:)
    end
  end
end
