class DocumentFilesController < BaseController
  def show
    file = DocumentFile.find(params[:id])
    version = file.document_version
    authorize file

    AccessLog.create!(
      user: current_user,
      company: current_user.company,
      project: version.document.project,
      document: version.document,
      document_version: version,
      action_type: :download,
      target_type: "file",
      target_name: file.file_name,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      accessed_at: Time.current
    )

    unless File.exist?(file.absolute_path)
      render plain: "File not found", status: :not_found
      return
    end

    send_file(
      file.absolute_path,
      filename: file.file_name,
      disposition: (file.inline_disposition? ? "inline" : "attachment"),
      type: file.effective_content_type
    )
  end
end
