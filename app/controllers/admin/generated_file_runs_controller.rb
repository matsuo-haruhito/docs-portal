class Admin::GeneratedFileRunsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_generated_file_run, only: %i[show retry_run]

  DEFAULT_PER_PAGE = 50
  MAX_PER_PAGE = 100

  def index
    @filters = run_filter_params
    @page = page_param
    @per_page = per_page_param
    @status_counts = GeneratedFileRun.group(:status).count
    @filtered_generated_file_runs = apply_filters(GeneratedFileRun.order(created_at: :desc, id: :desc))
    @total_count = @filtered_generated_file_runs.count
    @total_pages = total_pages(@total_count)
    @generated_file_runs = @filtered_generated_file_runs.offset((@page - 1) * @per_page).limit(@per_page)
  end

  def show
  end

  def retry_run
    enqueue_retry!(@generated_file_run)

    redirect_to admin_generated_file_run_path(@generated_file_run.public_id), notice: "生成ジョブの再実行をキューに投入しました。"
  end

  def retry_failed
    @filters = run_filter_params
    runs = apply_filters(GeneratedFileRun.failed.order(created_at: :asc, id: :asc)).limit(MAX_PER_PAGE)
    runs.each { enqueue_retry!(_1, bulk: true) }

    redirect_to admin_generated_file_runs_path(@filters), notice: "失敗した生成ジョブ #{runs.size} 件の再実行をキューに投入しました。"
  end

  private

  def enqueue_retry!(run, bulk: false)
    GeneratedFileJob.perform_later(
      changed_files: run.changed_files,
      job_ids: [run.job_id],
      event_source: bulk ? "generated_file_run_bulk_retry" : "generated_file_run_retry",
      metadata: retry_metadata_for(run, bulk:)
    )
  end

  def apply_filters(scope)
    filters = @filters || {}
    scope = scope.public_send(filters[:status]) if filters[:status].in?(GeneratedFileRun.statuses.keys)
    scope = scope.where(job_id: filters[:job_id]) if filters[:job_id].present?
    scope = scope.where(generator: filters[:generator]) if filters[:generator].present?
    scope = scope.where(output_writer: filters[:output_writer]) if filters[:output_writer].present?
    scope = scope.where(event_source: filters[:event_source]) if filters[:event_source].present?

    created_from = parsed_time(filters[:created_from], beginning: true)
    created_to = parsed_time(filters[:created_to], end_of_day: true)
    scope = scope.where("created_at >= ?", created_from) if created_from
    scope = scope.where("created_at <= ?", created_to) if created_to
    scope
  end

  def run_filter_params
    params.permit(:status, :job_id, :generator, :output_writer, :event_source, :created_from, :created_to).to_h.symbolize_keys
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

  def parsed_time(value, beginning: false, end_of_day: false)
    return if value.blank?

    time = Time.zone.parse(value.to_s)
    return time.beginning_of_day if beginning && value.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/)
    return time.end_of_day if end_of_day && value.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/)

    time
  rescue ArgumentError, TypeError
    nil
  end

  def set_generated_file_run
    @generated_file_run = GeneratedFileRun.find_by!(public_id: params[:public_id])
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
