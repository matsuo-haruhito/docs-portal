class PermissionChangeDryRun
  Change = Data.define(:viewer, :before_documents, :after_documents) do
    def gained_documents
      after_documents - before_documents
    end

    def lost_documents
      before_documents - after_documents
    end

    def unchanged_documents
      before_documents & after_documents
    end

    def changed?
      gained_documents.any? || lost_documents.any?
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
    after_documents = simulated_visible_documents_for(viewer, before_documents)

    Change.new(viewer:, before_documents:, after_documents:)
  end

  def visible_documents_for(viewer)
    documents.select { _1.viewable_by?(viewer) }
  end

  def simulated_visible_documents_for(viewer, before_documents)
    visible = before_documents.dup

    visible |= documents_for_ids(grant.fetch(:document_ids, []))
    visible -= documents_for_ids(revoke.fetch(:document_ids, []))

    if grant.fetch(:project_membership, false)
      visible |= documents.reject(&:internal_only?)
    end

    if revoke.fetch(:project_membership, false)
      visible = []
    end

    visible.select { simulated_project_visible?(viewer) || grant.fetch(:project_membership, false) }
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

  def documents_for_ids(ids)
    return [] if ids.blank?

    documents.select { ids.map(&:to_i).include?(_1.id) }
  end
end
