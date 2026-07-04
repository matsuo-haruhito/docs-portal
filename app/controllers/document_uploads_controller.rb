class DocumentUploadsController < BaseController
  READ_ONLY_MAINTENANCE_MESSAGE = "メンテナンス中のため、手動アップロードは実行できません。文書一覧と既存版は閲覧できます。".freeze

  def create
    @project = Project.find_by!(code: params.require(:project_code))
    require_project_access!(@project)
    raise ApplicationError::Forbidden unless current_user.internal?

    if read_only_maintenance?
      redirect_to project_documents_path(@project), alert: READ_ONLY_MAINTENANCE_MESSAGE
      return
    end

    result = ManualDocumentUpload.new(
      project: @project,
      actor: current_user,
      uploaded_file: params.require(:file),
      source_path: params[:source_path],
      target_document: target_document(@project)
    ).call

    redirect_to document_version_path(result.version, upload_review: "1"), notice: "文書をアップロードしました。差異を確認してOK/NGを選択してください。", flash: { upload_review_version_public_id: result.version.public_id }
  rescue ActionController::ParameterMissing, ApplicationError::BadRequest => e
    redirect_to document_upload_error_redirect_path, alert: e.message
  end

  private

  def read_only_maintenance?
    ActiveModel::Type::Boolean.new.cast(ENV["READ_ONLY_MAINTENANCE"])
  end

  def document_upload_error_redirect_path
    return project_documents_path(@project) if @project.present?

    project_code = params[:project_code].presence
    return project_documents_path(project_code) if project_code

    projects_path
  end

  def target_document(project)
    public_id = params[:target_document_id].to_s
    return if public_id.blank?

    project.documents.find_by!(public_id: public_id)
  end
end
