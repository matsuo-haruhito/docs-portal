class Admin::GeneratedFileRunsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_generated_file_run, only: %i[show retry_run]

  DEFAULT_PER_PAGE = 50
  MAX_PER_PAGE = 100
  QUERY_MAX_LENGTH = 100
  READ_ONLY_MAINTENANCE_ENV = "READ_ONLY_MAINTENANCE"

  def index
    @filters = run_filter_params
    @filter_warnings = []
    @page = page_param
    @per_page = per_page_param
    @status_counts = GeneratedFileRun.group(:status).count
    @filtered_generated_file_runs = apply_filters(GeneratedFileRun.order(created_at: :desc, id: :desc))
    @bulk_retry_target_count = bulk_retry_target_count
    @total_count = @filtered_generated_file_runs.count
    @total_pages = total_pages(@total_count)
    @generated_file_runs = @filtered_generated_file_runs.offset((@page - 1) * @per_page).limit(@per_page)
  end

  def show
    @related_generated_file_event_public_ids = Array(@generated_file_run.metadata&.dig("generated_file_event_public_ids")).compact_blank.uniq
    @related_generated_file_events_by_public_id = GeneratedFileEvent.where(public_id: @related_generated_file_event_public_ids).index_by(&:public_id)
    @retry_of_generated_file_run_public_id = @generated_file_run.metadata&.dig("retry_of_generated_file_run_public_id").presence
    @retry_of_generated_file_run = GeneratedFileRun.find_by(public_id: @retry_of_generated_file_run_public_id) if @retry_of_generated_file_run_public_id
    @retry_requested_by_user_id = @generated_file_run.metadata&.dig("retry_requested_by_user_id").presence
    @retry_requested_by_user = User.find_by(id: @retry_requested_by_user_id) if @retry_requested_by_user_id
    @retry_evidence_visible = generated_file_run_retry_evidence_visible?
    @retry_child_runs = recent_runs_related_to(@generated_file_run.public_id)
  end

  def retry_run
    if read_only_maintenance_mode?
      redirect_to admin_generated_file_run_path(@generated_file_run.public_id, return_to: @return_to_path), alert: maintenance_retry_message
      return
    end

    enqueue_retry!(@generated_file_run)

    redirect_to admin_generated_file_run_path(@generated_file_run.public_id, return_to: @return_to_path), notice: "生成ジョブの再実行をキューに投入しました。"
  end

  def retry_failed
    @filters = run_filter_params
    @filter_warnings = []

    if read_only_maintenance_mode?
      redirect_to admin_generated_file_runs_path(@filters), alert: maintenance_retry_message
      return
    end

    runs = apply_filters(GeneratedFileRun.failed.order(created_at: :asc, id: :asc)).limit(MAX_PER_PAGE)
    runs.each { enqueue_retry!(_1, bulk: true) }

    redirect_to admin_generated_file_runs_path(@filters), notice: "失敗した生成ジョブ #{runs.size} 件の再実行をキューに投入しました。"
  end

  private

  def enqueue_retry!(run, bulk: false)
    GeneratedFileJob.perform_later(
      changed_files: Array(run.changed_files),
      job_ids: [run.job_id],
      event_source: bulk ? "generated_file_run_bulk_retry" : "generated_file_run_retry",
      metadata: retry_metadata_for(run, bulk:)
    )
  end

  def read_only_maintenance_mode?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(READ_ONLY_MAINTENANCE_ENV, nil))
  end

  def maintenance_retry_message
    "メンテナンス中のため生成ファイルの再実行は停止しています。閲覧は継続できます。運用手順は本番運用・インフラ前提を確認してください。"
  end

  def bulk_retry_target_count
    apply_filters(GeneratedFileRun.failed.order(created_at: :asc, id: :asc)).limit(MAX_PER_PAGE).to_a.size
  end

  def recent_runs_related_to(public_id)
    related_retry_parent_public_ids = [public_id, @retry_of_generated_file_run_public_id].compact.uniq

    GeneratedFileRun
      .where.not(id: @generated_file_run.id)
      .where("metadata ->> 'retry_of_generated_file_run_public_id' IN (?)", related_retry_parent_public_ids)
      .order(created_at: :desc, id: :desc)
      .limit(10)
  end

  def generated_file_run_retry_evidence_visible?
    metadata = @generated_file_run.metadata || {}

    @retry_of_generated_file_run_public_id.present? ||
      metadata.key?("retry_requested_at") ||
      metadata.key?("retry_requested_by_user_id") ||
      metadata.key?("bulk_retry") ||
      @generated_file_run.event_source.in?(%w[generated_file_run_retry generated_file_run_bulk_retry])
  end

  def apply_filters(scope)
    filters = @filters || {}
    scope = scope.public_send(filters[:status]) if filters[:status].in?(GeneratedFileRun.statuses.keys)
    scope = scope.where(job_id: filters[:job_id]) if filters[:job_id].present?
    scope = scope.where(generator: filters[:generator]) if filters[:generator].present?
    scope = scope.where(output_writer: filters[:output_writer]) if filters[:output_writer].present?
    scope = scope.where(event_source: filters[:event_source]) if filters[:event_source].present?
    scope = apply_search(scope, filters[:q]) if filters[:q].present?

    created_from = parsed_time(filters[:created_from], label: "作成日(開始)", beginning: true)
    created_to = parsed_time(filters[:created_to], label: "作成日(終了)", end_of_day: true)
    scope = scope.where("created_at >= ?", created_from) if created_from
    scope = scope.where("created_at <= ?", created_to) if created_to
    scope
  end

  def apply_search(scope, query)
    escaped_query = ActiveRecord::Base.sanitize_sql_like(query.to_s.downcase)
    return scope if escaped_query.blank?

    pattern = "%#{escaped_query}%"
    scope.where(
      "LOWER(public_id) LIKE :pattern OR " \
      "LOWER(CAST(source_paths AS text)) LIKE :pattern OR " \
      "LOWER(CAST(changed_files AS text)) LIKE :pattern OR " \
      "LOWER(CAST(generated_paths AS text)) LIKE :pattern OR " \
      "LOWER(error_message) LIKE :pattern OR " \
      "LOWER(CAST(metadata AS text)) LIKE :pattern",
      pattern:
    )
  end

  def run_filter_params
    params
      .permit(:status, :job_id, :generator, :output_writer, :event_source, :created_from, :created_to, :q)
      .to_h
      .symbolize_keys
      .tap { |filters| filters[:q] = normalized_query(filters[:q]) }
  end

  def normalized_query(value)
    value.to_s.squish.first(QUERY_MAX_LENGTH).presence
  end

  def page_param
    [params[:page].to_i, 1].max
  end

  def per_page_param
    requested = params[:per_page].presence&.to_i || DEFAULT_PER_PAGE
    requested.clamp(1, MAX_PER_PAGE)
  end

  def total_pages(count)
    [(count.to_f / @per_page).ceil, 1].max
  end

  def parsed_time(value, label:, beginning: false, end_of_day: false)
    return if value.blank?

    raw_value = value.to_s.strip
    return invalid_time_filter(label, value) unless raw_value.match?(/\d/)

    time = Time.zone.parse(raw_value)
    return invalid_time_filter(label, value) unless time
    return time.beginning_of_day if beginning && raw_value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
    return time.end_of_day if end_of_day && raw_value.match?(/\A\d{4}-\d{2}-\d{2}\z/)

    time
  rescue ArgumentError, TypeError
    invalid_time_filter(label, value)
  end

  def invalid_time_filter(label, value)
    @filter_warnings ||= []
    @filter_warnings << "#{label}「#{value}」は日時として解釈できないため、この条件は適用していません。"
    nil
  end

  def set_generated_file_run
    @generated_file_run = GeneratedFileRun.find_by!(public_id: params[:public_id])
    @return_to_path = safe_return_to_path(admin_generated_file_runs_path)
  end

  def retry_metadata
    retry_metadata_for(@generated_file_run)
  end

  def retry_metadata_for(run, bulk: false)
    (run.metadata || {}).merge(
      "retry_of_generated_file_run_public_id" => run.public_id,
      "retry_requested_at" => Time.current.iso8601,
      "retry_requested_by_user_id" => current_user&.id,
      "bulk_retry" => bulk
    ).compact
  end
end
