require "json"
require "pathname"
require_relative "master_data_importer"
require_relative "external_sample_importer"

module SeedSupport
  class ExternalSampleValidator
    DEFAULT_ROOT = Rails.root.join("storage", "document_files", "external_samples")
    DEFAULT_MAX_ATTACHMENT_BYTES = 50 * 1024 * 1024

    Finding = Data.define(:level, :code, :message, :path) do
      def to_h
        {
          level: level,
          code: code,
          message: message,
          path: path
        }.compact
      end
    end

    Result = Data.define(:root, :documents, :warnings, :errors) do
      def valid? = errors.empty?

      def to_h
        {
          root: root.to_s,
          valid: valid?,
          summary: summary,
          candidates: documents.map { document_summary(_1) },
          warnings: warnings.map(&:to_h),
          errors: errors.map(&:to_h),
          note: "dry-run only; db:seed, standard showcase regeneration, CSV seed, Document, DocumentVersion, and DocumentFile writes are not executed"
        }
      end

      private

      def summary
        project_keys = documents.map { _1.fetch(:project_code) }.uniq
        attachment_count = documents.sum { _1.fetch(:attachment_files).size }

        {
          projects: project_keys.size,
          document_versions: documents.size,
          documents: documents.map { [_1.fetch(:project_code), _1.fetch(:slug)] }.uniq.size,
          attachments: attachment_count
        }
      end

      def document_summary(document)
        {
          project_code: document.fetch(:project_code),
          project_name: document.fetch(:project_name),
          title: document.fetch(:title),
          slug: document.fetch(:slug),
          version_label: document.fetch(:version_label),
          source_dir: document.fetch(:source_dir).to_s,
          markdown_path: document.fetch(:markdown_logical_relative_path).to_s,
          markdown_entry_path: document[:markdown_entry_path],
          site_build_path: document[:site_build_path],
          attachments: document.fetch(:attachment_files).size
        }.compact
      end
    end

    def initialize(root: DEFAULT_ROOT, max_attachment_bytes: DEFAULT_MAX_ATTACHMENT_BYTES, context: MasterDataImporter.new)
      @root = Pathname(root)
      @max_attachment_bytes = max_attachment_bytes
      @context = context
    end

    def call
      warnings = []
      errors = []

      unless root.exist?
        warnings << finding(:warning, :root_missing, "external sample root does not exist; run bin/setup_external_sample_data_links first", root.to_s)
        return Result.new(root:, documents: [], warnings:, errors:)
      end

      unless root.directory?
        errors << finding(:error, :root_not_directory, "external sample root must be a directory", root.to_s)
        return Result.new(root:, documents: [], warnings:, errors:)
      end

      warnings.concat(site_structure_warnings)

      documents = ExternalSampleImporter.new(context).documents(root)
      warnings << finding(:warning, :no_document_candidates, "no Markdown or renderable document candidates were found", relative_root) if documents.empty?

      validate_document_paths(documents, errors:)
      validate_large_attachments(documents, warnings:)
      validate_duplicate_candidates(documents, errors:)

      Result.new(root:, documents:, warnings:, errors:)
    end

    private

    attr_reader :root, :max_attachment_bytes, :context

    def site_structure_warnings
      sample_sets = child_directories(root)
      return [finding(:warning, :no_sample_sets, "no sample set directories were found", relative_root)] if sample_sets.empty?

      sample_sets.flat_map do |sample_set_dir|
        site_dirs = child_directories(sample_set_dir)
        site_dirs = [sample_set_dir] if site_dirs.empty?

        site_dirs.filter_map do |site_dir|
          next if Dir.glob(site_dir.join("**", "*.{md,markdown}").to_s, File::FNM_CASEFOLD).any?

          finding(:warning, :site_without_markdown, "site directory has no Markdown entry candidates", relative_path(site_dir))
        end
      end
    end

    def validate_document_paths(documents, errors:)
      documents.each do |document|
        source_dir = Pathname(document.fetch(:source_dir))
        validate_path_under_root(document.fetch(:markdown_source_file), source_dir, errors:, code: :markdown_outside_source_dir)

        document.fetch(:attachment_files).each do |attachment|
          validate_path_under_root(attachment, source_dir, errors:, code: :attachment_outside_source_dir)
        end
      end
    end

    def validate_path_under_root(path, source_dir, errors:, code:)
      expanded_source = source_dir.realpath
      expanded_path = Pathname(path).realpath
      return if inside_path?(expanded_path, expanded_source)

      errors << finding(:error, code, "candidate path escapes its source directory", relative_path(path))
    rescue Errno::ENOENT
      errors << finding(:error, :missing_candidate_file, "candidate file disappeared before validation", relative_path(path))
    end

    def validate_large_attachments(documents, warnings:)
      documents.each do |document|
        document.fetch(:attachment_files).each do |attachment|
          next unless File.file?(attachment)
          next if File.size(attachment) <= max_attachment_bytes

          warnings << finding(:warning, :large_attachment, "attachment is larger than the configured dry-run warning threshold", relative_path(attachment))
        end
      end
    end

    def validate_duplicate_candidates(documents, errors:)
      documents.group_by { [_1.fetch(:project_code), _1.fetch(:slug), _1.fetch(:version_label)] }.each do |key, grouped_documents|
        next if grouped_documents.one?

        errors << finding(
          :error,
          :duplicate_document_candidate,
          "multiple external sample candidates map to the same project, slug, and version: #{key.join(' / ')}",
          grouped_documents.map { relative_path(_1.fetch(:markdown_source_file)) }.join(", ")
        )
      end
    end

    def inside_path?(path, parent)
      path.to_s == parent.to_s || path.to_s.start_with?(parent.to_s + File::SEPARATOR)
    end

    def child_directories(path)
      path.children.select(&:directory?).sort_by(&:to_s)
    end

    def relative_root = root.relative_path_from(Rails.root).to_s

    def relative_path(path)
      Pathname(path).relative_path_from(Rails.root).to_s
    rescue ArgumentError
      Pathname(path).to_s
    end

    def finding(level, code, message, path = nil)
      Finding.new(level: level.to_s, code: code.to_s, message:, path:)
    end
  end
end
