class DocumentVersionPolicy < ApplicationPolicy
  def show?
    record.viewable_by?(user)
  end

  def download?
    return false unless user&.active?
    return true if user.internal?

    record.document.downloadable_by?(user)
  end

  def manage?
    user.present? && user.internal?
  end

  class Scope < Scope
    def resolve
      scope.select { _1.viewable_by?(user) }
    end
  end
end
