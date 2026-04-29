require "nokogiri"

class DocusaurusSiteRenderer
  def initialize(version:, view_context:)
    @version = version
    @view_context = view_context
  end

  def render_entry_html
    render_html(@version.site_entry_relative_path)
  end

  def render_html(site_path)
    absolute_path = resolve_absolute_path(site_path)
    rewrite_html(File.read(absolute_path))
  end

  def resolve_absolute_path(site_path)
    return @version.site_entry_absolute_path if site_path.blank?

    relative_path = normalize_site_path(site_path)
    legacy_path = @version.legacy_html_absolute_path
    if relative_path == @version.site_build_path && legacy_path.exist?
      return legacy_path
    end

    candidate = @version.site_root_absolute_path.join(relative_path)
    return candidate if candidate.exist? && candidate.file?

    html_candidate = @version.site_root_absolute_path.join("#{relative_path}.html")
    return html_candidate if html_candidate.exist? && html_candidate.file?

    index_candidate = @version.site_root_absolute_path.join(relative_path, "index.html")
    return index_candidate if index_candidate.exist? && index_candidate.file?

    shared_build_candidate = shared_build_path(relative_path)
    return shared_build_candidate if shared_build_candidate&.exist? && shared_build_candidate.file?

    raise ActiveRecord::RecordNotFound, "Site page not found: #{site_path}"
  end

  def file_response_path(site_path)
    resolve_absolute_path(site_path)
  end

  private

  def normalize_site_path(site_path)
    cleaned = Pathname.new(site_path.to_s.delete_prefix("/")).cleanpath.to_s
    raise ActiveRecord::RecordNotFound, "Invalid site path" if cleaned.start_with?("../")

    cleaned
  end

  def shared_build_path(relative_path)
    build_root = Rails.root.join("docusaurus", "build")
    return unless build_root.exist?

    candidate = build_root.join(relative_path)
    return candidate if candidate.exist?

    html_candidate = build_root.join("#{relative_path}.html")
    return html_candidate if html_candidate.exist?

    index_candidate = build_root.join(relative_path, "index.html")
    return index_candidate if index_candidate.exist?

    nil
  end

  def rewrite_html(html)
    document = Nokogiri::HTML5.parse(html)

    rewrite_url_attributes(document, "a", "href")
    rewrite_url_attributes(document, "link", "href")
    rewrite_url_attributes(document, "script", "src")
    rewrite_url_attributes(document, "img", "src")

    document.to_html.html_safe
  end

  def rewrite_url_attributes(document, selector, attribute)
    document.css(selector).each do |node|
      value = node[attribute]
      next if value.blank?

      rewritten = rewrite_url(value)
      node[attribute] = rewritten if rewritten
    end
  end

  def rewrite_url(value)
    return if value.start_with?("http://", "https://", "//", "mailto:", "tel:", "#")
    return value unless value.start_with?("/")

    @view_context.site_document_version_path(@version, site_path: value.delete_prefix("/"))
  end
end
