class DocumentFilesController < BaseController
  def show
    file = DocumentFile.find_by!(public_id: params[:public_id])
    require_document_file_download_access!(file)

    file_path = file.absolute_path

    unless File.exist?(file_path)
      render plain: "File not found", status: :not_found
      return
    end

    record_download_access_log(file)

    send_file(
      file_path,
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
