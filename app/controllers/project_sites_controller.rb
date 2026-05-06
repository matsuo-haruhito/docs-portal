class ProjectSitesController < BaseController
  before_action :set_project
  before_action :set_build_version
  skip_after_action :verify_same_origin_request, only: :show

  def show
    site_path = params[:site_path].presence || @build_version&.html_view_site_path
    renderer = project_site_renderer(site_path, embedded: embedded_request?)
    file_path = renderer.file_response_path(site_path)

    if html_file?(file_path)
      render_html_or_shell(renderer, site_path)
    else
      send_file file_path, disposition: "inline", type: Rack::Mime.mime_type(file_path.extname, "application/octet-stream")
    end
  end

  private

  def set_project
    @project = Project.find_by!(code: params[:project_code] || params[:code])
    require_project_access!(@project)
    return if require_consent!(target: @project, timing: :first_view)
  end

  def set_build_version
    @build_version =
      if params[:version_id].present?
        DocumentVersion
          .joins(:document)
          .where(documents: { project_id: @project.id })
          .find_by(public_id: params[:version_id])
      else
        @project.default_site_version_for(current_user)
      end

    raise ActiveRecord::RecordNotFound, "Project site build not found" unless @build_version

    require_document_version_view_access!(@build_version)
  end

  def project_site_renderer(site_path, embedded:)
    @current_document_version = resolve_document_version_for_page(site_path)
    @current_document_version ||= @build_version if current_page_matches_build_version?(site_path)

    DocusaurusSiteRenderer.new(
      version: @build_version,
      view_context: view_context,
      current_document_version: @current_document_version,
      project: @project,
      user: current_user,
      embedded:,
      document_version_resolver: ->(resolved_site_path) { resolve_document_version_for_page(resolved_site_path) },
      site_url_builder: lambda do |resolved_site_path, version_for_url|
        project_site_path(@project, site_path: resolved_site_path, version_id: version_for_url.public_id, embedded: embedded ? "1" : nil)
      end
    )
  end

  def render_html_or_shell(renderer, site_path)
    version_for_page = @current_document_version || @build_version
    require_document_version_view_access!(version_for_page)

    if embedded_request?
      record_view_access_log(site_path, version_for_page)
      render html: renderer.render_html(site_path)
    else
      @site_viewer_project = @project
      @site_viewer_document = version_for_page.document
      @site_viewer_version = version_for_page
      @site_viewer_iframe_src = project_site_path(@project, site_path:, version_id: version_for_page.public_id, embedded: "1")
      @site_viewer_back_path = project_document_path(@project, @site_viewer_document.slug)
      render "shared/site_viewer"
    end
  end

  def embedded_request?
    ActiveModel::Type::Boolean.new.cast(params[:embedded])
  end

  def current_page_matches_build_version?(site_path)
    normalized_path = DocumentVersion.normalize_site_page_path(site_path.presence || @build_version.html_view_site_path)
    build_path = @build_version.normalized_html_view_site_path

    normalized_path == build_path || normalized_path.start_with?("#{build_path}/")
  end

  def resolve_document_version_for_page(site_path)
    normalized_path = DocumentVersion.normalize_site_page_path(site_path.presence || @build_version.html_view_site_path)
    candidates = @project.documents.includes(:document_versions).flat_map(&:document_versions)
      .select { _1.version_label == @build_version.version_label && _1.rendered_site_available? }

    candidates
      .select do |version|
        candidate_path = version.normalized_html_view_site_path
        normalized_path == candidate_path || normalized_path.start_with?("#{candidate_path}/")
      end
      .max_by { _1.normalized_html_view_site_path.length }
  end

  def html_file?(file_path)
    file_path.extname == ".html"
  end
end
