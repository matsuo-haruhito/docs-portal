class DocumentUploadsController < BaseController
  def create
    project = Project.find_by!(code: params.require(:project_code))
    require_project_access!(project)
    raise ApplicationError::Forbidden unless current_user.internal?

    result = ManualDocumentUpload.new(
      project: project,
      actor: current_user,
      uploaded_file: params.require(:file),
      source_path: params[:source_path],
      target_document: target_document(project)
    ).call

    redirect_to project_documents_path(
      project,
      q: result.source_path,
      upload_source_path: result.version.source_directory,
      uploaded_version_id: result.version.public_id
    ), notice: "文書をアップロードしました。"
  rescue ActionController::ParameterMissing, ApplicationError::BadRequest => e
    redirect_to project_documents_path(params[:project_code]), alert: e.message
  end

  private

  def target_document(project)
    public_id = params[:target_document_id].to_s
    return if public_id.blank?

    project.documents.find_by!(public_id: public_id)
  end
end
