class Api::Internal::ArtifactImportsController < Api::BaseController
  before_action :authenticate_import_request!

  def create
    if validate_only?
      render_validation_result and return
    end

    render_read_only_maintenance_response and return if read_only_maintenance?

    ensure_confirmed_dry_run_matches_manifest!
    result = importer.call
    attach_direct_apply_note!(result) unless confirmed_dry_run
    attach_confirmed_dry_run!(result)

    render json: {
      publish_job_id: result.id,
      status: result.status,
      import_dry_run_id: confirmed_dry_run&.public_id
    }, status: :created
  end

  private

  def validate_only?
    ActiveModel::Type::Boolean.new.cast(params[:validate_only])
  end

  def render_validation_result
    result = ImportManifestDryRun.new(manifest: importer.manifest).call
    dry_run = ImportDryRun.create!(
      import_mode: :git_push,
      project: dry_run_project(result),
      created_by: actor,
      source_commit_hash: result[:source_commit_hash],
      summary_json: result[:summary],
      result_json: result,
      warnings_json: result[:warnings],
      errors_json: result[:errors]
    )

    render json: result.merge(
      dry_run_id: dry_run.public_id,
      status: dry_run.status,
      expires_at: dry_run.expires_at
    ), status: :created
  end

  def attach_direct_apply_note!(publish_job)
    publish_job.update!(log_message: [publish_job.log_message, "dry_run=not_provided direct_artifact_apply=true"].compact.join("\n"))
  end

  def attach_confirmed_dry_run!(publish_job)
    return unless confirmed_dry_run

    confirmed_dry_run.update!(
      status: :confirmed,
      confirmed_by: actor,
      confirmed_at: Time.current
    )
    publish_job.update!(log_message: [publish_job.log_message, "dry_run=#{confirmed_dry_run.public_id}"].compact.join("\n"))
  end

  def ensure_confirmed_dry_run_matches_manifest!
    return unless confirmed_dry_run

    manifest_commit_hash = importer.manifest["source_commit_hash"].presence
    dry_run_commit_hash = confirmed_dry_run.source_commit_hash.presence
    return if dry_run_commit_hash.blank? || manifest_commit_hash.blank? || dry_run_commit_hash == manifest_commit_hash

    raise ApplicationError::BadRequest, "source_commit_hash does not match the confirmed dry-run"
  end

  def confirmed_dry_run
    return @confirmed_dry_run if defined?(@confirmed_dry_run)

    public_id = params[:import_dry_run_id].to_s
    @confirmed_dry_run =
      if public_id.present?
        dry_run = ImportDryRun.find_by!(public_id:, status: :analyzed)
        raise ApplicationError::BadRequest, "import_dry_run_id must reference an analyzed git_push dry-run" unless dry_run.git_push?

        dry_run
      end
  end

  def dry_run_project(result)
    project_code = result[:projects].map { _1[:project_code] }.uniq.one? ? result[:projects].first[:project_code] : nil
    Project.find_by(code: project_code) if project_code.present?
  end

  def importer
    @importer ||= DocumentImporter.new(
      artifact_root: params.require(:artifact_root),
      manifest_path: params.require(:manifest_path),
      actor:
    )
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
