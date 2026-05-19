class DocumentVersionRollbacksController < BaseController
  def create
    version = DocumentVersion.includes(:document).find_by!(public_id: params.require(:document_version_public_id))
    require_document_version_view_access!(version)
    raise ApplicationError::Forbidden unless current_user.internal?

    document = version.document
    project = document.project
    previous_version = DocumentVersionRollback.new(version: version, actor: current_user).call

    if previous_version
      redirect_to document_version_path(previous_version), notice: "直前の版へロールバックしました。"
    else
      redirect_to project_documents_path(project), notice: "アップロードした文書を取り消し、文書をアーカイブしました。"
    end
  rescue ApplicationError::BadRequest => e
    redirect_to document_version_path(params[:document_version_public_id]), alert: e.message
  end
end
