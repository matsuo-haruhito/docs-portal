class DocumentVersionQualityChecksController < BaseController
  before_action :set_version
  before_action :require_internal_viewer!

  def show
    @result = DocumentVersionQualityChecker.new(@version).call
    @quality_check_hash = DocumentVersionQualityCheckHash.new(@result).call

    respond_to do |format|
      format.html
      format.json { render json: @quality_check_hash }
      format.md do
        render plain: DocumentVersionQualityCheckMarkdown.new(@result).call,
          content_type: "text/markdown; charset=utf-8"
      end
    end
  end

  private

  def set_version
    @version = DocumentVersion.find_by!(public_id: params[:document_version_public_id] || params[:public_id])
    require_document_version_view_access!(@version)
    @document = @version.document
    @project = @document.project
    @tree_projects = Project.accessible_to(current_user).includes(documents: :latest_version).order(:code)
  end

  def require_internal_viewer!
    raise ApplicationError::Forbidden unless current_user&.internal?
  end
end
