module ProjectAccess
  extend ActiveSupport::Concern

  included do
    scope :accessible_to, lambda { |user|
      return none unless user&.active?
      return all if user.internal?

      left_outer_joins(:company)
        .where(projects: { active: true })
        .where("companies.id IS NULL OR companies.active = ?", true)
        .joins(:project_memberships)
        .where(project_memberships: { user_id: user.id })
        .distinct
    }

    scope :with_portal_visible_documents_for, lambda { |user|
      where(id: Document.portal_visible_to(user).select(:project_id))
    }

    scope :without_documents, lambda {
      left_outer_joins(:documents).where(documents: { id: nil })
    }

    scope :without_documents_or_with_portal_visible_documents_for, lambda { |user|
      without_documents
        .or(left_outer_joins(:documents).where(id: Document.portal_visible_to(user).select(:project_id)))
        .distinct
    }
  end

  def viewable_by?(user)
    return false unless user&.active?
    return true if user.internal?
    return false unless active?
    return false if company && !company.active?

    project_memberships.exists?(user_id: user.id)
  end
end
