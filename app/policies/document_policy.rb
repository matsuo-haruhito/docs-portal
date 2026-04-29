class DocumentPolicy < ApplicationPolicy
  def index?
    user.present? && user.active?
  end

  def show?
    record.viewable_by?(user)
  end

  def manage?
    user.present? && user.internal?
  end

  alias create? manage?
  alias update? manage?
  alias destroy? manage?

  class Scope < Scope
    def resolve
      scope.accessible_to(user)
    end
  end
end
