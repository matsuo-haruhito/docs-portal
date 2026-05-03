class ProjectDocumentZipsController < BaseController
  def create
    project = Project.find_by!(code: params[:project_code])
    require_project_access!(project)

    versions = selected_versions(project)
    raise ApplicationError::BadRequest, "No documents selected" if versions.empty?

    archive = DocumentVersionsZipBuilder.new(
      versions:,
      user: current_user,
      filename: "#{project.code}-documents.zip"
    )

    versions.each do |version|
      record_zip_download_access_log(version, archive.filename)
    end

    send_data(
      archive.to_binary,
      filename: archive.filename,
      type: "application/zip",
      disposition: "attachment"
    )
  end

  private

  def selected_versions(project)
    ids = Array(params[:document_ids]).reject(&:blank?)
    return [] if ids.empty?

    project.documents
      .accessible_to(current_user)
      .where(id: ids)
      .includes(:latest_version)
      .filter_map(&:latest_version)
      .select { _1.viewable_by?(current_user) }
  end
end
