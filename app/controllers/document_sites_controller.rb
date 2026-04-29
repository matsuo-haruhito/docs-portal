class DocumentSitesController < BaseController
  before_action :set_version

  def show
    site_path = params[:site_path].presence || @version.site_build_path
    renderer = DocusaurusSiteRenderer.new(version: @version, view_context: view_context)
    file_path = renderer.file_response_path(site_path)

    if html_file?(file_path)
      log_page_view!(site_path)
      render html: renderer.render_html(site_path)
    else
      send_file file_path, disposition: "inline", type: Rack::Mime.mime_type(file_path.extname)
    end
  end

  private

  def set_version
    @version = DocumentVersion.find(params[:id])
    require_document_version_view_access!(@version)
  end

  def html_file?(file_path)
    file_path.extname == ".html"
  end

  def log_page_view!(site_path)
    AccessLog.create!(
      user: current_user,
      company: current_user.company,
      project: @version.document.project,
      document: @version.document,
      document_version: @version,
      action_type: :view,
      target_type: "page",
      target_name: site_path.to_s,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      accessed_at: Time.current
    )
  end
end
