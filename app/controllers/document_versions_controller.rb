class DocumentVersionsController < BaseController
  def show
    @version = DocumentVersion
      .includes(:document_files, document: [:project, :document_tags, :document_keywords])
      .find_by!(public_id: params[:public_id])
    require_document_version_view_access!(@version)

    @document = @version.document
    @project = @document.project
    @versions = @document.document_versions.select { _1.viewable_by?(current_user) }.sort_by(&:created_at).reverse
    @tree_projects = Project.accessible_to(current_user).includes(documents: :latest_version).order(:code)
  end
end
