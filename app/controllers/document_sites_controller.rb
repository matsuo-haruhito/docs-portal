class DocumentSitesController < BaseController
  before_action :set_version
  skip_after_action :verify_same_origin_request, only: :show

  def show
    site_path = params[:site_path].presence || @version.site_build_path
    renderer = DocusaurusSiteRenderer.new(
      version: @version,
      view_context: view_context,
      current_document_version: @version,
      project: @version.document.project,
      user: current_user
    )
    file_path = renderer.file_response_path(site_path)

    if html_file?(file_path)
      record_view_access_log(site_path, @version)
      render html: renderer.render_html(site_path)
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
end
