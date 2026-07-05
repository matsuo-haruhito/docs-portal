class Api::Internal::ZipUploadsController < Api::BaseController
  before_action :authenticate_import_request!

  def create
    if validate_only?
      render_validation_result and return
    end

    render_read_only_maintenance_response and return if read_only_maintenance?

    ensure_zip_dry_run!
    result = importer.call
    attach_confirmed_dry_run!(result)

    render json: {
      publish_job_id: result.id,
      status: result.status,
      import_dry_run_id: confirmed_dry_run.public_id
    }, status: :created
  end

  private

  def validate_only?
    ActiveModel::Type::Boolean.new.cast(params[:validate_only])
  end

  def render_validation_result
    staged = stager.call
    result = ImportManifestDryRun.new(manifest: staged.manifest).call
    dry_run = ImportDryRun.create!(
      import_mode: :zip,
      project: project,
      created_by: actor,
      source_commit_hash: staged.manifest["source_commit_hash"],
      summary_json: result[:summary],
      result_json: result.merge(
        artifact_root: staged.artifact_root.to_s,
        manifest_path: staged.manifest_path.to_s,
        zip_import_preview: staged.manifest["zip_import_preview"]
      ),
      warnings_json: result[:warnings] + Array(staged.manifest.dig("zip_import_preview", "warnings")),
      errors_json: result[:errors]
    )

    render json: result.merge(
      dry_run_id: dry_run.public_id,
      status: dry_run.status,
      expires_at: dry_run.expires_at,
      zip_import_preview: staged.manifest["zip_import_preview"]
    ), status: :created
  end

  def ensure_zip_dry_run!
    raise ApplicationError::BadRequest, "import_dry_run_id is required for ZIP upload execution" unless confirmed_dry_run
    raise ApplicationError::BadRequest, "ZIP dry-run artifact is missing" if confirmed_dry_run.result_json["artifact_root"].blank? || confirmed_dry_run.result_json["manifest_path"].blank?
  end

  def attach_confirmed_dry_run!(publish_job)
    confirmed_dry_run.update!(
      status: :confirmed,
      confirmed_by: actor,
      confirmed_at: Time.current
    )
    publish_job.update!(log_message: [publish_job.log_message, "dry_run=#{confirmed_dry_run.public_id}"].compact.join("\n"))
  end

  def confirmed_dry_run
    return @confirmed_dry_run if defined?(@confirmed_dry_run)

    public_id = params[:import_dry_run_id].to_s
    @confirmed_dry_run =
      if public_id.present?
        ImportDryRun.find_by!(public_id:, status: :analyzed, import_mode: :zip)
      end
  end

  def importer
    @importer ||= DocumentImporter.new(
      artifact_root: confirmed_dry_run.result_json.fetch("artifact_root"),
      manifest_path: confirmed_dry_run.result_json.fetch("manifest_path"),
      actor:
    )
  end

  def stager
    @stager ||= ZipImportStager.new(
      uploaded_file: params.require(:zip_file),
      project:,
      actor:,
      source_repo: params[:source_repo],
      source_branch: params[:source_branch],
      source_commit_hash: params[:source_commit_hash],
      version_label: params[:version_label],
      status: params[:status]
    )
  end

  def project
    @project ||= Project.find_by!(code: params.require(:project_code))
  end

  def actor
    @actor ||= begin
      actor_email = ENV["DOC_IMPORT_ACTOR_EMAIL"].to_s
      raise ApplicationError::BadRequest, "DOC_IMPORT_ACTOR_EMAIL is not configured" if actor_email.blank?

      User.find_by(email_address: actor_email) || raise(ApplicationError::BadRequest, "Import actor not found: #{actor_email}")
    end
  end

  def authenticate_import_request!
    authenticate_bearer_token!("DOC_IMPORT_TOKEN")
  end
end
