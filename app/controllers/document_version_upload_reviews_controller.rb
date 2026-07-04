class DocumentVersionUploadReviewsController < BaseController
  READ_ONLY_MAINTENANCE_MESSAGE = "メンテナンス中のため、アップロード候補の反映・破棄は実行できません。版詳細は閲覧できます。".freeze

  def create
    version = DocumentVersion.includes(:document).find_by!(public_id: params.require(:document_version_public_id))
    require_document_version_view_access!(version)
    raise ApplicationError::Forbidden unless current_user.internal?

    if read_only_maintenance?
      redirect_to document_version_path(version), alert: READ_ONLY_MAINTENANCE_MESSAGE
      return
    end

    review = ManualDocumentUploadReview.new(version: version, actor: current_user)
    case params.require(:decision)
    when "approve"
      review.approve!
      redirect_to project_document_path(version.document.project, version.document, version_id: version.public_id), notice: "アップロード内容を反映しました。誤りがあればすぐ取り消せます。", flash: { approved_upload_version_public_id: version.public_id }
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

  private

  def read_only_maintenance?
    ActiveModel::Type::Boolean.new.cast(ENV["READ_ONLY_MAINTENANCE"])
  end
end