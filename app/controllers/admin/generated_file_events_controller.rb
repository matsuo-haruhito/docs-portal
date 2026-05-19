class Admin::GeneratedFileEventsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_generated_file_event, only: %i[show retry_dispatch]

  def index
    @status = params[:status].presence
    @generated_file_events = GeneratedFileEvent.order(created_at: :desc, id: :desc)
    @generated_file_events = @generated_file_events.public_send(@status) if @status.in?(GeneratedFileEvent.statuses.keys)
    @generated_file_events = @generated_file_events.limit(100)
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

  def set_generated_file_event
    @generated_file_event = GeneratedFileEvent.find_by!(public_id: params[:public_id])
  end
end
