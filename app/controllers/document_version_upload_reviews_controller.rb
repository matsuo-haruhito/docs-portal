class DocumentVersionUploadReviewsController < BaseController
  def create
    version = DocumentVersion.includes(:document).find_by!(public_id: params.require(:document_version_public_id))
    require_document_version_view_access!(version)
    raise ApplicationError::Forbidden unless current_user.internal?

    review = ManualDocumentUploadReview.new(version: version, actor: current_user)
    case params.require(:decision)
    when "approve"
      review.approve!
      redirect_to project_document_path(version.document.project, version.document, version_id: version.public_id), notice: "アップロード内容を反映しました。"
    when "reject"
      document = version.document
      project = document.project
      review.reject!
      redirect_to project_documents_path(project, q: version.source_directory), notice: "アップロード候補を破棄しました。"
    else
      raise ApplicationError::BadRequest, "decision is invalid"
    end
  rescue ActionController::ParameterMissing, ApplicationError::BadRequest => e
    fallback_public_id = params[:document_version_public_id] || params[:document_version_id]
    redirect_to document_version_path(fallback_public_id), alert: e.message
  end
end
