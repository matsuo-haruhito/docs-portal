class AiContextHashExporter
  MODES = %i[compact full].freeze

  def initialize(project:, viewer:, mode: :compact, scope: nil)
    @project = project
    @viewer = viewer
    @mode = mode.to_sym
    @scope = scope
  end

  def call
    raise ArgumentError, "unsupported mode: #{mode}" unless MODES.include?(mode)

    {
      project: project_hash,
      viewer: viewer_hash,
      mode:,
      summary: summary_hash,
      documents: documents.map { document_hash(_1) }
    }
  end

  private

  attr_reader :project, :viewer, :mode, :scope

  def documents
    @documents ||= (scope || project.documents)
      .includes(:project, :latest_version)
      .select { _1.viewable_by?(viewer) }
      .sort_by { [_1.title.to_s, _1.id] }
  end

  def project_hash
    {
      public_id: project.public_id,
      code: project.code,
      name: project.name
    }
  end

  def viewer_hash
    {
      public_id: viewer.public_id,
      email_address: viewer.email_address,
      user_type: viewer.user_type,
      company_id: viewer.company&.public_id
    }
  end

  def summary_hash
    {
      document_count: documents.size,
      mode:,
      exported_public_ids: documents.map(&:public_id)
    }
  end

  def document_hash(document)
    version = document.latest_version
    base = {
      public_id: document.public_id,
      title: document.title,
      slug: document.slug,
      category: document.category,
      document_kind: document.document_kind,
      visibility_policy: document.visibility_policy,
      version: version_hash(version)
    }

    full? ? base.merge(body_text: body_for(version)) : base.merge(summary: summary_for(version))
  end

  def version_hash(version)
    return nil if version.blank?

    {
      public_id: version.public_id,
      version_label: version.version_label,
      status: version.status,
      source_relative_path: version.source_relative_path
    }
  end

  def full?
    mode == :full
  end

  def body_for(version)
    version&.search_body_text.to_s.strip.presence
  end

  def summary_for(version)
    text = version&.search_body_text.to_s.squish
    return nil if text.blank?

    text.truncate(160)
  end
end
