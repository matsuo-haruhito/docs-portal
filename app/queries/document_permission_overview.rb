class DocumentPermissionOverview
  Row = Data.define(:document, :company_permissions, :user_permissions, :download_allowed_count, :view_allowed_count)

  def initialize(scope = Document.all)
    @scope = scope
  end

  def rows
    documents.map do |document|
      permissions = permissions_by_document_id.fetch(document.id, [])
      Row.new(
        document:,
        company_permissions: permissions.select { _1.company_id.present? && _1.user_id.blank? },
        user_permissions: permissions.select { _1.user_id.present? },
        download_allowed_count: permissions.count(&:download?),
        view_allowed_count: permissions.count(&:view?)
      )
    end
  end

  private

  attr_reader :scope

  def documents
    @documents ||= scope.includes(:project).order(:title).to_a
  end

  def permissions_by_document_id
    @permissions_by_document_id ||= DocumentPermission
      .includes(:company, :user)
      .where(document_id: documents.map(&:id))
      .order(:document_id, :access_level, :company_id, :user_id)
      .group_by(&:document_id)
  end
end
