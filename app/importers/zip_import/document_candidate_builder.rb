module ZipImport
  class DocumentCandidateBuilder
    README_BASENAMES = %w[readme index].freeze
    LINK_PATTERN = /
      !?\[[^\]]*\]
      \(
        \s*
        (?<target>[^)\s]+(?:\s+[^)])*?)
        \s*
      \)
    /x.freeze

    def initialize(root:, path_classifier:, document_candidate_class:)
      @root = Pathname(root)
      @path_classifier = path_classifier
      @document_candidate_class = document_candidate_class
    end

    def call(path)
      logical_path = path_classifier.logical_path_for(path)
      frontmatter = path_classifier.markdown_file?(path) ? parse_frontmatter(path) : {}
      warnings = []

      attachment_paths = if path_classifier.markdown_file?(path)
        markdown_attachment_paths(path, logical_path, warnings)
      elsif path_classifier.diagram_file?(path)
        related_same_basename_files(path, logical_path)
      else
        [path]
      end

      attachment_paths.unshift(path) unless attachment_paths.include?(path)

      document_candidate_class.new(
        absolute_path: path,
        logical_path:,
        title: inferred_title(logical_path),
        slug: inferred_slug(logical_path, path),
        frontmatter:,
        document_kind: document_kind_for(path),
        attachment_paths: attachment_paths.uniq.sort_by(&:to_s),
        warnings:
      )
    end

    private

    attr_reader :root, :path_classifier, :document_candidate_class

    def document_kind_for(path)
      return "markdown" if path_classifier.markdown_file?(path)

      "mixed"
    end

    def markdown_attachment_paths(path, logical_path, warnings)
      attachments = []
      referenced_targets(path).each do |target|
        resolved = resolve_relative_target(logical_path, target)
        next if resolved.blank?

        absolute_path = root.join(resolved)
        if absolute_path.file?
          attachments << absolute_path
        else
          warnings << "referenced file is missing: #{resolved}"
        end
      end

      attachments
    end

    def related_same_basename_files(path, logical_path)
      path_in_root = root.join(File.dirname(logical_path))
      base_name = path.basename.sub_ext("").to_s

      Dir.glob(path_in_root.join("#{base_name}.*").to_s)
        .map { Pathname(_1) }
        .select(&:file?)
    end

    def referenced_targets(path)
      content = File.read(path, encoding: "UTF-8")
      content.scan(LINK_PATTERN).filter_map do |target|
        value = Array(target).first.to_s.strip
        next if value.blank?
        next if value.start_with?("#")
        next if value.match?(%r{\A[a-z][a-z0-9+\-.]*://}i)
        next if value.start_with?("mailto:")

        value.split("#").first.presence
      end.uniq
    rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
      []
    end

    def resolve_relative_target(logical_path, target)
      base_dir = Pathname(logical_path).dirname
      candidate = base_dir.join(target).cleanpath.to_s
      return if candidate == "." || candidate == ".." || candidate.start_with?("../")

      candidate
    end

    def parse_frontmatter(path)
      content = File.read(path, encoding: "UTF-8")
      return {} unless content.start_with?("---\n")

      closing_index = content.index("\n---\n", 4)
      return {} unless closing_index

      yaml = content[4...closing_index]
      parsed = YAML.safe_load(yaml, aliases: false)
      parsed.is_a?(Hash) ? parsed : {}
    rescue Psych::SyntaxError, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
      {}
    end

    def inferred_title(logical_path)
      path = Pathname(logical_path)
      base = path.basename.sub_ext("").to_s
      if README_BASENAMES.include?(base.downcase)
        directory = path.dirname.to_s
        return directory == "." ? "Home" : Pathname(directory).basename.to_s
      end

      base
    end

    def inferred_slug(logical_path, path)
      source = slug_source_for(logical_path, path)
      normalized = source.split("/").map { |segment| segment.parameterize.presence || "part" }.join("-")
      normalized.presence || "document"
    end

    def slug_source_for(logical_path, path)
      logical = Pathname(logical_path)
      base = logical.basename.sub_ext("").to_s
      if README_BASENAMES.include?(base.downcase)
        source = logical.dirname.to_s
        return "home" if source.blank? || source == "."

        return source
      end

      return logical.sub_ext("").to_s if path_classifier.renderable_document_file?(path)

      extension = logical.extname.delete_prefix(".").presence
      extension ? "#{logical.sub_ext('')}-#{extension}" : logical.to_s
    end
  end
end
