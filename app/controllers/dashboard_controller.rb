class DashboardController < BaseController
  OPEN_QA_HANDOFF_LIMIT = 5

  def show
    @projects = accessible_projects.limit(10)
    @favorite_bookmarks = bookmark_scope.favorite.limit(8)
    @read_later_bookmarks = bookmark_scope.read_later.limit(8)
    @recent_documents = RecentDocumentsQuery.new(user: current_user, limit: 10).call
    @recently_updated_documents = recently_updated_documents
    @pending_access_requests = pending_access_requests
    @open_question_handoff_threads = open_question_handoff_threads
    @dashboard_stats = {
      project_count: accessible_projects.count,
      document_count: Document.accessible_to(current_user).count,
      bookmark_count: current_user.document_bookmarks.count,
      pending_access_request_count: current_user.access_requests.pending.count,
      pending_approval_count: current_user.internal? ? current_user.approved_document_approval_requests.pending.count : 0
    }
  end

  private

  def accessible_projects
    @accessible_projects ||= Project.accessible_to(current_user).order(:code)
  end

  def bookmark_scope
    current_user.document_bookmarks
      .includes(document: [:project, :latest_version])
      .readable_by(current_user)
      .order(created_at: :desc)
  end

  def recently_updated_documents
    Document.accessible_to(current_user)
      .includes(:project, :latest_version)
      .recommended_first
      .order(updated_at: :desc)
      .limit(10)
  end

  def pending_access_requests
    current_user.access_requests
      .pending
      .recent_first
      .includes(:requestable)
      .limit(3)
  end

  def open_question_handoff_threads
    return DocumentReviewComment.none unless current_user.internal?

    DocumentReviewComment
      .joins(:document)
      .merge(Document.accessible_to(current_user))
      .where(
        comment_type: :question,
        internal_only: false,
        status: :open,
        parent_id: nil
      )
      .includes(:author, :document_version, document: :project, replies: [:author])
      .order(updated_at: :desc, id: :desc)
      .limit(OPEN_QA_HANDOFF_LIMIT)
  end
end
