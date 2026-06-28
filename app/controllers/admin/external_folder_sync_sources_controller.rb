class Admin::ExternalFolderSyncSourcesController < Admin::BaseController
  METADATA_RECHECK_FIELDS = {
    "drive_id" => "Drive ID",
    "folder_item_id" => "Folder item ID",
    "folder_path" => "Folder path",
    "site_id" => "Site ID"
  }.freeze
  EXTERNAL_FOLDER_SYNC_SOURCE_SEARCH_QUERY_MAX_LENGTH = 100
  EXTERNAL_FOLDER_SYNC_SOURCE_DEFAULT_PER_PAGE = 10
  EXTERNAL_FOLDER_SYNC_SOURCE_MAX_PER_PAGE = 50
  PROJECT_SEARCH_QUERY_MAX_LENGTH = 100
  PROJECT_SEARCH_LIMIT = 20

  before_action :require_admin_only!
  before_action :set_external_folder_sync_source, only: %i[show edit update destroy dry_run apply force_apply enqueue subscribe unsubscribe recheck_metadata]
  before_action :ensure_google_drive_runtime_supported!, only: %i[dry_run apply force_apply enqueue subscribe unsubscribe]

  helper_method :safe_return_to

  def index
    load_index_state
    @external_folder_sync_source = ExternalFolderSyncSource.new(
      provider: :google_drive,
      auth_type: :oauth_user,
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
    assign_external_folder_metadata(@external_folder_sync_source)

    if @external_folder_sync_source.save
      redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source, return_to: safe_return_to), notice: "外部フォルダ同期設定を登録しました。"
    else
      load_index_state
      render :index, status: :unprocessable_entity
    end
  rescue ExternalFolderSync::MicrosoftGraphFolderResolver::Error => e
    @external_folder_sync_source.errors.add(:folder_url, e.message)
    load_index_state
    render :index, status: :unprocessable_entity
  end

  def edit
  end

  def update
    @external_folder_sync_source.assign_attributes(normalized_external_folder_sync_source_params)
    assign_external_folder_metadata(@external_folder_sync_source)

    if @external_folder_sync_source.save
      redirect_to admin_external_folder_sync_source_path(@external_folder_sync_source, return_to: safe_return_to), notice: "外部フォルダ同期設定を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  rescue ExternalFolderSync::MicrosoftGraphFolderResolver::Error => e
    @external_folder_sync_source.errors.add(:folder_url, e.message)
    render :edit, status: :unprocessable_entity
  end

  def destroy
    @external_folder_sync_source.destroy!
    redirect_to safe_return_to(admin_external_folder_sync_sources_path), notice: "外部フォルダ同期設定を削除しました。"
  end

  def dry_run
    run = ExternalFolderSync::Runner.new(source: @external_folder_sync_source, mode: :dry_run, actor: current_user).call
    redirect_to sync_source_path_with_return_to, notice: "同期プレビューを実行しました。（#{run.items_scanned_count}件）"
  rescue ExternalFolderSync::GoogleDriveClient::Error, ExternalFolderSync::Runner::Error => e
    redirect_to sync_source_path_with_return_to, alert: e.message
  end

  def apply
    run = ExternalFolderSync::Runner.new(source: @external_folder_sync_source, mode: :apply, actor: current_user).call
    redirect_to sync_source_path_with_return_to, notice: "同期しました。（#{run.items_scanned_count}件）"
  rescue ExternalFolderSync::GoogleDriveClient::Error, ExternalFolderSync::Runner::Error => e
    redirect_to sync_source_path_with_return_to, alert: e.message
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
    redirect_to sync_source_path_with_return_to, notice: "警告を承認して同期しました。（#{run.items_scanned_count}件）"
  rescue ExternalFolderSync::GoogleDriveClient::Error, ExternalFolderSync::Runner::Error => e
    redirect_to sync_source_path_with_return_to, alert: e.message
  end

  def enqueue
    if latest_dry_run_has_conflict_warnings?
      redirect_to_sync_source_with_warning(manual_enqueue_blocked_message)
      return
    end

    ExternalFolderSyncJob.perform_later(@external_folder_sync_source.id, current_user.id)
    redirect_to sync_source_path_with_return_to, notice: "バックグラウンド同期を登録しました。"
  end

  def subscribe
    subscription = ExternalFolderSync::GoogleDriveSubscriptionManager.new(
      source: @external_folder_sync_source,
      callback_url: external_folder_sync_webhooks_google_drive_url
    ).subscribe!
    redirect_to sync_source_path_with_return_to, notice: "Google Driveの変更通知の購読を開始しました。（期限: #{l(subscription.expires_at)}）"
  rescue ExternalFolderSync::GoogleDriveSubscriptionManager::Error => e
    redirect_to sync_source_path_with_return_to, alert: e.message
  end

  def unsubscribe
    ExternalFolderSync::GoogleDriveSubscriptionManager.new(
      source: @external_folder_sync_source,
      callback_url: external_folder_sync_webhooks_google_drive_url
    ).stop_active_subscription!
    redirect_to sync_source_path_with_return_to, notice: "Google Driveの変更通知の購読を停止しました。"
  rescue ExternalFolderSync::GoogleDriveSubscriptionManager::Error => e
    redirect_to sync_source_path_with_return_to, alert: e.message
  end

  def recheck_metadata
    unless @external_folder_sync_source.microsoft_graph?
      redirect_to sync_source_path_with_return_to, alert: "保存済み metadata の再確認は SharePoint / OneDrive の metadata-only source で利用できます。"
      return
    end

    resolved = ExternalFolderSync::MicrosoftGraphFolderResolver.new(source: @external_folder_sync_source).resolve
    summary = metadata_recheck_summary(metadata_recheck_comparisons(resolved))
    redirect_to sync_source_path_with_return_to,
                notice: summary["notice"],
                flash: { metadata_recheck_summary: summary }
  rescue ExternalFolderSync::MicrosoftGraphFolderResolver::Error
    redirect_to sync_source_path_with_return_to, alert: "保存済み metadata を再確認できませんでした。Microsoft Graph接続・共有URL・権限を確認してください。"
  end

  def project_search
    render json: { options: project_options(searchable_projects) }
  end

  def selected_project
    project = Project.find_by(id: params[:id])

    render json: { option: project ? project_option(project) : nil }
  end

  private

  def set_external_folder_sync_source
    @external_folder_sync_source = ExternalFolderSyncSource.find_by!(public_id: params[:public_id])
  end

  def load_index_state
    @selected_review_filter = normalize_review_filter(params[:review])
    @search_query = normalize_search_query(params[:q])

    base_scope = external_folder_sync_sources_scope
    @review_filter_counts = review_filter_counts(base_scope)

    scoped_sources = filter_external_folder_sync_sources_scope(base_scope).to_a
    @latest_runs_by_source_id = latest_runs_by_source_id(scoped_sources)
    filtered_sources = filter_external_folder_sync_sources_by_latest_run(scoped_sources)
    paginate_external_folder_sync_sources(filtered_sources)
  end

  def paginate_external_folder_sync_sources(sources)
    @external_folder_sync_sources_total_count = sources.size
    @external_folder_sync_sources_per_page = normalize_per_page(params[:per_page])
    @external_folder_sync_sources_total_pages = [(@external_folder_sync_sources_total_count.to_f / @external_folder_sync_sources_per_page).ceil, 1].max
    @external_folder_sync_sources_page = normalize_page(params[:page], @external_folder_sync_sources_total_pages)
    @external_folder_sync_sources_offset = (@external_folder_sync_sources_page - 1) * @external_folder_sync_sources_per_page
    @external_folder_sync_sources = sources.slice(@external_folder_sync_sources_offset, @external_folder_sync_sources_per_page) || []
  end

  def normalize_page(value, total_pages)
    page = Integer(value.presence || 1, exception: false) || 1
    page.clamp(1, total_pages)
  end

  def normalize_per_page(value)
    per_page = Integer(value.presence || EXTERNAL_FOLDER_SYNC_SOURCE_DEFAULT_PER_PAGE, exception: false) || EXTERNAL_FOLDER_SYNC_SOURCE_DEFAULT_PER_PAGE
    per_page.clamp(1, EXTERNAL_FOLDER_SYNC_SOURCE_MAX_PER_PAGE)
  end

  def ensure_google_drive_runtime_supported!
    return if @external_folder_sync_source.google_drive?

    redirect_to sync_source_path_with_return_to, alert: "SharePoint / OneDrive の差分同期と変更通知は後続 issue で対応予定です。現在は共有URLからフォルダ metadata を保存するところまで利用できます。"
  end

  def external_folder_sync_sources_scope
    ExternalFolderSyncSource.includes(:project, :created_by).order(:provider, :name, :id)
  end

  def filter_external_folder_sync_sources_scope(scope)
    scope = apply_external_folder_sync_source_search(scope)

    case @selected_review_filter
    when "disabled"
      scope.where(enabled: false)
    when "google_drive"
      scope.google_drive
    when "microsoft_graph"
      scope.microsoft_graph
    else
      scope
    end
  end

  def apply_external_folder_sync_source_search(scope)
    return scope if @search_query.blank?

    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@search_query.downcase)}%"
    scope.left_joins(:project).where(
      <<~SQL.squish,
        LOWER(external_folder_sync_sources.name) LIKE :pattern OR
        LOWER(projects.name) LIKE :pattern OR
        LOWER(projects.code) LIKE :pattern OR
        LOWER(external_folder_sync_sources.external_folder_id) LIKE :pattern OR
        LOWER(external_folder_sync_sources.external_folder_path) LIKE :pattern
      SQL
      pattern:
    )
  end

  def filter_external_folder_sync_sources_by_latest_run(sources)
    return sources unless %w[warnings errors].include?(@selected_review_filter)

    sources.select { |source| review_filter_matches_latest_run?(source, @selected_review_filter) }
  end

  def review_filter_counts(scope)
    latest_error_messages_by_source_id = scope.reorder(nil).pluck(:id, :last_error_message).to_h
    source_ids = latest_error_messages_by_source_id.keys
    latest_runs_by_source_id = latest_runs_by_source_ids(source_ids)

    {
      all: scope.count,
      warnings: source_ids.count { |source_id| conflict_warnings_count_from_run(latest_runs_by_source_id[source_id]).positive? },
      errors: source_ids.count { |source_id| latest_error_message_from_run(latest_runs_by_source_id[source_id], latest_error_messages_by_source_id[source_id]).present? },
      disabled: scope.where(enabled: false).count,
      google_drive: scope.google_drive.count,
      microsoft_graph: scope.microsoft_graph.count
    }
  end

  def normalize_review_filter(value)
    return value if %w[warnings errors disabled google_drive microsoft_graph].include?(value)

    nil
  end

  def normalize_search_query(value)
    value.to_s.squish.first(EXTERNAL_FOLDER_SYNC_SOURCE_SEARCH_QUERY_MAX_LENGTH).presence
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
    { value: project.id, text: helpers.external_folder_sync_source_project_option_label(project) }
  end

  def review_filter_matches_latest_run?(source, selected_review_filter)
    case selected_review_filter
    when "warnings"
      conflict_warnings_count(source).positive?
    when "errors"
      latest_error_message(source).present?
    else
      true
    end
  end

  def latest_runs_by_source_id(sources)
    latest_runs_by_source_ids(sources.map(&:id))
  end

  def latest_runs_by_source_ids(source_ids)
    compact_source_ids = source_ids.compact
    return {} if compact_source_ids.empty?

    ExternalFolderSyncRun
      .select("DISTINCT ON (external_folder_sync_runs.external_folder_sync_source_id) external_folder_sync_runs.*")
      .where(external_folder_sync_source_id: compact_source_ids)
      .order(Arel.sql("external_folder_sync_runs.external_folder_sync_source_id, external_folder_sync_runs.started_at DESC, external_folder_sync_runs.id DESC"))
      .index_by(&:external_folder_sync_source_id)
  end

  def latest_run_for(source, latest_runs_by_source_id = @latest_runs_by_source_id)
    latest_runs_by_source_id[source.id]
  end

  def conflict_warnings_count(source, latest_runs_by_source_id = @latest_runs_by_source_id)
    conflict_warnings_count_from_run(latest_run_for(source, latest_runs_by_source_id))
  end

  def conflict_warnings_count_from_run(run)
    run&.summary_json&.fetch("conflict_warnings_count", 0).to_i
  end

  def latest_error_message(source, latest_runs_by_source_id = @latest_runs_by_source_id)
    latest_error_message_from_run(latest_run_for(source, latest_runs_by_source_id), source.last_error_message)
  end

  def latest_error_message_from_run(run, source_last_error_message)
    run&.error_message.presence || source_last_error_message.presence
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
    redirect_to sync_source_path_with_return_to, alert: message
  end

  def safe_return_to(fallback = admin_external_folder_sync_sources_path)
    safe_return_to_path(fallback)
  end

  def sync_source_path_with_return_to
    admin_external_folder_sync_source_path(@external_folder_sync_source, return_to: safe_return_to)
  end

  def force_apply_blocked_message
    "先に同期プレビューで競合・重複警告の内容を確認してください。"
  end

  def manual_enqueue_blocked_message
    "直近の同期プレビューに競合・重複警告があります。警告を確認してから同期してください。"
  end

  def metadata_recheck_summary(comparisons)
    changed_labels = comparisons.filter_map { |comparison| comparison[:label] unless comparison[:matched] }
    matched_labels = comparisons.filter_map { |comparison| comparison[:label] if comparison[:matched] }

    {
      "status" => changed_labels.empty? ? "matched" : "changed",
      "matched_labels" => matched_labels,
      "changed_labels" => changed_labels,
      "notice" => metadata_recheck_notice(changed_labels)
    }
  end

  def metadata_recheck_notice(changed_labels)
    if changed_labels.empty?
      "保存済み metadata を再確認しました。Drive ID / Folder item ID / Folder path / Site ID は現在の Microsoft Graph 解決結果と一致しています。"
    else
      "保存済み metadata を再確認しました。差分があります: #{changed_labels.join(' / ')}。保存済み値は変更していません。必要なら設定を編集して保存し直してください。"
    end
  end

  def metadata_recheck_comparisons(resolved)
    METADATA_RECHECK_FIELDS.map do |key, label|
      {
        label:,
        matched: metadata_recheck_current_value(key) == resolved[key.to_sym].to_s
      }
    end
  end

  def metadata_recheck_current_value(key)
    metadata = @external_folder_sync_source.provider_metadata || {}

    value = case key
            when "folder_item_id"
              @external_folder_sync_source.external_folder_id.presence || metadata[key]
            when "folder_path"
              @external_folder_sync_source.external_folder_path.presence || metadata[key]
            else
              metadata[key]
            end

    value.to_s
  end

  def normalized_external_folder_sync_source_params
    attrs = external_folder_sync_source_params.to_h
    if attrs["auth_type"] == "oauth_user"
      attrs["auth_config"] = @external_folder_sync_source&.oauth_user? ? @external_folder_sync_source.auth_config : {}.to_json
    elsif attrs["auth_type"] == "microsoft_graph_connection"
      attrs["auth_config"] = {}.to_json
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

  def assign_external_folder_metadata(source)
    if source.google_drive?
      folder_id = ExternalFolderSync::GoogleDriveClient.extract_folder_id(source.folder_url)
      source.external_folder_id = folder_id if folder_id.present?
      source.provider_metadata = {}
      return
    end

    return unless source.microsoft_graph?

    resolved = ExternalFolderSync::MicrosoftGraphFolderResolver.new(source: @external_folder_sync_source).resolve
    source.external_folder_id = resolved.fetch(:folder_item_id)
    source.external_folder_path = resolved.fetch(:folder_path)
    source.provider_metadata = {
      "drive_id" => resolved.fetch(:drive_id),
      "folder_item_id" => resolved.fetch(:folder_item_id),
      "folder_path" => resolved.fetch(:folder_path),
      "site_id" => resolved[:site_id]
    }.compact
  end
end
