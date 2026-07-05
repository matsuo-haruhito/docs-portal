class DocumentReviewCommentsController < BaseController
  COMMENT_CONTEXT_TABS = %w[all qa review unresolved].freeze
  EXTERNAL_COMMENT_CONTEXT_TABS = %w[all qa unresolved].freeze
  READ_ONLY_MAINTENANCE_ENV = "READ_ONLY_MAINTENANCE"

  before_action :set_targets

  def create
    if read_only_maintenance_mode?
      redirect_to redirect_path, alert: maintenance_document_review_comment_message
      return
    end

    comment = @document.document_review_comments.build(comment_params)
    comment.document_version ||= @version if params[:document_version_public_id].present?
    comment.document = @document
    comment.author = current_user
    apply_visibility_rules!(comment)

    if comment.save
      redirect_to redirect_path, notice: success_message_for(comment)
    else
      redirect_to redirect_path, alert: comment.errors.full_messages.join(", ")
    end
  end

  def update
    raise ApplicationError::Forbidden unless current_user&.admin?

    if read_only_maintenance_mode?
      redirect_to redirect_path, alert: maintenance_document_review_comment_message
      return
    end

    comment = @document.document_review_comments.find_by!(public_id: params[:public_id])

    case params[:decision]
    when "resolve"
      comment.resolve!(current_user)
      notice = decision_success_message_for(comment, :resolve)
    when "reject"
      comment.update!(status: :rejected, resolved_by: nil, resolved_at: nil)
      notice = decision_success_message_for(comment, :reject)
    else
      raise ApplicationError::BadRequest, "unsupported decision"
    end

    redirect_to redirect_path, notice:
  end

  private

  def set_targets
    if params[:document_version_public_id].present?
      @version = DocumentVersion.find_by!(public_id: params[:document_version_public_id])
      require_document_version_view_access!(@version)
      @document = @version.document
      @project = @document.project
    else
      @project = Project.find_by!(code: params[:project_code])
      require_project_access!(@project)
      @document = @project.documents.find_by!(slug: params[:document_slug] || params[:slug])
      require_document_access!(@document)
      @version = @document.latest_version if @document.latest_version&.viewable_by?(current_user)
    end
  end

  def redirect_path
    path = @version.present? && params[:document_version_public_id].present? ? document_version_path(@version) : project_document_path(@project, @document.slug)
    context = safe_comment_redirect_context

    context.present? ? "#{path}?#{context.to_query}" : path
  end

  def safe_comment_redirect_context
    context = {}
    tab = params[:comment_tab].to_s.strip
    query = params[:comment_q].to_s.strip
    author_public_id = safe_comment_author_public_id
    allowed_tabs = current_user&.internal? ? COMMENT_CONTEXT_TABS : EXTERNAL_COMMENT_CONTEXT_TABS

    context[:comment_tab] = tab if allowed_tabs.include?(tab)
    if query.present?
      context[:comment_q] = query.first(DocumentCommentWorkspaceSearch::COMMENT_QUERY_MAX_LENGTH)
    end
    context[:comment_author_id] = author_public_id if author_public_id.present?

    context
  end

  def safe_comment_author_public_id
    author_public_id = params[:comment_author_id].to_s.strip
    return if author_public_id.blank?

    visible_author_exists = @document
      .document_review_comments
      .visible_to(current_user)
      .joins(:author)
      .where(users: { public_id: author_public_id })
      .exists?
    author_public_id if visible_author_exists
  end

  def apply_visibility_rules!(comment)
    if comment.parent.present? && !comment.parent.internal_only?
      comment.internal_only = false
      comment.comment_type = "question"
      return
    end

    if current_user&.internal?
      comment.internal_only = true if comment.internal_only.nil?
      return
    end

    raise ApplicationError::Forbidden unless comment.comment_type == "question"

    comment.internal_only = false
    comment.comment_type = "question"
  end

  def success_message_for(comment)
    return "Q&A を投稿しました。" if comment.public_thread?

    "レビューコメントを追加しました。"
  end

  def decision_success_message_for(comment, decision)
    if comment.public_thread?
      return "Q&A を回答済みにしました。" if decision == :resolve
      return "Q&A をクローズしました。" if decision == :reject
    end

    return "レビューコメントを解決済みにしました。" if decision == :resolve

    "レビューコメントを却下扱いにしました。"
  end

  def read_only_maintenance_mode?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(READ_ONLY_MAINTENANCE_ENV, nil))
  end

  def maintenance_document_review_comment_message
    "メンテナンス中のため文書コメント・Q&Aの投稿や状態更新は停止しています。閲覧、検索、未解決handoffは継続できます。"
  end

  def comment_params
    params.require(:document_review_comment).permit(
      :comment_type,
      :body,
      :document_version_id,
      :internal_only,
      :parent_id,
      :text_line_start,
      :text_line_end,
      :text_anchor_type,
      :text_anchor_path,
      :text_anchor_label,
      :source_path
    )
  end
end
