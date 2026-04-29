class ProjectPolicy < ApplicationPolicy
  def show?
    return false unless user&.active?
    return true if user.internal?

    record.project_memberships.exists?(user_id: user.id)
  end

  class Scope < Scope
    def resolve
      return scope.all if user.internal?

      scope.joins(:project_memberships).where(project_memberships: { user_id: user.id }).distinct
    end
  end
end
