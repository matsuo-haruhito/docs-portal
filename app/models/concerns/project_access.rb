module ProjectAccess
  extend ActiveSupport::Concern

  included do
    scope :accessible_to, lambda { |user|
      return none unless user&.active?
      return all if user.internal?

      joins(:project_memberships).where(project_memberships: { user_id: user.id }).distinct
    }
  end

  def viewable_by?(user)
    return false unless user&.active?
    return true if user.internal?

    project_memberships.exists?(user_id: user.id)
  end
end
