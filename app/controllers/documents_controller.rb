class DocumentsController < BaseController
  def index
    @project = Project.find(params[:project_id])
    require_project_access!(@project)
    @documents = @project.documents.accessible_to(current_user).sort_by(&:title)
  end

  def show
    @project = Project.find(params[:project_id])
    require_project_access!(@project)
    @document = @project.documents.find(params[:id])
    require_document_access!(@document)

    @versions = @document.document_versions.select { _1.viewable_by?(current_user) }.sort_by(&:created_at).reverse
    @tree_projects = Project.accessible_to(current_user).includes(:documents).order(:code)
  end
end
