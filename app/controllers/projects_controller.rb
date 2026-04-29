class ProjectsController < BaseController
  def index
    @projects =
      if current_user.internal?
        Project.order(:code)
      else
        current_user.projects.distinct.order(:code)
      end
  end

  def show
    @project = Project.find(params[:id])
    authorize @project
  end
end
