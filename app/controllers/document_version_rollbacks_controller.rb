class DocumentVersionRollbacksController < BaseController
  READ_ONLY_MAINTENANCE_ENV = "READ_ONLY_MAINTENANCE"

  def create
    version = DocumentVersion.includes(:document).find_by!(public_id: params.require(:document_version_public_id))
    require_document_version_view_access!(version)
    raise ApplicationError::Forbidden unless current_user.internal?

    document = version.document
    project = document.project

    if read_only_maintenance_mode?
      redirect_to document_version_path(version), alert: maintenance_rollback_message
      return
    end

    previous_version = DocumentVersionRollback.new(version: version, actor: current_user).call

    if previous_version
      redirect_to document_version_path(previous_version), notice: "直前の版へロールバックしました。"
    else
      redirect_to project_documents_path(project), notice: "アップロードした文書を取り消し、文書をアーカイブしました。"
    end
  rescue ApplicationError::BadRequest => e
    redirect_to document_version_path(params[:document_version_public_id]), alert: e.message
  end

  private

  def read_only_maintenance_mode?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(READ_ONLY_MAINTENANCE_ENV, nil))
  end

  def maintenance_rollback_message
    "メンテナンス中のため文書版の取り消しは停止しています。版詳細、差分、添付確認は閲覧できます。"
  end
end
