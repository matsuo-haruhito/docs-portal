require "nokogiri"

class DocusaurusSiteRenderer
  def initialize(
    version:,
    view_context:,
    current_document_version: nil,
    project: nil,
    user: nil,
    document_version_resolver: nil,
    site_url_builder: nil
  )
    @version = version
    @view_context = view_context
    @current_document_version = current_document_version
    @project = project
    @user = user
    @document_version_resolver = document_version_resolver
    @site_url_builder = site_url_builder || lambda { |site_path, version_for_url|
      @view_context.site_document_version_path(version_for_url, site_path: site_path)
    }
  end

  def render_entry_html
    render_html(@version.site_entry_relative_path)
  end

  def render_html(site_path)
    absolute_path = resolve_absolute_path(site_path)
    rewrite_html(File.read(absolute_path), absolute_path:)
  end

  def resolve_absolute_path(site_path)
    return @version.site_entry_absolute_path if site_path.blank?

    legacy_path = @version.legacy_html_absolute_path
    candidate_site_paths(site_path).each do |relative_path|
      if relative_path == @version.site_build_path && legacy_path.exist?
        return verified_file_path(legacy_path, @version.site_root_absolute_path)
      end

      candidate = @version.site_root_absolute_path.join(relative_path)
      verified_candidate = verified_file_path(candidate, @version.site_root_absolute_path)
      return verified_candidate if verified_candidate

      html_candidate = @version.site_root_absolute_path.join("#{relative_path}.html")
      verified_html_candidate = verified_file_path(html_candidate, @version.site_root_absolute_path)
      return verified_html_candidate if verified_html_candidate

      index_candidate = @version.site_root_absolute_path.join(relative_path, "index.html")
      verified_index_candidate = verified_file_path(index_candidate, @version.site_root_absolute_path)
      return verified_index_candidate if verified_index_candidate

      shared_build_candidate = shared_build_path(relative_path)
      return shared_build_candidate if shared_build_candidate
    end

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

  def candidate_site_paths(site_path)
    cleaned = normalize_site_path(site_path)
    variants = [cleaned]

    if cleaned.match?(/\.(md|markdown)\z/i)
      without_markdown_ext = cleaned.sub(/\.(md|markdown)\z/i, "")
      variants << without_markdown_ext

      if cleaned.match?(%r{/(?:index|README)\.(md|markdown)\z}i)
        variants << cleaned.sub(%r{/(?:index|README)\.(md|markdown)\z}i, "")
      end
    end

    variants.uniq
  end

  def shared_build_path(relative_path)
    build_root = Rails.root.join("docusaurus", "build")
    return unless build_root.exist?

    candidate = build_root.join(relative_path)
    verified_candidate = verified_file_path(candidate, build_root)
    return verified_candidate if verified_candidate

    html_candidate = build_root.join("#{relative_path}.html")
    verified_html_candidate = verified_file_path(html_candidate, build_root)
    return verified_html_candidate if verified_html_candidate

    index_candidate = build_root.join(relative_path, "index.html")
    verified_index_candidate = verified_file_path(index_candidate, build_root)
    return verified_index_candidate if verified_index_candidate

    nil
  end

  def rewrite_html(html, absolute_path:)
    document = Nokogiri::HTML5.parse(html)

    filter_restricted_navigation_links!(document, absolute_path:)
    rewrite_url_attributes(document, "a", "href", absolute_path:)
    rewrite_url_attributes(document, "link", "href", absolute_path:)
    rewrite_url_attributes(document, "script", "src", absolute_path:)
    rewrite_url_attributes(document, "img", "src", absolute_path:)
    inject_portal_navigation!(document)
    inject_version_switcher!(document)

    document.to_html.html_safe
  end

  def rewrite_url_attributes(document, selector, attribute, absolute_path:)
    document.css(selector).each do |node|
      value = node[attribute]
      next if value.blank?

      rewritten = rewrite_url(value, absolute_path:)
      node[attribute] = rewritten if rewritten
    end
  end

  def rewrite_url(value, absolute_path:)
    relative_path = site_path_from_url(value, absolute_path:)
    return unless relative_path

    build_site_url(relative_path, @current_document_version || @version)
  end

  def resolve_relative_url(value, absolute_path)
    page_dir = relative_directory_for(absolute_path)
    cleaned = Pathname.new(page_dir.join(value)).cleanpath.to_s
    raise ActiveRecord::RecordNotFound, "Invalid site path" if cleaned.start_with?("../")

    cleaned
  end

  def site_path_from_url(value, absolute_path:)
    return if value.start_with?("http://", "https://", "//", "mailto:", "tel:", "#")

    if value.start_with?("/")
      value.delete_prefix("/")
    else
      resolve_relative_url(value, absolute_path)
    end
  end

  def relative_directory_for(absolute_path)
    root = if absolute_path.to_s.start_with?(@version.site_root_absolute_path.to_s + File::SEPARATOR)
      @version.site_root_absolute_path
    else
      Rails.root.join("docusaurus", "build")
    end

    Pathname.new(relative_path(absolute_path.dirname, root))
  end

  def relative_path(path, root)
    Pathname(path).relative_path_from(Pathname(root))
  end

  def verified_file_path(candidate, root)
    return unless candidate.exist? && candidate.file?

    root_realpath = root.realpath.to_s
    candidate_realpath = candidate.realpath.to_s
    return candidate if candidate_realpath == root_realpath
    return candidate if candidate_realpath.start_with?(root_realpath + File::SEPARATOR)

    raise ActiveRecord::RecordNotFound, "Site page not found"
  end

  def build_site_url(site_path, version_for_url)
    @site_url_builder.call(site_path, version_for_url)
  end

  def filter_restricted_navigation_links!(document, absolute_path:)
    return unless @document_version_resolver && @user

    document.css("nav a[href], aside a[href], .theme-doc-sidebar-menu a[href]").each do |node|
      site_path = site_path_from_url(node["href"], absolute_path:)
      next unless site_path

      linked_version = @document_version_resolver.call(site_path)
      next unless linked_version
      next if linked_version.viewable_by?(@user)

      node.ancestors("li").first&.remove || node.remove
    end
  end

  def inject_portal_navigation!(document)
    return unless @project

    container = Nokogiri::XML::Node.new("div", document)
    container["class"] = "portal-site-nav"

    project_link = Nokogiri::XML::Node.new("a", document)
    project_link["href"] = @view_context.project_path(@project)
    project_link.content = "ポータルへ戻る"
    container.add_child(project_link)

    if @current_document_version
      separator = Nokogiri::XML::Node.new("span", document)
      separator["class"] = "portal-site-nav-separator"
      separator.content = " / "
      container.add_child(separator)

      document_link = Nokogiri::XML::Node.new("a", document)
      document_link["href"] = @view_context.project_document_path(@project, @current_document_version.document.slug)
      document_link.content = @current_document_version.document.title
      container.add_child(document_link)
    end

    body = document.at_css("body")
    body&.children&.first ? body.children.first.add_previous_sibling(container) : body&.add_child(container)
  end

  def inject_version_switcher!(document)
    return unless @current_document_version

    versions = @current_document_version.document.document_versions
      .select { _1.viewable_by?(Current.user) }
      .sort_by(&:created_at)
      .reverse
    return if versions.size <= 1

    switcher = Nokogiri::XML::Node.new("details", document)
    switcher["class"] = "document-version-switcher"

    summary = Nokogiri::XML::Node.new("summary", document)
    summary.content = @current_document_version.version_label
    switcher.add_child(summary)

    list = Nokogiri::XML::Node.new("ul", document)
    versions.each do |version|
      item = Nokogiri::XML::Node.new("li", document)

      if version == @current_document_version
        item.content = version.version_label
      else
        link = Nokogiri::XML::Node.new("a", document)
        link["href"] = build_site_url(version.html_view_site_path, version)
        link.content = version.version_label
        item.add_child(link)
      end

      list.add_child(item)
    end

    switcher.add_child(list)

    body = document.at_css("body")
    body&.children&.first ? body.children.first.add_previous_sibling(switcher) : body&.add_child(switcher)
  end
end
