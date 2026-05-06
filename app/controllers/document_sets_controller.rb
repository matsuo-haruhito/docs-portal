class DocumentSetsController < BaseController
  before_action :set_project

  def index
    @document_sets = @project.document_sets.ordered.select { _1.viewable_by?(current_user) }
  end

  def show
    @document_set = @project.document_sets.find_by!(public_id: params[:public_id])
    raise ApplicationError::Forbidden unless @document_set.viewable_by?(current_user)

    @items = @document_set.visible_items_for(current_user)
    @tree_projects = Project.accessible_to(current_user).includes(documents: :latest_version).order(:code)
  end

  private

  def set_project
    @project = Project.find_by!(code: params[:project_code] || params[:code])
    require_project_access!(@project)
  end
end
