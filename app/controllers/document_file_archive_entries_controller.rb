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

  private

  def assign_context
    @document_version = @document_file.document_version
    @document = @document_version.document
    @project = @document.project
  end
end
