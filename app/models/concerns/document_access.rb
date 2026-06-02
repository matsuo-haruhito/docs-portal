module DocumentAccess
  extend ActiveSupport::Concern

  included do
    scope :accessible_to, lambda { |user|
      return none unless user&.active?
      return active_only if user.internal?

      active_only
        .left_outer_joins(:document_permissions)
        .joins(:project)
        .merge(Project.accessible_to(user))
        .where.not(visibility_policy: Document.visibility_policies[:internal_only])
        .where(
          "documents.visibility_policy = :public_with_login OR " \
          "document_permissions.user_id = :user_id OR " \
          "(document_permissions.company_id = :company_id AND document_permissions.user_id IS NULL)",
          public_with_login: Document.visibility_policies[:public_with_login],
          user_id: user.id,
          company_id: user.company_id
        )
        .distinct
    }

    scope :visible_in_portal_for, lambda { |user, at = Time.current|
      return none unless user&.active?
      return active_only if user.internal?

      active_version_sql = <<~SQL.squish
        document_versions.status = :published_status
        AND (document_versions.published_from IS NULL OR document_versions.published_from <= :at)
        AND (document_versions.published_until IS NULL OR document_versions.published_until >= :at)
      SQL

      accessible_to(user)
        .left_outer_joins(:document_versions)
        .where(
          "document_versions.id IS NULL OR (#{active_version_sql})",
          published_status: DocumentVersion.statuses[:published],
          at:
        )
        .distinct
    }
  end

  def viewable_by?(user)
    return false unless user&.active?
    return false if archived?
    return true if user.internal?
    return false unless project.viewable_by?(user)
    return false if internal_only?
    return true if public_with_login?

    external_permission_scope_for(user).exists?
  end

  def downloadable_by?(user)
    return false unless user&.active?
    return false if archived?
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