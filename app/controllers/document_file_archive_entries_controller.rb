class DocumentFileArchiveEntriesController < BaseController
  def preview
    @document_file = DocumentFile.find_by!(public_id: params[:public_id])
    require_document_version_view_access!(@document_file.document_version)
    raise ApplicationError::Forbidden unless @document_file.deliverable_after_scan?(current_user)
    return if require_consent!(target: @document_file, timing: :first_view)

    record_file_view_access_log(@document_file)
    assign_context

    @entry_preview = DocumentFileArchiveEntryPreview.new(file: @document_file, entry_path: params[:entry_path]).call

    render :preview, status: @entry_preview.previewable? ? :ok : :unprocessable_entity
  end

  def download
    document_file = DocumentFile.find_by!(public_id: params[:public_id])
    require_document_file_download_access!(document_file)
    raise ApplicationError::Forbidden unless document_file.deliverable_after_scan?(current_user)
    return if require_consent!(target: document_file, timing: :download)

    entry_download = DocumentFileArchiveEntryDownload.new(file: document_file, entry_path: params[:entry_path]).call

    unless entry_download.downloadable?
      render plain: entry_download.reason.presence || "Archive entry download is not available", status: :unprocessable_entity
      return
    end

    record_download_access_log(document_file)
    send_data(
      entry_download.data,
      filename: entry_download.filename,
      type: entry_download.content_type,
      disposition: "attachment"
    )
  end

  private

  def assign_context
    @document_version = @document_file.document_version
    @document = @document_version.document
    @project = @document.project
  end
end
