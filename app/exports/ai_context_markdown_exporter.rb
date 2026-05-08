class AiContextMarkdownExporter
  MODES = %i[compact full].freeze

  def initialize(project:, viewer:, mode: :compact, scope: nil)
    @project = project
    @viewer = viewer
    @mode = mode.to_sym
    @scope = scope
  end

  def call
    raise ArgumentError, "unsupported mode: #{mode}" unless MODES.include?(mode)

    [
      project_section,
      "",
      documents_section
    ].join("\n").strip + "\n"
  end

  private

  attr_reader :project, :viewer, :mode, :scope

  def project_section
    [
      "# Project: #{project.name}",
      "",
      "- code: #{project.code}",
      "- export_mode: #{mode}",
      "- viewer: #{viewer.email_address}",
      "- document_count: #{documents.size}"
    ].join("\n")
  end

  def documents_section
    return "## Documents\n\nNo exportable documents." if documents.empty?

    [
      "## Documents",
      "",
      *documents.map { document_section(_1) }
    ].join("\n\n")
  end

  def document_section(document)
    version = document.latest_version
    lines = [
      "### #{document.title}",
      "",
      "- public_id: #{document.public_id}",
      "- slug: #{document.slug}",
      "- category: #{document.category}",
      "- document_kind: #{document.document_kind}",
      "- visibility_policy: #{document.visibility_policy}",
      "- version: #{version&.version_label || '-'}",
      "- source_path: #{version&.source_relative_path || '-'}"
    ]

    if full?
      lines += ["", body_for(version)]
    else
      lines << "- summary: #{summary_for(version)}"
    end

    lines.join("\n")
  end

  def documents
    @documents ||= (scope || project.documents)
      .includes(:project, :latest_version)
      .select { _1.visible_in_portal_for?(viewer) }
      .sort_by { [_1.title.to_s, _1.id] }
  end

  def full?
    mode == :full
  end

  def body_for(version)
    text = version&.search_body_text.to_s.strip
    text.presence || "_No body text available._"
  end

  def summary_for(version)
    text = version&.search_body_text.to_s.squish
    return "-" if text.blank?

    text.truncate(160)
  end
end
