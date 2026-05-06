class ProjectDocumentZipsController < BaseController
  def create
    project = Project.find_by!(code: params[:project_code])
    require_project_access!(project)
    return if require_consent!(target: project, timing: :download, return_to: project_documents_path(project))

    versions = selected_versions(project)
    raise ApplicationError::BadRequest, "No documents selected" if versions.empty?

    archive = DocumentVersionsZipBuilder.new(
      versions:,
      user: current_user,
      filename: "#{project.code}-documents.zip",
      zip_path_mode: zip_options[:zip_path_mode],
      include_markdown_sources: zip_options[:include_markdown_sources],
      include_attachments: zip_options[:include_attachments],
      pdf_only: zip_options[:pdf_only]
    )
    disposition = "attachment"

    versions.each do |version|
      record_zip_download_access_log(version, archive.filename)
    end

    send_data(
      archive.to_binary,
      type: "application/zip",
      disposition:
    )
    response.headers["Content-Disposition"] = ContentDispositionFilename.new(archive.filename, disposition:).header
  end

  private

  def selected_versions(project)
    ids = Array(params[:document_ids]).reject(&:blank?)
    return [] if ids.empty?

    project.documents
      .accessible_to(current_user)
      .where(id: ids)
      .includes(:latest_version)
      .select { _1.downloadable_by?(current_user) }
      .filter_map(&:latest_version)
      .select { _1.viewable_by?(current_user) }
  end

  def zip_options
    @zip_options ||= {
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
