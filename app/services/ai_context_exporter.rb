class AiContextExporter
  MODES = %i[compact full].freeze

  def initialize(project:, user:, mode: :compact, scope: nil)
    @project = project
    @user = user
    @mode = mode.to_sym
    @scope = scope
  end

  def call
    raise ArgumentError, "unsupported AI context export mode: #{mode}" unless MODES.include?(mode)

    [
      project_heading,
      project_metadata,
      documents_section
    ].join("\n\n").strip + "\n"
  end

  private

  attr_reader :project, :user, :mode, :scope

  def project_heading
    "# Project: #{project.name}"
  end

  def project_metadata
    lines = [
      "- code: #{project.code}",
      "- exported_for: #{user.email_address}",
      "- mode: #{mode}"
    ]

    lines << "- description: #{single_line(project.description)}" if project.description.present?
    lines.join("\n")
  end

  def documents_section
    return "## Documents\n\nNo readable documents." if readable_documents.empty?

    [
      "## Documents",
      readable_documents.map { document_section(_1) }.join("\n\n")
    ].join("\n\n")
  end

  def readable_documents
    @readable_documents ||= base_documents
      .includes(:latest_version, :document_tags, :document_keywords)
      .select { _1.viewable_by?(user) }
      .sort_by { [_1.title.to_s, _1.id] }
  end

  def base_documents
    scope || project.documents
  end

  def document_section(document)
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

  def single_line(value)
    value.to_s.unicode_normalize(:nfkc).squish
  end
end
