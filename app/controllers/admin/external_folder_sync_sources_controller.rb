class Admin::ExternalFolderSyncSourcesController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_external_folder_sync_source, only: %i[show edit update destroy dry_run apply force_apply enqueue subscribe unsubscribe]
  before_action :load_form_collections, only: %i[index create edit update]

  def index
    @external_folder_sync_sources = external_folder_sync_sources_scope
    @latest_runs_by_source_id = latest_runs_by_source_id(@external_folder_sync_sources)
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
    @subscriptions = @external_folder_sync_source.external_folder_sync_subscriptions.order(created_at: :desc, id: :desc).limit(20)
    @webhook_events = @external_folder_sync_source.external_folder_sync_webhook_events
      .includes(:external_folder_sync_subscription)
      .order(received_at: :desc, id: :desc)
      .limit(20)
  end

  def create
    @external_folder_sync_source = ExternalFolderSyncSource.new(normalized_external_folder_sync_source_params)
    @external_folder_sync_source.created_by = current_user
    assign_google_drive_folder_id(@external_folder_sync_source)

    if @external_folder_sync_source.save
      redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), notice: "外部フォルダ同期設定を登録しました。"
    else
      @external_folder_sync_sources = external_folder_sync_sources_scope
      @latest_runs_by_source_id = latest_runs_by_source_id(@external_folder_sync_sources)
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @external_folder_sync_source.assign_attributes(normalized_external_folder_sync_source_params)
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
    redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), notice: "同期プレビューを実行しました。（#{run.items_scanned_count}件）"
  rescue ExternalFolderSync::GoogleDriveClient::Error, ExternalFolderSync::Runner::Error => e
    redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), alert: e.message
  end

  def apply
    run = ExternalFolderSync::Runner.new(source: @external_folder_sync_source, mode: :apply, actor: current_user).call
    redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), notice: "同期を実行しました。（#{run.items_scanned_count}件）"
  rescue ExternalFolderSync::GoogleDriveClient::Error, ExternalFolderSync::Runner::Error => e
    redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), alert: e.message
  end

  def force_apply
    unless force_apply_allowed?
      redirect_to_sync_source_with_warning(force_apply_blocked_message)
      return
    end

    run = ExternalFolderSync::Runner.new(
      source: @external_folder_sync_source,
      mode: :apply,
      actor: current_user,
      allow_conflict_warnings: true
    ).call
    redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), notice: "警告を承認して同期しました。（#{run.items_scanned_count}件）"
  rescue ExternalFolderSync::GoogleDriveClient::Error, ExternalFolderSync::Runner::Error => e
    redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), alert: e.message
  end

  def enqueue
    if latest_dry_run_has_conflict_warnings?
      redirect_to_sync_source_with_warning(manual_enqueue_blocked_message)
      return
    end

    ExternalFolderSyncJob.perform_later(@external_folder_sync_source.id, current_user.id)
    redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), notice: "バックグラウンド同期を登録しました。"
  end

  def subscribe
    subscription = ExternalFolderSync::GoogleDriveSubscriptionManager.new(
      source: @external_folder_sync_source,
      callback_url: external_folder_sync_webhooks_google_drive_url
    ).subscribe!
    redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), notice: "Google Driveの変更通知の購読を開始しました。（期限: #{l(subscription.expires_at)}）"
  rescue ExternalFolderSync::GoogleDriveSubscriptionManager::Error => e
    redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), alert: e.message
  end

  def unsubscribe
    ExternalFolderSync::GoogleDriveSubscriptionManager.new(
      source: @external_folder_sync_source,
      callback_url: external_folder_sync_webhooks_google_drive_url
    ).stop_active_subscription!
    redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), notice: "Google Driveの変更通知の購読を停止しました。"
  rescue ExternalFolderSync::GoogleDriveSubscriptionManager::Error => e
    redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), alert: e.message
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

  def latest_runs_by_source_id(sources)
    source_ids = sources.map(&:id)
    ExternalFolderSyncRun
      .where(external_folder_sync_source_id: source_ids)
      .order(started_at: :desc, id: :desc)
      .group_by(&:external_folder_sync_source_id)
      .transform_values(&:first)
  end

  def latest_run
    @latest_run ||= @external_folder_sync_source.external_folder_sync_runs.order(started_at: :desc, id: :desc).first
  end

  def latest_dry_run_has_conflict_warnings?
    latest_run&.dry_run? && latest_run.summary_json&.fetch("conflict_warnings_count", 0).to_i.positive?
  end

  def force_apply_allowed?
    return false unless latest_dry_run_has_conflict_warnings?

    latest_run.summary_json&.fetch("conflict_warnings_approval", nil).blank?
  end

  def redirect_to_sync_source_with_warning(message)
    redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source), alert: message
  end

  def force_apply_blocked_message
    "先に同期プレビューで競合・重複警告の内容を確認してください。"
  end

  def manual_enqueue_blocked_message
    "直近の同期プレビューに競合・重複警告があります。警告を確認してから同期してください。"
  end

  def normalized_external_folder_sync_source_params
    attrs = external_folder_sync_source_params.to_h
    if attrs["auth_type"] == "oauth_user"
      attrs["auth_config"] = @external_folder_sync_source&.oauth_user? ? @external_folder_sync_source.auth_config : {}.to_json
    elsif attrs["auth_config"].blank?
      attrs.delete("auth_config")
    end
    attrs
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
