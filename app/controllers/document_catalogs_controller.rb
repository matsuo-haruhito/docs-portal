class DocumentCatalogsController < BaseController
  CATALOG_QUERY_MAX_LENGTH = 100

  def index
    @project = Project.find_by!(code: params[:project_code])
    require_project_access!(@project)

    @catalog_query = normalized_catalog_query
    @audience_type_filter = normalized_audience_type_filter
    @visibility_policy_filter = normalized_visibility_policy_filter

    visible_catalogs = @project.document_catalogs.ordered.select { _1.viewable_by?(current_user) }
    @catalogs = filter_catalogs(visible_catalogs)
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

  private

  def normalized_catalog_query
    query = params[:q].to_s.strip.presence
    return if query.blank?

    query[0, CATALOG_QUERY_MAX_LENGTH]
  end

  def normalized_audience_type_filter
    params[:audience_type].presence_in(DocumentCatalog.audience_types.keys)
  end

  def normalized_visibility_policy_filter
    params[:visibility_policy].presence_in(DocumentCatalog.visibility_policies.keys)
  end

  def filter_catalogs(catalogs)
    catalogs.select do |catalog|
      catalog_matches_query?(catalog) &&
        catalog_matches_audience_type?(catalog) &&
        catalog_matches_visibility_policy?(catalog)
    end
  end

  def catalog_matches_query?(catalog)
    return true if @catalog_query.blank?

    query = @catalog_query.downcase
    [catalog.name, catalog.description].any? { _1.to_s.downcase.include?(query) }
  end

  def catalog_matches_audience_type?(catalog)
    @audience_type_filter.blank? || catalog.audience_type == @audience_type_filter
  end

  def catalog_matches_visibility_policy?(catalog)
    @visibility_policy_filter.blank? || catalog.visibility_policy == @visibility_policy_filter
  end
end
