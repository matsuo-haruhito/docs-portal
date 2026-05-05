class DocumentCatalogsController < BaseController
  def index
    @project = Project.find_by!(code: params[:project_code])
    require_project_access!(@project)
    @catalogs = @project.document_catalogs.ordered.select { _1.viewable_by?(current_user) }
    @tree_projects = Project.accessible_to(current_user).includes(documents: :latest_version).order(:code)
  end

  def show
    @project = Project.find_by!(code: params[:project_code])
    require_project_access!(@project)
    @catalog = @project.document_catalogs.find_by!(public_id: params[:public_id])
    raise ApplicationError::Forbidden unless @catalog.viewable_by?(current_user)

    @catalog_hash = DocumentCatalogHash.new(document_catalog: @catalog, viewer: current_user).call
    @tree_projects = Project.accessible_to(current_user).includes(documents: :latest_version).order(:code)
  end
end
