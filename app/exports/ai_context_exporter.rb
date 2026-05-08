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
      AiContext::ProjectSectionBuilder.new(project:, user:, mode:).call,
      documents_section
    ].join("\n\n").strip + "\n"
  end

  private

  attr_reader :project, :user, :mode, :scope

  def documents_section
    return "## Documents\n\nNo readable documents." if readable_documents.empty?

    [
      "## Documents",
      readable_documents.map { document_section_builder.call(_1) }.join("\n\n")
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

  def document_section_builder
    @document_section_builder ||= AiContext::DocumentSectionBuilder.new(mode:)
  end
end
