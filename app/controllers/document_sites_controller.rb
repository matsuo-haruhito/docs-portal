class DocumentSitesController < BaseController
  before_action :set_version
  skip_after_action :verify_same_origin_request, only: :show

  def show
    site_path = params[:site_path].presence || @version.site_build_path
    resolved_version = @version
    renderer = DocusaurusSiteRenderer.new(
      version: @version,
      view_context: view_context,
      current_document_version: @version,
      project: @version.document.project,
      user: current_user,
      embedded: embedded_request?,
      site_url_builder: lambda do |resolved_site_path, version_for_url|
        site_document_version_path(version_for_url, site_path: resolved_site_path, embedded: embedded_request? ? "1" : nil)
      end
    )
    file_path = renderer.file_response_path(site_path)

    if html_file?(file_path)
      if embedded_request? || params[:site_path].blank?
        record_view_access_log(site_path, resolved_version)
        render html: renderer.render_html(site_path)
      else
        @site_viewer_project = @version.document.project
        @site_viewer_document = @version.document
        @site_viewer_version = resolved_version
        @site_viewer_iframe_src = site_document_version_path(@version, site_path:, embedded: "1")
        @site_viewer_back_path = project_document_path(@site_viewer_project, @site_viewer_document.slug)
        render "shared/site_viewer"
      end
    else
      send_file file_path, disposition: "inline", type: Rack::Mime.mime_type(file_path.extname, "application/octet-stream")
    end
  end

  private

  def set_version
    @version = DocumentVersion.find_by!(public_id: params[:public_id])
    require_document_version_view_access!(@version)
  end

  def html_file?(file_path)
    file_path.extname == ".html"
  end

  def embedded_request?
    ActiveModel::Type::Boolean.new.cast(params[:embedded])
  end
end
