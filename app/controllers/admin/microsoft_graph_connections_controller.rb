class Admin::MicrosoftGraphConnectionsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_microsoft_graph_connection, only: %i[edit update destroy]
  before_action :load_form_collections, only: %i[index create edit update]

  def index
    @microsoft_graph_connections = microsoft_graph_connections_scope
    @microsoft_graph_connection = MicrosoftGraphConnection.new(auth_type: :client_credentials, preview_folder_path: "docs-portal-previews", enabled: true)
  end

  def create
    @microsoft_graph_connection = MicrosoftGraphConnection.new(microsoft_graph_connection_params)
    @microsoft_graph_connection.created_by = current_user

    if @microsoft_graph_connection.save
      redirect_to admin_microsoft_graph_connections_path, notice: "Microsoft Graph接続設定を登録しました。"
    else
      @microsoft_graph_connections = microsoft_graph_connections_scope
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

  def microsoft_graph_connections_scope
    MicrosoftGraphConnection.includes(:project, :created_by).order(:name, :id)
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
