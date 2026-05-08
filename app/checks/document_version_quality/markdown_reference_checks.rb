require "set"

module DocumentVersionQuality
  class MarkdownReferenceChecks
    def initialize(document_version:, check_class:)
      @document_version = document_version
      @document = document_version.document
      @check_class = check_class
    end

    def call
      markdown_source_files.flat_map do |file|
        parse_markdown_targets(file).filter_map do |reference|
          next if markdown_reference_resolved?(reference)

          missing_reference_check(reference)
        end
      end
    end

    private

    attr_reader :document_version, :document, :check_class

    def markdown_source_files
      document_version.document_files.select do |file|
        file.effective_content_type.start_with?("text/markdown") && file.absolute_path.file?
      rescue ActiveRecord::RecordNotFound
        false
      end
    end

    def parse_markdown_targets(file)
      body = file.absolute_path.read
      body.scan(DocumentVersionQualityChecker::MARKDOWN_REFERENCE_PATTERN).map do |image_marker, raw_target|
        target = normalize_markdown_target(raw_target)
        next if target.blank? || ignored_markdown_target?(target)

        {
          kind: reference_kind(target, image_marker.present?),
          file_name: file.file_name,
          target:,
          resolved_target: resolve_reference_target(file, target)
        }
      end.compact
    rescue Errno::ENOENT
      []
    end

    def normalize_markdown_target(raw_target)
      value = raw_target.to_s.strip
      value = value.delete_prefix("<").delete_suffix(">")
      value.split(/\s+/, 2).first.to_s
    end

    def ignored_markdown_target?(target)
      target.start_with?("#") || target.match?(/\A[a-z][a-z0-9+\-.]*:/i)
    end

    def reference_kind(target, image_reference)
      return :image if image_reference || DocumentVersionQualityChecker::IMAGE_EXTENSIONS.include?(File.extname(target).downcase)
      return :document_link if document_link_target?(target)

      :attachment
    end

    def document_link_target?(target)
      extension = File.extname(target_without_suffixes(target)).downcase
      extension.blank? || DocumentVersionQualityChecker::MARKDOWN_EXTENSIONS.include?(extension) || extension == ".html"
    end

    def target_without_suffixes(target)
      target.to_s.split("#", 2).first.split("?", 2).first
    end

    def resolve_reference_target(file, target)
      relative_target = target_without_suffixes(target)
      base_dir = markdown_source_directory(file)
      Pathname.new(base_dir.to_s).join(relative_target).cleanpath.to_s
    end

    def markdown_source_directory(file)
      source_path = document_version.source_relative_path.presence || file.file_name
      path = Pathname.new(source_path)
      path.dirname.to_s == "." ? "" : path.dirname.to_s
    end

    def markdown_reference_resolved?(reference)
      case reference[:kind]
      when :document_link
        available_document_targets.include?(reference[:resolved_target]) ||
          available_document_targets.include?("#{reference[:resolved_target]}.md") ||
          available_document_targets.include?("#{reference[:resolved_target]}.markdown") ||
          available_document_targets.include?(Pathname.new(reference[:resolved_target]).join("README.md").to_s) ||
          available_document_targets.include?(Pathname.new(reference[:resolved_target]).join("index.md").to_s)
      when :image, :attachment
        available_attachment_targets.include?(File.basename(reference[:resolved_target])) ||
          available_attachment_targets.include?(reference[:resolved_target])
      else
        false
      end
    end

    def available_document_targets
      @available_document_targets ||= DocumentVersion
        .joins(:document)
        .where(documents: { project_id: document.project_id })
        .where.not(source_relative_path: [nil, ""])
        .pluck(:source_relative_path)
        .to_set
    end

    def available_attachment_targets
      @available_attachment_targets ||= document_version.document_files.filter_map do |file|
        next unless file.absolute_path.file?

        [file.file_name, file.storage_key]
      rescue ActiveRecord::RecordNotFound
        next
      end.flatten.to_set
    end

    def missing_reference_check(reference)
      detail = "#{reference[:file_name]} -> #{reference[:target]}"

      case reference[:kind]
      when :document_link
        error(:markdown_link_missing, "Markdown link target is missing", detail)
      when :image
        error(:markdown_image_missing, "Markdown image target is missing", detail)
      when :attachment
        error(:markdown_attachment_missing, "Markdown attachment target is missing", detail)
      end
    end

    def error(key, message, detail = nil)
      check_class.new(key:, severity: :error, message:, detail:)
    end
  end
end
