class Admin::GeneratedFileRunsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_generated_file_run, only: %i[show retry_run]

  def index
    @filters = run_filter_params
    @generated_file_runs = apply_filters(GeneratedFileRun.order(created_at: :desc, id: :desc)).limit(100)
  end

  def show
  end

  def retry_run
    GeneratedFileJob.perform_later(
      changed_files: @generated_file_run.changed_files,
      job_ids: [@generated_file_run.job_id],
      event_source: "generated_file_run_retry",
      metadata: retry_metadata
    )

    redirect_to admin_generated_file_run_path(@generated_file_run.public_id), notice: "生成ジョブの再実行をキューに投入しました。"
  end

  private

  def apply_filters(scope)
    scope = scope.public_send(@filters[:status]) if @filters[:status].in?(GeneratedFileRun.statuses.keys)
    scope = scope.where(job_id: @filters[:job_id]) if @filters[:job_id].present?
    scope = scope.where(generator: @filters[:generator]) if @filters[:generator].present?
    scope = scope.where(output_writer: @filters[:output_writer]) if @filters[:output_writer].present?
    scope = scope.where(event_source: @filters[:event_source]) if @filters[:event_source].present?

    created_from = parsed_time(@filters[:created_from], beginning: true)
    created_to = parsed_time(@filters[:created_to], end_of_day: true)
    scope = scope.where("created_at >= ?", created_from) if created_from
    scope = scope.where("created_at <= ?", created_to) if created_to
    scope
  end

  def run_filter_params
    params.permit(:status, :job_id, :generator, :output_writer, :event_source, :created_from, :created_to).to_h.symbolize_keys
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
    (@generated_file_run.metadata || {}).merge(
      "retry_of_generated_file_run_public_id" => @generated_file_run.public_id,
      "retry_requested_at" => Time.current.iso8601,
      "retry_requested_by_user_id" => current_user&.id
    ).compact
  end
end
