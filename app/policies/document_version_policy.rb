class DocumentVersionPolicy < ApplicationPolicy
  def show?
    return false unless user&.active?
    return true if user.internal?

    record.published? && record.document.external_viewable_by?(user)
  end

  def manage?
    user.present? && user.internal?
  end

  class Scope < Scope
    def resolve
      base = user.internal? ? scope.all : scope.where(status: :published)
      base.select { |version| user.internal? || version.document.external_viewable_by?(user) }
    end
  end
end
