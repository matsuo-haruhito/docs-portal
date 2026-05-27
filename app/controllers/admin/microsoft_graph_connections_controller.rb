class Admin::MicrosoftGraphConnectionsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_microsoft_graph_connection, only: %i[edit update destroy]
  before_action :load_form_collections, only: %i[index create edit update]

  def index
    load_index_state
    @microsoft_graph_connection = MicrosoftGraphConnection.new(auth_type: :client_credentials, preview_folder_path: "docs-portal-previews", enabled: true)
  end

  def create
    @microsoft_graph_connection = MicrosoftGraphConnection.new(microsoft_graph_connection_params)
    @microsoft_graph_connection.created_by = current_user

    if @microsoft_graph_connection.save
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

  private

  def set_microsoft_graph_connection
    @microsoft_graph_connection = MicrosoftGraphConnection.find_by!(public_id: params[:id])
  end

  def load_form_collections
    @projects = Project.order(:code)
  end

  def load_index_state
    base_connections = microsoft_graph_connections_scope.to_a
    project_ids = base_connections.map(&:project_id)
    @preview_connection_ids_by_project = MicrosoftGraphConnection.preview_selected_ids_by_project(project_ids)
    @duplicate_enabled_project_ids = MicrosoftGraphConnection.enabled_only.where(project_id: project_ids)
      .group(:project_id)
      .having("COUNT(*) > 1")
      .count
      .keys
    @duplicate_projects = base_connections.select { |connection| @duplicate_enabled_project_ids.include?(connection.project_id) }.map(&:project).uniq
    @preview_usage_counts = preview_usage_counts(base_connections)
    @selected_preview_usage = normalize_preview_usage(params[:preview_usage])
    @duplicate_only = params[:duplicate_only] == "1"
    @microsoft_graph_connections = filter_connections(base_connections)
  end

  def microsoft_graph_connections_scope
    MicrosoftGraphConnection.includes(:project, :created_by).order(:name, :id)
  end

  def filter_connections(connections)
    filtered = connections.select { |connection| preview_usage_matches?(connection, @selected_preview_usage) }
    return filtered unless @duplicate_only

    filtered.select { |connection| @duplicate_enabled_project_ids.include?(connection.project_id) }
  end

  def preview_usage_counts(connections)
    {
      all: connections.size,
      preview_selected: connections.count { |connection| preview_selected_connection?(connection) },
      enabled_unused: connections.count { |connection| connection.enabled? && !preview_selected_connection?(connection) },
      disabled: connections.count { |connection| !connection.enabled? }
    }
  end

  def normalize_preview_usage(value)
    return value if %w[preview_selected enabled_unused disabled].include?(value)

    nil
  end

  def preview_usage_matches?(connection, selected_preview_usage)
    case selected_preview_usage
    when "preview_selected"
      preview_selected_connection?(connection)
    when "enabled_unused"
      connection.enabled? && !preview_selected_connection?(connection)
    when "disabled"
      !connection.enabled?
    else
      true
    end
  end

  def preview_selected_connection?(connection)
    connection.enabled? && @preview_connection_ids_by_project[connection.project_id] == connection.id
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
      :enabled
    )
  end
end