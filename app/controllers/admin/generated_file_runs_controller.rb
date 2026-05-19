class Admin::GeneratedFileRunsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_generated_file_run, only: %i[show retry_run]

  def index
    @generated_file_runs = GeneratedFileRun.order(created_at: :desc, id: :desc).limit(100)
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
