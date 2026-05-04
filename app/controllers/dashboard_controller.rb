class DashboardController < BaseController
  def show
    @projects = Project.accessible_to(current_user).order(:code).limit(10)
    @favorite_bookmarks = bookmark_scope.favorite.limit(10)
    @read_later_bookmarks = bookmark_scope.read_later.limit(10)
    @recent_documents = RecentDocumentsQuery.new(user: current_user, limit: 10).call
    @recently_updated_documents = recently_updated_documents
  end

  private

  def bookmark_scope
    current_user.document_bookmarks
      .includes(document: [:project, :latest_version])
      .readable_by(current_user)
      .order(created_at: :desc)
  end

  def recently_updated_documents
    Document.accessible_to(current_user)
      .includes(:project, :latest_version)
      .order(updated_at: :desc)
      .limit(10)
  end
end
