class PermissionChangeDryRun
  Change = Data.define(:viewer, :before_documents, :after_documents, :before_downloadable_documents, :after_downloadable_documents) do
    def gained_documents
      after_documents - before_documents
    end

    def lost_documents
      before_documents - after_documents
    end

    def unchanged_documents
      before_documents & after_documents
    end

    def gained_downloadable_documents
      after_downloadable_documents - before_downloadable_documents
    end

    def lost_downloadable_documents
      before_downloadable_documents - after_downloadable_documents
    end

    def unchanged_downloadable_documents
      before_downloadable_documents & after_downloadable_documents
    end

    def changed?
      gained_documents.any? || lost_documents.any? || gained_downloadable_documents.any? || lost_downloadable_documents.any?
    end
  end

  Result = Data.define(:project, :changes) do
    def changed_viewers
      changes.select(&:changed?)
    end

    def gained_documents
      changes.flat_map(&:gained_documents).uniq
    end

    def lost_documents
      changes.flat_map(&:lost_documents).uniq
    end

    def gained_downloadable_documents
      changes.flat_map(&:gained_downloadable_documents).uniq
    end

    def lost_downloadable_documents
      changes.flat_map(&:lost_downloadable_documents).uniq
    end
  end

  def initialize(project:, viewers:, grant: nil, revoke: nil, scope: nil)
    @project = project
    @viewers = Array(viewers)
    @grant = grant || {}
    @revoke = revoke || {}
    @scope = scope
  end

  def call
    Result.new(
      project:,
      changes: viewers.map { change_for(_1) }
    )
  end

  private

  attr_reader :project, :viewers, :grant, :revoke, :scope

  def change_for(viewer)
    before_documents = visible_documents_for(viewer)
    after_documents = simulated_visible_documents_for(viewer)
    before_downloadable_documents = downloadable_documents_for(viewer)
    after_downloadable_documents = simulated_downloadable_documents_for(
      viewer,
      before_downloadable_documents,
      after_documents
    )

    Change.new(
      viewer:,
      before_documents:,
      after_documents:,
      before_downloadable_documents:,
      after_downloadable_documents:
    )
  end

  def visible_documents_for(viewer)
    documents.select { _1.viewable_by?(viewer) }
  end

  def downloadable_documents_for(viewer)
    documents.select { _1.downloadable_by?(viewer) }
  end

  def simulated_visible_documents_for(viewer)
    return documents if viewer&.internal?
    return [] unless simulated_project_visible?(viewer)

    documents.select { visible_after_change?(viewer, _1) }
  end

  def simulated_downloadable_documents_for(viewer, before_downloadable_documents, after_documents)
    return after_documents if viewer&.internal?
    return [] if revoke.fetch(:project_membership, false)

    after_documents.select { downloadable_after_change?(viewer, _1, before_downloadable_documents) }
  end

  def simulated_project_visible?(viewer)
    return true if viewer&.internal?
    return false if revoke.fetch(:project_membership, false)
    return true if grant.fetch(:project_membership, false)

    project.viewable_by?(viewer)
  end

  def documents
    @documents ||= (scope || project.documents).includes(:project).to_a
  end

  def visible_after_change?(viewer, document)
    return false if document.internal_only?
    return true if document.public_with_login?

    current_document_permission?(viewer, document) ||
      grant.fetch(:document_ids, []).map(&:to_i).include?(document.id) ||
      grant.fetch(:download_document_ids, []).map(&:to_i).include?(document.id)
  end

  def downloadable_after_change?(viewer, document, before_downloadable_documents)
    return false unless visible_after_change?(viewer, document)
    return false if revoke.fetch(:project_membership, false)
    return false if revoke.fetch(:download_document_ids, []).map(&:to_i).include?(document.id)
    return true if grant.fetch(:download_document_ids, []).map(&:to_i).include?(document.id)

    before_downloadable_documents.include?(document)
  end

  def current_document_permission?(viewer, document)
    return false if viewer.blank? || viewer.company_id.blank?
    return false if revoke.fetch(:document_ids, []).map(&:to_i).include?(document.id)

    document.document_permissions.where(user_id: viewer.id)
      .or(document.document_permissions.where(company_id: viewer.company_id, user_id: nil))
      .exists?
  end
end
