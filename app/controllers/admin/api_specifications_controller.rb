class Admin::ApiSpecificationsController < Admin::BaseController
  CODEBLOCK_DRY_RUN_MAX_BYTES = 12_000
  HTTP_METHODS = %w[GET POST PUT PATCH DELETE HEAD OPTIONS].freeze

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

  def codeblock_dry_run
    result = api_codeblock_dry_run_result(
      codeblock: params[:codeblock].to_s,
      codeblock_id: params[:codeblock_id].to_s
    )

    render json: result, status: result[:status] == "error" ? :unprocessable_entity : :ok
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

  def api_codeblock_dry_run_result(codeblock:, codeblock_id:)
    if codeblock.bytesize > CODEBLOCK_DRY_RUN_MAX_BYTES
      return api_codeblock_dry_run_payload(
        status: "error",
        message: "http codeblock が大きすぎるため dry-run validation を実行できません。",
        target_api: "未判定",
        details: ["codeblock を短い代表 request sample に分けてください。"],
        codeblock_id:
      )
    end

    request_line = first_http_request_line(codeblock)
    if request_line.blank?
      return api_codeblock_dry_run_payload(
        status: "error",
        message: "http request line を検出できませんでした。",
        target_api: "未判定",
        details: ["例: GET /api/internal/file_uploads HTTP/1.1 のような行を含めてください。"],
        codeblock_id:
      )
    end

    method, path = request_line.split(/\s+/, 3)
    method = method.to_s.upcase

    unless HTTP_METHODS.include?(method)
      return api_codeblock_dry_run_payload(
        status: "error",
        message: "サポート対象外の HTTP method です。",
        target_api: request_line,
        details: ["dry-run validation は #{HTTP_METHODS.join(', ')} の request sample だけを対象にします。"],
        codeblock_id:
      )
    end

    if external_url_path?(path)
      return api_codeblock_dry_run_payload(
        status: "error",
        message: "外部 URL への request sample は dry-run 対象外です。",
        target_api: "#{method} #{path}",
        details: ["外部 API 送信を避けるため、path-only の internal API sample に限定しています。"],
        codeblock_id:
      )
    end

    unless path.to_s.start_with?("/")
      return api_codeblock_dry_run_payload(
        status: "error",
        message: "path-only の internal API sample ではありません。",
        target_api: "#{method} #{path}".strip,
        details: ["dry-run validation は /api/... のような同一アプリ内 path だけを対象にします。"],
        codeblock_id:
      )
    end

    api_codeblock_dry_run_payload(
      status: "ok",
      message: "dry-run validation は成功しました。apply / import / 外部送信は実行していません。",
      target_api: "#{method} #{path}",
      details: [
        "対象 API: #{method} #{path}",
        "実行ユーザー: #{current_user.display_name}",
        "dry-run only: request sample の形式確認だけを行いました。"
      ],
      codeblock_id:
    )
  end

  def api_codeblock_dry_run_payload(status:, message:, target_api:, details:, codeblock_id:)
    {
      status:,
      dry_run: true,
      destructive: false,
      action_kind: "admin_api_spec.http_codeblock_dry_run",
      target_viewer: "admin_api_specification",
      target_api:,
      codeblock_id: codeblock_id.presence || "unknown",
      user: current_user.display_name,
      message:,
      details:
    }
  end

  def first_http_request_line(codeblock)
    codeblock.each_line.map(&:strip).find do |line|
      line.present? && !line.start_with?("#", "//")
    end
  end

  def external_url_path?(path)
    path.to_s.start_with?("http://", "https://", "//")
  end

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
