class ProjectDocumentZipsController < BaseController
  READ_ONLY_MAINTENANCE_ENV = "READ_ONLY_MAINTENANCE"

  def create
    project = Project.find_by!(code: params[:project_code])
    require_project_access!(project)
    return if require_consent!(target: project, timing: :download, return_to: project_documents_path(project))

    if read_only_maintenance_mode?
      redirect_to project_documents_path(project), alert: maintenance_document_zip_message
      return
    end

    versions = selected_versions(project)
    raise ApplicationError::BadRequest, "No documents selected" if versions.empty?

    archive = DocumentVersionsZipBuilder.new(
      versions:,
      user: current_user,
      filename: zip_filename(project),
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
    documents = filtered_documents(project)

    unless selecting_matching_documents?
      ids = Array(params[:document_ids]).reject(&:blank?)
      return [] if ids.empty?

      documents = documents.where(id: ids)
    end

    source_path = normalized_source_path
    documents = documents.select { |document| document_in_source_path?(document, source_path) } if source_path.present?

    documents
      .select { _1.downloadable_by?(current_user) }
      .filter_map(&:latest_version)
      .select { _1.viewable_by?(current_user) }
  end

  def filtered_documents(project)
    ProjectDocumentFilter.new(project:, user: current_user, filters: document_filter_params)
      .call
      .includes(:latest_version)
  end

  def document_filter_params
    params.to_unsafe_h.symbolize_keys.slice(*ProjectDocumentFilter::FILTER_KEYS)
  end

  def selecting_matching_documents?
    params[:selection_scope] == "matching"
  end

  def document_in_source_path?(document, source_path)
    version = document.latest_version
    return false unless version

    source_directory = normalize_path(version.source_directory)
    source_relative_path = normalize_path(version.source_relative_path)

    source_directory == source_path ||
      source_directory.start_with?("#{source_path}/") ||
      source_relative_path.start_with?("#{source_path}/")
  end

  def zip_filename(project)
    source_path = normalized_source_path
    return "#{project.code}-documents.zip" if source_path.blank?

    folder_name = source_path.split("/").last.presence || "folder"
    "#{project.code}-#{folder_name}-documents.zip"
  end

  def normalized_source_path
    @normalized_source_path ||= normalize_path(params[:source_path])
  end

  def normalize_path(value)
    value.to_s.tr("\\", "/").split("/").reject(&:blank?).join("/")
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

  def read_only_maintenance_mode?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(READ_ONLY_MAINTENANCE_ENV, nil))
  end

  def maintenance_document_zip_message
    "メンテナンス中のため文書ZIP生成は停止しています。文書閲覧と個別添付の確認は継続できます。"
  end
end
