module AiContext
  class DocumentSectionBuilder
    def initialize(mode:)
      @mode = mode
    end

    def call(document)
      version = document.latest_version
      lines = [
        "### #{document.title}",
        "",
        "- slug: #{document.slug}",
        "- category: #{document.category}",
        "- document_kind: #{document.document_kind}",
        "- visibility_policy: #{document.visibility_policy}"
      ]

      lines.concat(version_metadata(version)) if version
      lines.concat(tag_metadata(document))
      lines.concat(keyword_metadata(document))
      lines.concat(body_text(version)) if mode == :full

      lines.join("\n")
    end

    private

    attr_reader :mode

    def version_metadata(version)
      [
        "- version: #{version.version_label}",
        "- status: #{version.status}",
        "- source_path: #{version.source_relative_path}",
        "- source_commit_hash: #{version.source_commit_hash}"
      ].compact_blank
    end

    def tag_metadata(document)
      return [] if document.document_tags.empty?

      ["- tags: #{document.document_tags.map(&:name).sort.join(', ')}"]
    end

    def keyword_metadata(document)
      return [] if document.document_keywords.empty?

      ["- keywords: #{document.document_keywords.map(&:keyword).sort.join(', ')}"]
    end

    def body_text(version)
      return [] if version.blank? || version.search_body_text.blank?

      [
        "",
        "#### Body",
        "",
        version.search_body_text
      ]
    end
  end
end
