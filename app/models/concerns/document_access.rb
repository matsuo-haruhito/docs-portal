module DocumentAccess
  extend ActiveSupport::Concern

  included do
    scope :accessible_to, lambda { |user|
      return none unless user&.active?
      return all if user.internal?

      joins(:project, :document_permissions)
        .merge(Project.accessible_to(user))
        .where.not(visibility_policy: Document.visibility_policies[:internal_only])
        .where(
          "document_permissions.user_id = :user_id OR " \
          "(document_permissions.company_id = :company_id AND document_permissions.user_id IS NULL)",
          user_id: user.id,
          company_id: user.company_id
        )
        .distinct
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
