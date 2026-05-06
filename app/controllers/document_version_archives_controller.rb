class DocumentVersionArchivesController < BaseController
  def show
    version = DocumentVersion.find_by!(public_id: params[:document_version_public_id])
    require_document_version_view_access!(version)
    require_document_download_access!(version.document)

    archive = DocumentVersionZipBuilder.new(
      version:,
      user: current_user,
      zip_path_mode: zip_options[:zip_path_mode],
      include_markdown_sources: zip_options[:include_markdown_sources],
      include_attachments: zip_options[:include_attachments],
      pdf_only: zip_options[:pdf_only]
    )
    filename = archive.filename
    disposition = "attachment"
    record_zip_download_access_log(version, filename)

    send_data(
      archive.to_binary,
      type: "application/zip",
      disposition:
    )
    response.headers["Content-Disposition"] = ContentDispositionFilename.new(filename, disposition:).header
  end

  private

  def zip_options
    {
      zip_path_mode: params[:zip_path_mode].presence_in(%w[source_path document_title]) || "document_title",
      include_markdown_sources: boolean_param(:include_markdown_sources, default: true),
      include_attachments: boolean_param(:include_attachments, default: true),
      pdf_only: boolean_param(:pdf_only, default: false)
    }
  end

  def boolean_param(key, default:)
    return default if params[key].nil?

    ActiveModel::Type::Boolean.new.cast(params[key])
  end
end
