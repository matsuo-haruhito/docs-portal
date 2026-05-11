class Admin::ExternalFolderSyncSourcesController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_external_folder_sync_source, only: %i[show edit update destroy dry_run apply enqueue]
  before_action :load_form_collections, only: %i[index create edit update]

  def index
    @external_folder_sync_sources = external_folder_sync_sources_scope
    @external_folder_sync_source = ExternalFolderSyncSource.new(
      provider: :google_drive,
      auth_type: :service_account,
      sync_direction: :external_to_portal,
      conflict_policy: :manual,
      enabled: true
    )
  end

  def show
    @runs = @external_folder_sync_source.external_folder_sync_runs.order(started_at: :desc, id: :desc).limit(20)
    @items = @external_folder_sync_source.external_folder_sync_items.order(:path, :id).limit(200)
  end

  def create
    @external_folder_sync_source = ExternalFolderSyncSource.new(external_folder_sync_source_params)
    @external_folder_sync_source.created_by = current_user
    assign_google_drive_folder_id(@external_folder_sync_source)

    if @external_folder_sync_source.save
      redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), notice: "外部フォルダ同期設定を登録しました。"
    else
      @external_folder_sync_sources = external_folder_sync_sources_scope
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    attrs = external_folder_sync_source_params
    attrs.delete(:auth_config) if attrs[:auth_config].blank?
    @external_folder_sync_source.assign_attributes(attrs)
    assign_google_drive_folder_id(@external_folder_sync_source)

    if @external_folder_sync_source.save
      redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), notice: "外部フォルダ同期設定を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @external_folder_sync_source.destroy!
    redirect_to admin_external_folder_sync_sources_path, notice: "外部フォルダ同期設定を削除しました。"
  end

  def dry_run
    run = ExternalFolderSync::Runner.new(source: @external_folder_sync_source, mode: :dry_run, actor: current_user).call
    redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), notice: "dry-runを実行しました。（#{run.items_scanned_count}件）"
  rescue ExternalFolderSync::GoogleDriveClient::Error, ExternalFolderSync::Runner::Error => e
    redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), alert: e.message
  end

  def apply
    run = ExternalFolderSync::Runner.new(source: @external_folder_sync_source, mode: :apply, actor: current_user).call
    redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), notice: "同期を実行しました。（#{run.items_scanned_count}件）"
  rescue ExternalFolderSync::GoogleDriveClient::Error, ExternalFolderSync::Runner::Error => e
    redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), alert: e.message
  end

  def enqueue
    ExternalFolderSyncJob.perform_later(@external_folder_sync_source.id, current_user.id)
    redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), notice: "同期ジョブを登録しました。"
  end

  private

  def set_external_folder_sync_source
    @external_folder_sync_source = ExternalFolderSyncSource.find_by!(public_id: params[:id])
  end

  def load_form_collections
    @projects = Project.order(:code)
  end

  def external_folder_sync_sources_scope
    ExternalFolderSyncSource.includes(:project, :created_by).order(:provider, :name, :id)
  end

  def external_folder_sync_source_params
    params.require(:external_folder_sync_source).permit(
      :project_id,
      :provider,
      :auth_type,
      :name,
      :folder_url,
      :external_folder_path,
      :sync_direction,
      :conflict_policy,
      :enabled,
      :auth_config
    )
  end

  def assign_google_drive_folder_id(source)
    return unless source.google_drive?

    folder_id = ExternalFolderSync::GoogleDriveClient.extract_folder_id(source.folder_url)
    source.external_folder_id = folder_id if folder_id.present?
  end
end
