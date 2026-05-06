class DocumentReviewCommentsController < BaseController
  before_action :set_targets

  def create
    comment = @document.document_review_comments.build(comment_params)
    comment.document_version ||= @version
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

    comment = @document.document_review_comments.find_by!(public_id: params[:public_id])

    case params[:decision]
    when "resolve"
      comment.resolve!(current_user)
      notice = "レビューコメントを解決済みにしました。"
    when "reject"
      comment.update!(status: :rejected, resolved_by: nil, resolved_at: nil)
      notice = "レビューコメントを却下扱いにしました。"
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
    @version.present? && params[:document_version_public_id].present? ? document_version_path(@version) : project_document_path(@project, @document.slug)
  end

  def apply_visibility_rules!(comment)
    if current_user&.internal?
      comment.internal_only = true if comment.internal_only.nil?
      return
    end

    raise ApplicationError::Forbidden unless comment.comment_type == "question" || comment.parent_id.present?

    comment.internal_only = false
    comment.comment_type = "question" if comment.parent_id.blank?

    if comment.parent.present?
      raise ApplicationError::Forbidden if comment.parent.internal_only?
      raise ApplicationError::Forbidden unless comment.parent.comment_type == "question" || comment.parent.parent_id.present?
    end
  end

  def success_message_for(comment)
    return "Q&A を投稿しました。" if comment.public_thread?

    "レビューコメントを追加しました。"
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
