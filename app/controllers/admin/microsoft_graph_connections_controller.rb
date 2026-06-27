class Admin::MicrosoftGraphConnectionsController < Admin::BaseController
  MAX_SEARCH_QUERY_LENGTH = 100
  INDEX_RESULT_LIMIT = 50
  PROJECT_SEARCH_QUERY_MAX_LENGTH = 100
  PROJECT_SEARCH_LIMIT = 20

  before_action :require_admin_only!
  before_action :set_microsoft_graph_connection, only: %i[edit update destroy]

  def index
    load_index_state
    @microsoft_graph_connection = MicrosoftGraphConnection.new(auth_type: :client_credentials, preview_folder_path: "docs-portal-previews", enabled: true)
  end

  def create
    @microsoft_graph_connection = MicrosoftGraphConnection.new(microsoft_graph_connection_params)
    @microsoft_graph_connection.created_by = current_user

    if resolve_share_url_request?
      resolve_shared_folder_for(@microsoft_graph_connection, client_secret: @microsoft_graph_connection.client_secret)
      load_index_state
      render :index, status: @microsoft_graph_connection.errors.any? ? :unprocessable_entity : :ok
    elsif @microsoft_graph_connection.save
      redirect_to admin_microsoft_graph_connections_path, notice: "Microsoft Graph接続設定を登録しました。"
    else
      load_index_state
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    attrs = microsoft_graph_connection_params

    if resolve_share_url_request?
      resolution_attrs = attrs.except(:client_secret)
      resolution_attrs[:client_secret] = attrs[:client_secret] if attrs[:client_secret].present?
      @microsoft_graph_connection.assign_attributes(resolution_attrs)
      resolve_shared_folder_for(@microsoft_graph_connection, client_secret: attrs[:client_secret].presence || @microsoft_graph_connection.client_secret)
      render :edit, status: @microsoft_graph_connection.errors.any? ? :unprocessable_entity : :ok
      return
    end

    attrs.delete(:client_secret) if attrs[:client_secret].blank?

    if @microsoft_graph_connection.update(attrs)
      redirect_to admin_microsoft_graph_connections_path, notice: "Microsoft Graph接続設定を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @microsoft_graph_connection.destroy!
    redirect_to admin_microsoft_graph_connections_path, notice: "Microsoft Graph接続設定を削除しました。"
  end

  def project_search
    render json: { options: project_options(searchable_projects) }
  end

  def selected_project
    project = Project.find_by(id: params[:id])

    render json: { option: project ? project_option(project) : nil }
  end

  private

  def set_microsoft_graph_connection
    @microsoft_graph_connection = MicrosoftGraphConnection.find_by!(public_id: params[:public_id])
  end

  def load_index_state
    base_scope = microsoft_graph_connections_scope
    project_ids = base_scope.unscope(:order).distinct.pluck(:project_id)
    @preview_connection_ids_by_project = MicrosoftGraphConnection.preview_selected_ids_by_project(project_ids)
    @duplicate_enabled_project_ids = MicrosoftGraphConnection.enabled_only.where(project_id: project_ids)
      .group(:project_id)
      .having("COUNT(*) > 1")
      .count
      .keys
    @duplicate_projects = Project.where(id: @duplicate_enabled_project_ids).order(:code, :id)
    @preview_usage_counts = preview_usage_counts(base_scope)
    @selected_preview_usage = normalize_preview_usage(params[:preview_usage])
    @duplicate_only = params[:duplicate_only] == "1"
    @search_query = normalize_search_query(params[:q])

    filtered_scope = filter_connections(base_scope)
    @microsoft_graph_connections_total_count = filtered_scope.count
    @microsoft_graph_connections_page = normalized_page(@microsoft_graph_connections_total_count)
    @microsoft_graph_connections_limit = INDEX_RESULT_LIMIT
    @microsoft_graph_connections_offset = (@microsoft_graph_connections_page - 1) * INDEX_RESULT_LIMIT
    @microsoft_graph_connections = filtered_scope.offset(@microsoft_graph_connections_offset).limit(INDEX_RESULT_LIMIT).to_a
    @microsoft_graph_connections_has_previous_page = @microsoft_graph_connections_page > 1
    @microsoft_graph_connections_has_next_page = @microsoft_graph_connections_offset + @microsoft_graph_connections.size < @microsoft_graph_connections_total_count
  end

  def microsoft_graph_connections_scope
    MicrosoftGraphConnection.includes(:project, :created_by).order(:name, :id)
  end

  def filter_connections(scope)
    filtered = filter_by_preview_usage(scope, @selected_preview_usage)
    filtered = filtered.where(project_id: @duplicate_enabled_project_ids) if @duplicate_only
    filtered = filter_by_search_query(filtered, @search_query) if @search_query.present?
    filtered
  end

  def preview_usage_counts(scope)
    preview_selected_ids = @preview_connection_ids_by_project.values

    {
      all: scope.count,
      preview_selected: scope.where(id: preview_selected_ids).count,
      enabled_unused: scope.where(enabled: true).where.not(id: preview_selected_ids).count,
      disabled: scope.where(enabled: false).count
    }
  end

  def normalize_preview_usage(value)
    return value if %w[preview_selected enabled_unused disabled].include?(value)

    nil
  end

  def normalize_search_query(value)
    normalized = value.to_s.squish
    return if normalized.blank?

    normalized.first(MAX_SEARCH_QUERY_LENGTH)
  end

  def normalized_page(total_count)
    requested_page = params[:page].to_i
    page = requested_page.positive? ? requested_page : 1
    max_page = [(total_count.to_f / INDEX_RESULT_LIMIT).ceil, 1].max

    page > max_page ? 1 : page
  end

  def filter_by_preview_usage(scope, selected_preview_usage)
    preview_selected_ids = @preview_connection_ids_by_project.values

    case selected_preview_usage
    when "preview_selected"
      scope.where(id: preview_selected_ids)
    when "enabled_unused"
      scope.where(enabled: true).where.not(id: preview_selected_ids)
    when "disabled"
      scope.where(enabled: false)
    else
      scope
    end
  end

  def filter_by_search_query(scope, search_query)
    query = "%#{ActiveRecord::Base.sanitize_sql_like(search_query.downcase)}%"

    scope.left_joins(:project).where(
      <<~SQL.squish,
        LOWER(projects.name) LIKE :query OR
        LOWER(projects.code) LIKE :query OR
        LOWER(microsoft_graph_connections.name) LIKE :query OR
        LOWER(microsoft_graph_connections.tenant_id) LIKE :query OR
        LOWER(microsoft_graph_connections.client_id) LIKE :query OR
        LOWER(microsoft_graph_connections.drive_id) LIKE :query OR
        LOWER(microsoft_graph_connections.site_id) LIKE :query OR
        LOWER(microsoft_graph_connections.preview_folder_path) LIKE :query
      SQL
      query:
    )
  end

  def searchable_projects
    scope = Project.order(:code, :id)
    query = normalize_project_search_query(params[:q])
    return scope.limit(PROJECT_SEARCH_LIMIT) if query.blank?

    pattern = "%#{Project.sanitize_sql_like(query.downcase)}%"
    scope.where(
      "LOWER(projects.code) LIKE :pattern OR LOWER(projects.name) LIKE :pattern",
      pattern:
    ).limit(PROJECT_SEARCH_LIMIT)
  end

  def normalize_project_search_query(query)
    query.to_s.strip.first(PROJECT_SEARCH_QUERY_MAX_LENGTH)
  end

  def project_options(projects)
    projects.map { |project| project_option(project) }
  end

  def project_option(project)
    { value: project.id, text: helpers.microsoft_graph_connection_project_option_label(project) }
  end

  def resolve_share_url_request?
    params[:resolve_share_url].present?
  end

  def resolve_shared_folder_for(connection, client_secret:)
    result = MicrosoftGraphSharedFolderResolver.new(
      tenant_id: connection.tenant_id,
      client_id: connection.client_id,
      client_secret: client_secret,
      shared_folder_url: connection.shared_folder_url
    ).resolve

    connection.drive_id = result.drive_id
    connection.site_id = result.site_id if result.site_id.present?
    connection.preview_folder_path = result.preview_folder_path
  rescue MicrosoftGraphSharedFolderResolver::ResolutionError => e
    connection.errors.add(:base, e.message)
  end

  def microsoft_graph_connection_params
    params.require(:microsoft_graph_connection).permit(
      :project_id,
      :name,
      :auth_type,
      :tenant_id,
      :client_id,
      :client_secret,
      :site_id,
      :drive_id,
      :preview_folder_path,
      :enabled,
      :shared_folder_url
    )
  end
end
