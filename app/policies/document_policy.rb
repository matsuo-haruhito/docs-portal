class DocumentPolicy < ApplicationPolicy
  def index?
    user.present? && user.active?
  end

  def show?
    return false unless user&.active?
    return true if user.internal?

    record.external_viewable_by?(user)
  end

  def manage?
    user.present? && user.internal?
  end

  alias create? manage?
  alias update? manage?
  alias destroy? manage?

  class Scope < Scope
    def resolve
      return scope.all if user.internal?

      scope.select { |doc| doc.external_viewable_by?(user) }
    end
  end
end
