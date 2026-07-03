class Admin::ApiSpecificationsController < Admin::BaseController
  before_action :require_admin_only!
  skip_after_action :verify_same_origin_request, only: :site

  READ_ONLY_MAINTENANCE_ENV = "READ_ONLY_MAINTENANCE"

  def show
    @api_specification_page = Admin::ApiSpecificationPage.new(view_context:)
    @api_specification_read_only_maintenance = read_only_maintenance_mode?
    @api_specification_build_enqueued = @api_specification_read_only_maintenance ? false : @api_specification_page.enqueue_build_if_stale!
  end

  def retry_build
    if read_only_maintenance_mode?
      redirect_to admin_api_specification_path, alert: maintenance_retry_build_message
      return
    end

    page = Admin::ApiSpecificationPage.new(view_context:)

    if page.build_requested?
      redirect_to admin_api_specification_path, notice: "API仕様ページの Docusaurus build はすでに実行中です。完了後に再読み込みしてください。"
      return
    end

    build_status = page.build_status
    unless %i[failed stale].include?(build_status.state)
      redirect_to admin_api_specification_path, alert: "現在の状態では API仕様ページの手動 build 再実行は不要です。"
      return
    end

    page.enqueue_manual_build!
    redirect_to admin_api_specification_path, notice: "API仕様ページの Docusaurus build を再実行します。完了後に再読み込みしてください。"
  end

  def site
    page = Admin::ApiSpecificationPage.new(view_context:)
    page.enqueue_build_if_stale! unless read_only_maintenance_mode?
    raise ActiveRecord::RecordNotFound unless page.available?

    site_path = params[:site_path].presence || page.site_path
    renderer = page.renderer
    file_path = renderer.file_response_path(site_path)
    raise ActiveRecord::RecordNotFound unless site_file_response_allowed?(file_path)

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

  def site_file_response_allowed?(file_path)
    absolute_file_path = file_path.expand_path
    build_root = Rails.root.join("docusaurus", "build").expand_path

    absolute_file_path.to_s.start_with?("#{build_root}/") && absolute_file_path.file?
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

  def read_only_maintenance_mode?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(READ_ONLY_MAINTENANCE_ENV, nil))
  end

  def maintenance_retry_build_message
    "メンテナンス中のためAPI仕様ページの build 再要求は停止しています。API仕様 viewer と生成済み HTML の確認は継続できます。"
  end
end
