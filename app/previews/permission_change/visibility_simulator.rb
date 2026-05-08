module PermissionChange
  class VisibilitySimulator
    def initialize(project:, viewer:, grant:, revoke:, scope:)
      @project = project
      @viewer = viewer
      @grant = grant || {}
      @revoke = revoke || {}
      @scope = scope
    end

    def visible_documents
      documents.select { _1.viewable_by?(viewer) }
    end

    def downloadable_documents
      documents.select { _1.downloadable_by?(viewer) }
    end

    def simulated_visible_documents
      return documents if viewer&.internal?
      return [] unless simulated_project_visible?

      documents.select { visible_after_change?(_1) }
    end

    def simulated_downloadable_documents(before_downloadable_documents:, after_documents:)
      return after_documents if viewer&.internal?
      return [] if revoke.fetch(:project_membership, false)

      after_documents.select { downloadable_after_change?(_1, before_downloadable_documents) }
    end

    private

    attr_reader :project, :viewer, :grant, :revoke, :scope

    def simulated_project_visible?
      return true if viewer&.internal?
      return false if revoke.fetch(:project_membership, false)
      return true if grant.fetch(:project_membership, false)

      project.viewable_by?(viewer)
    end

    def documents
      @documents ||= (scope || project.documents).includes(:project).to_a
    end

    def visible_after_change?(document)
      return false if document.internal_only?
      return true if document.public_with_login?

      current_document_permission?(document) ||
        granted_document_ids.include?(document.id) ||
        granted_download_document_ids.include?(document.id)
    end

    def downloadable_after_change?(document, before_downloadable_documents)
      return false unless visible_after_change?(document)
      return false if revoke.fetch(:project_membership, false)
      return false if revoked_download_document_ids.include?(document.id)
      return true if granted_download_document_ids.include?(document.id)

      before_downloadable_documents.include?(document)
    end

    def current_document_permission?(document)
      return false if viewer.blank? || viewer.company_id.blank?
      return false if revoked_document_ids.include?(document.id)

      document.document_permissions.where(user_id: viewer.id)
        .or(document.document_permissions.where(company_id: viewer.company_id, user_id: nil))
        .exists?
    end

    def granted_document_ids
      @granted_document_ids ||= Array(grant[:document_ids]).map(&:to_i)
    end

    def granted_download_document_ids
      @granted_download_document_ids ||= Array(grant[:download_document_ids]).map(&:to_i)
    end

    def revoked_document_ids
      @revoked_document_ids ||= Array(revoke[:document_ids]).map(&:to_i)
    end

    def revoked_download_document_ids
      @revoked_download_document_ids ||= Array(revoke[:download_document_ids]).map(&:to_i)
    end
  end
end
