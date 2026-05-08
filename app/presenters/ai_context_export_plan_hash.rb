class AiContextExportPlanHash
  def initialize(project:, viewer:, scope: nil)
    @project = project
    @viewer = viewer
    @scope = scope
  end

  def call
    {
      project: project_hash,
      viewer: viewer_hash,
      summary: summary_hash,
      items: item_hashes
    }
  end

  private

  attr_reader :project, :viewer, :scope

  def documents
    @documents ||= (scope || project.documents)
      .includes(:project, :latest_version)
      .sort_by { [_1.title.to_s, _1.id] }
  end

  def item_hashes
    @item_hashes ||= documents.map { item_hash(_1) }
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
    included = item_hashes.count { _1[:included] }

    {
      total_documents: item_hashes.size,
      included_documents: included,
      excluded_documents: item_hashes.size - included,
      included_public_ids: item_hashes.select { _1[:included] }.map { _1[:document][:public_id] }
    }
  end

  def item_hash(document)
    included = document.viewable_by?(viewer)

    {
      included:,
      reason: included ? "viewable" : "not_viewable",
      document: document_hash(document),
      document_version: document_version_hash(document.latest_version)
    }
  end

  def document_hash(document)
    {
      public_id: document.public_id,
      title: document.title,
      slug: document.slug,
      category: document.category,
      document_kind: document.document_kind,
      visibility_policy: document.visibility_policy
    }
  end

  def document_version_hash(version)
    return nil if version.blank?

    {
      public_id: version.public_id,
      version_label: version.version_label,
      status: version.status,
      source_relative_path: version.source_relative_path
    }
  end
end
