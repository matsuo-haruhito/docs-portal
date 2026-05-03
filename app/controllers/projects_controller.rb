class ProjectsController < BaseController
  def index
    @projects = Project.accessible_to(current_user)
      .includes(documents: :latest_version)
      .order(:code)
  end

  def show
    @project = Project.find_by!(code: params[:code])
    require_project_access!(@project)
    @documents = @project.documents.accessible_to(current_user).includes(:latest_version).order(:title)
    @tree_projects = Project.accessible_to(current_user).includes(documents: :latest_version).order(:code)
  end
end
