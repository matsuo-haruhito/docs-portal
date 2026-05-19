class Admin::ZipImportsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_import_dry_run, only: %i[show update]

  def new
    load_projects
  end

  def create
    dry_run = create_zip_dry_run!
    redirect_to admin_zip_import_path(dry_run), notice: "ZIPインポートのdry-runを作成しました。内容を確認してから取り込んでください。"
  rescue ActionController::ParameterMissing, ApplicationError::BadRequest => e
    load_projects
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    load_projects
    flash.now[:alert] = e.record.errors.full_messages.to_sentence.presence || "ZIPインポートのdry-runを作成できませんでした。"
    render :new, status: :unprocessable_entity
  end

  def show
    load_dry_run_payload
  end

  def update
    ensure_executable_zip_dry_run!

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

    redirect_to admin_zip_import_path(@import_dry_run), notice: "ZIPインポートを実行しました。"
  rescue ApplicationError::BadRequest => e
    redirect_to admin_zip_import_path(@import_dry_run), alert: e.message
  end

  private

  def set_import_dry_run
    @import_dry_run = ImportDryRun.find_by!(public_id: params[:public_id] || params[:id], import_mode: :zip)
  end

  def load_projects
    @projects = Project.order(:code, :name)
  end

  def create_zip_dry_run!
    staged = ZipImportStager.new(
      uploaded_file: params.require(:zip_file),
      project: selected_project,
      actor: current_user,
      source_repo: params[:source_repo],
      source_branch: params[:source_branch],
      source_commit_hash: params[:source_commit_hash],
      version_label: params[:version_label],
      status: params[:status]
    ).call

    result = ImportManifestDryRun.new(manifest: staged.manifest).call

    ImportDryRun.create!(
      import_mode: :zip,
      project: selected_project,
      created_by: current_user,
      source_commit_hash: staged.manifest["source_commit_hash"],
      summary_json: result[:summary],
      result_json: result.merge(
        artifact_root: staged.artifact_root.to_s,
        manifest_path: staged.manifest_path.to_s,
        zip_import_preview: staged.manifest["zip_import_preview"]
      ),
      warnings_json: Array(result[:warnings]) + Array(staged.manifest.dig("zip_import_preview", "warnings")),
      errors_json: Array(result[:errors])
    )
  end

  def selected_project
    @selected_project ||= Project.find(params.require(:project_id))
  end

  def load_dry_run_payload
    @summary = @import_dry_run.summary_json || {}
    @result = @import_dry_run.result_json || {}
    @zip_import_preview = @result["zip_import_preview"] || {}
    @warnings = Array(@import_dry_run.warnings_json)
    @errors = Array(@import_dry_run.errors_json)
    @tree_preview = ImportDryRunTreePreview.new(@import_dry_run).call
  end

  def ensure_executable_zip_dry_run!
    raise ApplicationError::BadRequest, "実行済み、または実行できないdry-runです。" unless @import_dry_run.analyzed?
    raise ApplicationError::BadRequest, "ZIP dry-run artifact is missing" if @import_dry_run.result_json["artifact_root"].blank? || @import_dry_run.result_json["manifest_path"].blank?
  end
end
