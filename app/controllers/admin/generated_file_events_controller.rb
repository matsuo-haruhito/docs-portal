class Admin::GeneratedFileEventsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_generated_file_event, only: %i[show retry_dispatch]

  def index
    @filters = event_filter_params
    @status_counts = GeneratedFileEvent.group(:status).count
    @generated_file_events = apply_filters(GeneratedFileEvent.order(created_at: :desc, id: :desc)).limit(100)
  end

  def show
  end

  def retry_dispatch
    @generated_file_event.update!(
      status: :pending,
      scheduled_at: Time.current,
      error_message: nil,
      processed_at: nil
    )
    GeneratedFileEventDispatchJob.perform_later

    redirect_to admin_generated_file_event_path(@generated_file_event.public_id), notice: "生成ファイルイベントの再dispatchをキューに投入しました。"
  end

  private

  def apply_filters(scope)
    scope = scope.public_send(@filters[:status]) if @filters[:status].in?(GeneratedFileEvent.statuses.keys)
    scope = scope.where(operation: @filters[:operation]) if @filters[:operation].present?
    scope = scope.where(event_source: @filters[:event_source]) if @filters[:event_source].present?
    scope = scope.where("path LIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(@filters[:path])}%") if @filters[:path].present?

    scheduled_from = parsed_time(@filters[:scheduled_from], beginning: true)
    scheduled_to = parsed_time(@filters[:scheduled_to], end_of_day: true)
    scope = scope.where("scheduled_at >= ?", scheduled_from) if scheduled_from
    scope = scope.where("scheduled_at <= ?", scheduled_to) if scheduled_to
    scope
  end

  def event_filter_params
    params.permit(:status, :operation, :event_source, :path, :scheduled_from, :scheduled_to).to_h.symbolize_keys
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

  def set_generated_file_event
    @generated_file_event = GeneratedFileEvent.find_by!(public_id: params[:public_id])
  end
end
