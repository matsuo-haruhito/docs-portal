class DocumentFilePolicy < ApplicationPolicy
  def show?
    return false unless user&.active?
    return true if user.internal?

    record.document_version.published? && record.document_version.document.external_downloadable_by?(user)
  end
end
