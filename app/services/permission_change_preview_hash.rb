class PermissionChangePreviewHash
  def initialize(project:, viewers:, grant_document_ids: [], revoke_document_ids: [], grant_project_membership: false, revoke_project_membership: false, scope: nil)
    @project = project
    @viewers = Array(viewers)
    @grant_document_ids = grant_document_ids.map(&:to_i)
    @revoke_document_ids = revoke_document_ids.map(&:to_i)
    @grant_project_membership = grant_project_membership
    @revoke_project_membership = revoke_project_membership
    @scope = scope
  end

  def call
    {
      project: project_hash,
      summary: summary_hash,
      viewers: viewer_hashes
    }
  end

  private

  attr_reader :project, :viewers, :grant_document_ids, :revoke_document_ids, :grant_project_membership, :revoke_project_membership, :scope

  def project_hash
    {
      public_id: project.public_id,
      code: project.code,
      name: project.name
    }
  end

  def summary_hash
    {
      total_viewers: viewer_hashes.size,
      changed_viewers: viewer_hashes.count { _1[:changed] },
      gained_documents: viewer_hashes.flat_map { _1[:gained_documents] }.uniq { _1[:public_id] }.size,
      lost_documents: viewer_hashes.flat_map { _1[:lost_documents] }.uniq { _1[:public_id] }.size
    }
  end

  def viewer_hashes
    @viewer_hashes ||= viewers.map { viewer_hash(_1) }
  end

  def viewer_hash(viewer)
    before_documents = visible_documents_for(viewer)
    after_documents = simulated_visible_documents_for(viewer, before_documents)
    gained = after_documents - before_documents
    lost = before_documents - after_documents

    {
      public_id: viewer.public_id,
      email_address: viewer.email_address,
      user_type: viewer.user_type,
      company_id: viewer.company&.public_id,
      changed: gained.any? || lost.any?,
      before_visible_count: before_documents.size,
      after_visible_count: after_documents.size,
      gained_documents: gained.map { document_hash(_1) },
      lost_documents: lost.map { document_hash(_1) },
      unchanged_documents: (before_documents & after_documents).map { document_hash(_1) }
    }
  end

  def visible_documents_for(viewer)
    documents.select { _1.viewable_by?(viewer) }
  end

  def simulated_visible_documents_for(viewer, before_documents)
    visible = before_documents.dup
    visible |= documents_for_ids(grant_document_ids)
    visible -= documents_for_ids(revoke_document_ids)
    visible |= documents.reject(&:internal_only?) if grant_project_membership
    visible = [] if revoke_project_membership
    visible.select { project_visible_after_change?(viewer) }
  end

  def project_visible_after_change?(viewer)
    return true if viewer&.internal?
    return false if revoke_project_membership
    return true if grant_project_membership

    project.viewable_by?(viewer)
  end

  def documents
    @documents ||= (scope || project.documents).includes(:project).to_a.sort_by { [_1.title.to_s, _1.id] }
  end

  def documents_for_ids(ids)
    return [] if ids.blank?

    documents.select { ids.include?(_1.id) }
  end

  def document_hash(document)
    {
      public_id: document.public_id,
      title: document.title,
      slug: document.slug,
      visibility_policy: document.visibility_policy
    }
  end
end
