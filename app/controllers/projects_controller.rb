class ProjectsController < BaseController
  def index
    @projects = Project.accessible_to(current_user).order(:code)
  end

  def show
    @project = Project.find(params[:id])
    require_project_access!(@project)
  end
end
