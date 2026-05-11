class Admin::ApiSpecificationsController < Admin::BaseController
  before_action :require_admin_only!
  skip_after_action :verify_same_origin_request, only: :site

  def show
    @api_specification_page = Admin::ApiSpecificationPage.new(view_context:)
    @api_specification_build_enqueued = @api_specification_page.enqueue_build_if_stale!
  end

  def site
    page = Admin::ApiSpecificationPage.new(view_context:)
    page.enqueue_build_if_stale!
    raise ActiveRecord::RecordNotFound unless page.available?

    site_path = params[:site_path].presence || page.site_path
    renderer = page.renderer
    file_path = renderer.file_response_path(site_path)

    if asset_path?(site_path) || !html_file?(file_path)
      send_site_file(file_path, cacheable: asset_path?(site_path))
    else
      render html: renderer.render_html(site_path), layout: false
    end
  end

  private

  def asset_path?(site_path)
    site_path.to_s.start_with?("assets/")
  end

  def html_file?(file_path)
    file_path.extname == ".html"
  end

  def send_site_file(file_path, cacheable: false)
    if webpack_runtime_file?(file_path)
      send_rewritten_webpack_runtime(file_path, cacheable:)
    else
      set_private_immutable_asset_cache! if cacheable
      send_file file_path,
        disposition: "inline",
        type: Rack::Mime.mime_type(file_path.extname, "application/octet-stream")
    end
  end

  def webpack_runtime_file?(file_path)
    file_path.basename.to_s.start_with?("runtime~main.") && file_path.extname == ".js"
  end

  def send_rewritten_webpack_runtime(file_path, cacheable: false)
    body = rewrite_webpack_runtime_public_path(File.read(file_path))

    if cacheable
      set_private_immutable_asset_cache!
    else
      expires_now
      response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
      response.headers["Pragma"] = "no-cache"
      response.headers.delete("ETag")
      response.headers.delete("Last-Modified")
    end

    send_data body,
      disposition: "inline",
      type: Rack::Mime.mime_type(file_path.extname, "application/javascript")
  end

  def set_private_immutable_asset_cache!
    response.headers["Cache-Control"] = "private, max-age=31536000, immutable"
    response.headers.delete("Pragma")
  end

  def rewrite_webpack_runtime_public_path(body)
    body.gsub(/([A-Za-z_$][\w$]*\.p)\s*=\s*["']\/["']/, "\\1=#{site_asset_public_path.dump}")
  end

  def site_asset_public_path
    placeholder = "__docs_portal_asset__"
    site_admin_api_specification_path(site_path: placeholder).delete_suffix(placeholder)
  end
end
