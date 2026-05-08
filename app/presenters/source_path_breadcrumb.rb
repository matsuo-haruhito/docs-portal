class SourcePathBreadcrumb
  Crumb = Data.define(:label, :path, :url)

  def initialize(document:, version:, project:)
    @document = document
    @version = version
    @project = project
  end

  def crumbs
    return [] unless source_path.present?

    [project_crumb, *directory_crumbs, document_crumb]
  end

  private

  attr_reader :document, :version, :project

  def source_path
    @source_path ||= version&.source_relative_path.presence || version&.source_directory.presence
  end

  def project_crumb
    Crumb.new(
      label: project.name,
      path: nil,
      url: Rails.application.routes.url_helpers.project_path(project)
    )
  end

  def directory_crumbs
    directory = version.source_directory.presence || Pathname.new(source_path).dirname.to_s
    return [] if directory.blank? || directory == "."

    segments = directory.split("/").reject(&:blank?)
    segments.each_with_index.map do |segment, index|
      path = segments.first(index + 1).join("/")
      Crumb.new(
        label: segment,
        path:,
        url: Rails.application.routes.url_helpers.project_documents_path(project, q: path)
      )
    end
  end

  def document_crumb
    Crumb.new(
      label: version.source_file_name.presence || document.title,
      path: version.source_relative_path,
      url: Rails.application.routes.url_helpers.project_document_path(project, document.slug)
    )
  end
end
