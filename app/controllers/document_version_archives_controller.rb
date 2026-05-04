class DocumentVersionArchivesController < BaseController
  def show
    version = DocumentVersion.find_by!(public_id: params[:document_version_public_id])
    require_document_version_view_access!(version)
    require_document_download_access!(version.document)

    archive = DocumentVersionZipBuilder.new(version:, user: current_user)
    filename = archive.filename
    record_zip_download_access_log(version, filename)

    send_data(
      archive.to_binary,
      filename:,
      type: "application/zip",
      disposition: "attachment"
    )
  end
end
