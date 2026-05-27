class DocumentSitesController < BaseController
  EMBEDDED_VIEWER_HEIGHT_MESSAGE = "docs-portal:site-viewer-height".freeze

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
        render html: decorate_embedded_site_html(renderer.render_html(site_path), version: resolved_version, site_path:)
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

  def embedded_request?
    ActiveModel::Type::Boolean.new.cast(params[:embedded])
  end
end
