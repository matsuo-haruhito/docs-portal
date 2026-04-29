class DocumentsController < BaseController
  def index
    @project = Project.find(params[:project_id])
    authorize @project, :show?
    @documents = policy_scope(@project.documents).sort_by(&:title)
  end

  def show
    @project = Project.find(params[:project_id])
    authorize @project, :show?
    @document = @project.documents.find(params[:id])
    authorize @document

    @versions = policy_scope(@document.document_versions).sort_by(&:created_at).reverse
    @tree_projects =
      if current_user.internal?
        Project.includes(:documents).order(:code)
      else
        current_user.projects.includes(:documents).distinct.order(:code)
      end
  end
end
