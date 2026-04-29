class Api::Internal::DocImportsController < Api::BaseController
  before_action :authenticate_import_request!

  def create
    artifact_root = params.require(:artifact_root)
    manifest_path = params.require(:manifest_path)

    actor = User.find_by!(email_address: "admin@example.com")

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
