class DocumentFilesController < BaseController
  def show
    file = DocumentFile.find_by!(public_id: params[:public_id])
    require_document_file_download_access!(file)

    record_download_access_log(file)

    unless File.exist?(file.absolute_path)
      render plain: "File not found", status: :not_found
      return
    end

    send_file(
      file.absolute_path,
      filename: file.file_name,
      disposition: disposition_for(file),
      type: file.effective_content_type
    )
  end

  private

  def disposition_for(file)
    case params[:disposition]
    when "inline"
      file.inline_disposition? ? "inline" : "attachment"
    when "download"
      "attachment"
    else
      file.inline_disposition? ? "inline" : "attachment"
    end
  end
end
