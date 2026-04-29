module DocumentAccess
  extend ActiveSupport::Concern

  included do
    scope :accessible_to, lambda { |user|
      return none unless user&.active?
      return all if user.internal?

      includes(:document_permissions, :project).select { _1.viewable_by?(user) }
    }
  end

  def viewable_by?(user)
    return false unless user&.active?
    return true if user.internal?
    return false unless project.viewable_by?(user)
    return false if internal_only?

    external_permission_scope_for(user).exists?
  end

  def downloadable_by?(user)
    return false unless user&.active?
    return true if user.internal?
    return false unless project.viewable_by?(user)
    return false if internal_only?

    external_permission_scope_for(user)
      .where(access_level: DocumentPermission.access_levels[:download])
      .exists?
  end

  private

  def external_permission_scope_for(user)
    document_permissions.where(user_id: user.id)
      .or(document_permissions.where(company_id: user.company_id, user_id: nil))
  end
end
