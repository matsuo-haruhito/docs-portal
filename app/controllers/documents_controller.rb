class DocumentsController < BaseController
  def index
    @project = Project.find_by!(code: params[:project_code])
    require_project_access!(@project)
    @documents = @project.documents.accessible_to(current_user).sort_by(&:title)
    @tree_projects = Project.accessible_to(current_user).includes(:documents).order(:code)
  end

  def show
    @project = Project.find_by!(code: params[:project_code])
    require_project_access!(@project)
    @document = @project.documents.find_by!(slug: params[:slug])
    require_document_access!(@document)

    @versions = @document.document_versions.select { _1.viewable_by?(current_user) }.sort_by(&:created_at).reverse
    @tree_projects = Project.accessible_to(current_user).includes(:documents).order(:code)
  end
end
