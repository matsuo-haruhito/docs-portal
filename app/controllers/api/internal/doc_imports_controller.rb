class Api::Internal::DocImportsController < Api::BaseController
  before_action :authenticate_import_request!

  def create
    artifact_root = params.require(:artifact_root)
    manifest_path = params.require(:manifest_path)

    actor_email = ENV["DOC_IMPORT_ACTOR_EMAIL"].to_s
    raise ApplicationError::BadRequest, "DOC_IMPORT_ACTOR_EMAIL is not configured" if actor_email.blank?

    actor = User.find_by(email_address: actor_email)
    raise ApplicationError::BadRequest, "Import actor not found: #{actor_email}" unless actor

    result = DocumentImporter.new(
      artifact_root: artifact_root,
      manifest_path: manifest_path,
      actor: actor
    ).call

    render json: { publish_job_id: result.id, status: result.status }, status: :created
  end

  private

  def authenticate_import_request!
    authenticate_bearer_token!("DOC_IMPORT_TOKEN")
  end
end
