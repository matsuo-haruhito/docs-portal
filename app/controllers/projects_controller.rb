class ProjectsController < BaseController
  def index
    @projects = Project.accessible_to(current_user)
      .includes(documents: :latest_version)
      .order(:code)
    @projects = @projects.select { visible_project_for_portal?(_1) } unless current_user.internal?
  end

  def show
    @project = Project.find_by!(code: params[:code])
    require_project_access!(@project)
    @documents = @project.documents.accessible_to(current_user).includes(:latest_version).recommended_first
    @documents = @documents.select { _1.visible_in_portal_for?(current_user) } unless current_user.internal?
    @important_documents = @documents.select { %w[critical important].include?(_1.importance_level) }
    @tree_projects = Project.accessible_to(current_user).includes(documents: :latest_version).order(:code)
  end

  private

  def visible_project_for_portal?(project)
    return true if project.documents.empty?

    project.documents.any? { _1.visible_in_portal_for?(current_user) }
  end
end
