class ProjectSitesController < BaseController
  EMBEDDED_VIEWER_HEIGHT_MESSAGE = "docs-portal:site-viewer-height".freeze

  before_action :set_project
  before_action :set_build_version
  skip_after_action :verify_same_origin_request, only: :show

  def show
    site_path = params[:site_path].presence || @build_version&.html_view_site_path

    if asset_path?(site_path)
      file_path = asset_file_response_path(site_path)
      return send_site_file(file_path, cacheable: true)
    end

    path_history_resolution = resolve_project_site_path_history(site_path)
    return redirect_to_project_site_canonical_path(path_history_resolution) if path_history_resolution&.moved?
    return redirect_terminal_project_site_history_to_reader(path_history_resolution) if path_history_resolution&.terminal? && !embedded_request?

    set_terminal_history_response_headers(path_history_resolution) if path_history_resolution&.terminal?

    render_site_path = renderable_site_path(site_path, path_history_resolution)
    renderer = project_site_renderer(render_site_path, embedded: embedded_request?)
    file_path = renderer.file_response_path(render_site_path)

    if html_file?(file_path)
      render_html_or_shell(renderer, render_site_path)
    else
      send_site_file(file_path)
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

  def resolve_project_site_path_history(site_path)
    return unless @build_version&.document

    DocumentPathHistoryResolver.new(
      document: @build_version.document,
      requested_site_path: site_path,
      canonical_version: @build_version,
      candidate_versions: @build_version.document.document_versions.select { _1.viewable_by?(current_user) }
    ).call
  end

  def redirect_to_project_site_canonical_path(path_history_resolution)
    redirect_to project_site_path(
      @project,
      site_path: path_history_resolution.canonical_path,
      version_id: path_history_resolution.canonical_version.public_id,
      previous_site_path: path_history_resolution.requested_path,
      embedded: embedded_request? ? "1" : nil
    ), status: :found
  end

  def redirect_terminal_project_site_history_to_reader(path_history_resolution)
    redirect_to project_document_path(
      @project,
      path_history_resolution.canonical_version.document.slug,
      version_id: path_history_resolution.canonical_version.public_id,
      site_path: path_history_resolution.canonical_path,
      terminal_site_path: path_history_resolution.requested_path
    )
  end

  def set_terminal_history_response_headers(path_history_resolution)
    response.headers["X-Docs-Portal-History-Status"] = path_history_resolution.status.to_s
    response.headers["X-Docs-Portal-History-Requested-Path"] = path_history_resolution.requested_path.to_s
    response.headers["X-Docs-Portal-History-Canonical-Path"] = path_history_resolution.canonical_path.to_s
  end

  def renderable_site_path(site_path, path_history_resolution)
    return path_history_resolution.canonical_path if path_history_resolution&.terminal? && embedded_request?

    site_path
  end

  def render_html_or_shell(renderer, site_path)
    version_for_page = @current_document_version || @build_version
    require_document_version_view_access!(version_for_page)
    record_view_access_log(site_path, version_for_page)

    if embedded_request?
      render html: decorate_embedded_site_html(renderer.render_html(site_path), version: version_for_page, site_path:)
    elsif version_for_page.document.present?
      reader_params = { version_id: version_for_page.public_id }
      reader_params[:site_path] = site_path if site_path.present?
      reader_params[:previous_site_path] = params[:previous_site_path] if params[:previous_site_path].present?
      reader_params[:terminal_site_path] = params[:terminal_site_path] if params[:terminal_site_path].present?
      redirect_to project_document_path(@project, version_for_page.document.slug, reader_params)
    else
      @site_viewer_project = @project
      @site_viewer_document = version_for_page.document
      @site_viewer_version = version_for_page
      @site_viewer_iframe_src = project_site_path(@project, site_path:, version_id: version_for_page.public_id, embedded: "1")
      @site_viewer_back_path = project_document_path(@project, @site_viewer_document.slug)
      render "shared/site_viewer"
    end
  end

  def decorate_embedded_site_html(html, version:, site_path:)
    document = Nokogiri::HTML.parse(html.to_s)
    body = document.at_css("body")
    return html if body.blank?

    body["data-docs-portal-preview-context-key"] = preview_table_context_key(version:, site_path:)
    inject_embedded_viewer_height_sync!(document)
    document.to_html.html_safe
  rescue StandardError
    html
  end

  def inject_embedded_viewer_height_sync!(document)
    body = document.at_css("body")
    return if body.blank?
    return if document.at_css("script[data-docs-portal-embedded-height-sync]").present?

    body["data-docs-portal-embedded-viewer"] = "true"

    script = Nokogiri::XML::Node.new("script", document)
    script["data-docs-portal-embedded-height-sync"] = "true"
    script.content = <<~JS
      (() => {
        if (window.__docsPortalEmbeddedHeightSyncReady) return
        window.__docsPortalEmbeddedHeightSyncReady = true

        const messageType = "#{EMBEDDED_VIEWER_HEIGHT_MESSAGE}"

        const collectHeight = () => {
          const body = document.body
          const root = document.documentElement
          const height = Math.max(
            body?.scrollHeight || 0,
            body?.offsetHeight || 0,
            root?.scrollHeight || 0,
            root?.offsetHeight || 0,
            root?.clientHeight || 0
          )
          return Math.ceil(height)
        }

        const postHeight = () => {
          try {
            const height = collectHeight()
            if (height <= 0 || !window.parent || window.parent === window) return
            window.parent.postMessage({ type: messageType, height }, window.location.origin)
          } catch (_error) {
          }
        }

        const schedulePostHeight = () => {
          window.requestAnimationFrame(() => {
            window.requestAnimationFrame(postHeight)
          })
        }

        if (document.readyState === "complete") {
          schedulePostHeight()
        } else {
          window.addEventListener("load", schedulePostHeight, { once: true })
        }

        document.addEventListener("readystatechange", schedulePostHeight)
        window.addEventListener("resize", schedulePostHeight)

        if (window.ResizeObserver) {
          const resizeObserver = new ResizeObserver(schedulePostHeight)
          resizeObserver.observe(document.documentElement)
          if (document.body) resizeObserver.observe(document.body)
        } else if (window.MutationObserver && document.body) {
          const mutationObserver = new MutationObserver(schedulePostHeight)
          mutationObserver.observe(document.body, {
            childList: true,
            subtree: true,
            attributes: true,
            characterData: true
          })
        }

        Array.from(document.images || []).forEach((image) => {
          if (image.complete) return
          image.addEventListener("load", schedulePostHeight, { once: true })
        })

        schedulePostHeight()
      })()
    JS
    body.add_child(script)
  end

  def preview_table_context_key(version:, site_path:)
    normalized_site_path = DocumentVersion.normalize_site_page_path(site_path.presence || version.html_view_site_path)
    "document_version:#{version.public_id}:#{normalized_site_path}"
  end

  def asset_path?(site_path)
    site_path.to_s.start_with?("assets/")
  end

  def asset_file_response_path(site_path)
    DocusaurusSiteRenderer.new(
      version: @build_version,
      view_context: view_context
    ).file_response_path(site_path)
  end

  def send_site_file(file_path, cacheable: false)
    if webpack_runtime_file?(file_path)
      send_rewritten_webpack_runtime(file_path, cacheable:)
    else
      set_private_immutable_asset_cache! if cacheable
      send_file file_path, disposition: "inline", type: Rack::Mime.mime_type(file_path.extname, "application/octet-stream")
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
    body = body.gsub(/([A-Za-z_$][\w$]*\.p)\s*=\s*["']\/["']/, "\\1=#{site_asset_public_path.dump}")
    asset_query = site_asset_query_suffix
    return body if asset_query.blank?

    body.gsub(/([A-Za-z_$][\w$]*\.p\s*\+\s*[A-Za-z_$][\w$]*\.u\([^)]*\))/, "\\1+#{asset_query.dump}")
  end

  def site_asset_public_path
    placeholder = "__docs_portal_asset__"
    project_site_path(@project, site_path: placeholder).delete_suffix(placeholder)
  end

  def site_asset_query_suffix
    query = Rack::Utils.build_query(
      {
        embedded: embedded_request? ? "1" : nil,
        version_id: @build_version.public_id
      }.compact
    )
    query.present? ? "?#{query}" : ""
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