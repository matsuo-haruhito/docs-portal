class Admin::FileUploadDryRunsController < Admin::BaseController
  PROJECT_SEARCH_QUERY_MAX_LENGTH = 100
  PROJECT_SEARCH_LIMIT = 20

  before_action :require_admin_only!
  before_action :set_import_dry_run, only: %i[show update]

  def index
    @status_options = status_options
    @selected_status = status_param
    @selected_project_id = project_id_param
    @selected_project = selected_project_for_filter
    @selected_project_option = project_option(@selected_project) if @selected_project.present?
    @selected_dry_run_id = dry_run_id_param
    @selected_query = query_param
    @dry_runs = ImportDryRun.where(import_mode: :manual_upload).includes(:project).order(created_at: :desc, id: :desc)
    @dry_runs = @dry_runs.where(status: @selected_status) if @selected_status.present?
    @dry_runs = @dry_runs.where(project_id: @selected_project_id) if @selected_project_id.present?
    @dry_runs = @dry_runs.where(public_id: @selected_dry_run_id) if @selected_dry_run_id.present?
    @dry_runs = apply_preview_metadata_query(@dry_runs) if @selected_query.present?
  end

  def show
    load_dry_run_payload
  end

  def update
    ensure_executable_file_upload_dry_run!

    publish_job = DocumentImporter.new(
      artifact_root: @import_dry_run.result_json.fetch("artifact_root"),
      manifest_path: @import_dry_run.result_json.fetch("manifest_path"),
      actor: current_user
    ).call

    @import_dry_run.update!(
      status: :confirmed,
      confirmed_by: current_user,
      confirmed_at: Time.current
    )
    publish_job.update!(log_message: [publish_job.log_message, "dry_run=#{@import_dry_run.public_id}"].compact.join("\n"))

    redirect_to admin_file_upload_dry_run_path(@import_dry_run), notice: "単体ファイルアップロードを実行しました。"
  rescue ApplicationError::BadRequest => e
    redirect_to admin_file_upload_dry_run_path(@import_dry_run), alert: e.message
  end

  def project_search
    render json: { options: project_options(searchable_projects) }
  end

  def selected_project
    project = Project.find_by(id: params[:id])

    render json: { option: project ? project_option(project) : nil }
  end

  private

  def set_import_dry_run
    @import_dry_run = ImportDryRun.find_by!(public_id: params[:public_id] || params[:id], import_mode: :manual_upload)
  end

  def status_options
    [["すべて", ""]] + ImportDryRun.statuses.keys.map do |status|
      [import_dry_run_status_label_value(status), status]
    end
  end

  def status_param
    status = params[:status].to_s
    ImportDryRun.statuses.key?(status) ? status : nil
  end

  def project_id_param
    project_id = params[:project_id].to_s
    return nil if project_id.blank?

    Project.exists?(id: project_id) ? project_id : nil
  end

  def selected_project_for_filter
    Project.find_by(id: @selected_project_id) if @selected_project_id.present?
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
    { value: project.id, text: project_option_label(project) }
  end

  def project_option_label(project)
    [project.code, project.name].compact_blank.join(" / ")
  end

  def dry_run_id_param
    params[:dry_run_id].to_s.strip.presence
  end

  def query_param
    params[:q].to_s.strip.presence
  end

  def apply_preview_metadata_query(scope)
    pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@selected_query)}%"
    scope.where(
      <<~SQL.squish,
        COALESCE(import_dry_runs.result_json #>> '{file_upload_preview,source_name}', '') ILIKE :query
        OR COALESCE(import_dry_runs.result_json #>> '{file_upload_preview,relative_path}', '') ILIKE :query
        OR COALESCE(import_dry_runs.result_json #>> '{file_upload_preview,content_hash}', '') ILIKE :query
      SQL
      query: pattern
    )
  end

  def import_dry_run_status_label_value(status)
    I18n.t("labels.import_dry_runs.status.#{status}", default: status)
  end

  def load_dry_run_payload
    @summary = @import_dry_run.summary_json || {}
    @result = @import_dry_run.result_json || {}
    @file_upload_preview = @result["file_upload_preview"] || {}
    @zip_import_preview = @file_upload_preview["zip_import_preview"] || {}
    @warnings = Array(@import_dry_run.warnings_json) + Array(@zip_import_preview["warnings"])
    @errors = Array(@import_dry_run.errors_json)
    @tree_preview = ImportDryRunTreePreview.new(@import_dry_run).call
  end

  def ensure_executable_file_upload_dry_run!
    raise ApplicationError::BadRequest, "実行済み、または実行できないdry-runです。" unless @import_dry_run.analyzed?
    raise ApplicationError::BadRequest, "file upload dry-run artifact is missing" if @import_dry_run.result_json["artifact_root"].blank? || @import_dry_run.result_json["manifest_path"].blank?
  end
end
