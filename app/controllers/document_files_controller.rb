class DocumentFilesController < BaseController
  def show
    file = DocumentFile.find_by!(public_id: params[:public_id])
    require_document_file_download_access!(file)

    file_path = file.absolute_path
    disposition = disposition_for(file)

    unless File.exist?(file_path)
      render plain: "File not found", status: :not_found
      return
    end

    record_download_access_log(file)

    if disposition == "inline" && file.text_previewable?
      response.headers["Content-Disposition"] = DocumentFileContentDisposition.new(file, disposition:).header
      @document_file = file
      @document_version = file.document_version
      @document = @document_version.document
      @project = @document.project
      @preview_lines = File.read(file_path, encoding: "UTF-8").lines(chomp: true)
      render :show_text_preview
      return
    end

    send_file(
      file_path,
      disposition:,
      type: file.effective_content_type
    )
    response.headers["Content-Disposition"] = DocumentFileContentDisposition.new(file, disposition:).header
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
