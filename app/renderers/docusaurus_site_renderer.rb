require "base64"
require "nokogiri"
require "pathname"

class DocusaurusSiteRenderer
  MARKDOWN_EXTENSIONS_PATTERN = "md|markdown|mdx"

  def initialize(
    version:,
    view_context:,
    current_document_version: nil,
    project: nil,
    user: nil,
    embedded: false,
    document_version_resolver: nil,
    site_url_builder: nil
  )
    @version = version
    @view_context = view_context
    @current_document_version = current_document_version
    @project = project
    @user = user
    @embedded = embedded
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
    rewrite_html(File.read(absolute_path), absolute_path:, site_path:)
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

    if cleaned.match?(/\.(#{MARKDOWN_EXTENSIONS_PATTERN})\z/i)
      without_markdown_ext = cleaned.sub(/\.(#{MARKDOWN_EXTENSIONS_PATTERN})\z/i, "")
      variants << without_markdown_ext

      if cleaned.match?(%r{/(?:index|README)\.(#{MARKDOWN_EXTENSIONS_PATTERN})\z}i)
        variants << cleaned.sub(%r{/(?:index|README)\.(#{MARKDOWN_EXTENSIONS_PATTERN})\z}i, "")
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

  def rewrite_html(html, absolute_path:, site_path:)
    document = Nokogiri::HTML5.parse(html)

    filter_restricted_navigation_links!(document, absolute_path:)
    rewrite_url_attributes(document, "a", "href", absolute_path:)
    rewrite_url_attributes(document, "link", "href", absolute_path:)
    rewrite_url_attributes(document, "script", "src", absolute_path:)
    rewrite_url_attributes(document, "img", "src", absolute_path:)
    strip_embedded_docusaurus_chrome!(document) if @embedded
    inject_embedded_route_path!(document, site_path) if @embedded
    annotate_document_tables!(document, site_path)
    inject_portal_navigation!(document) unless @embedded
    inject_version_switcher!(document) unless @embedded
    inject_viewer_theme!(document)

    document.to_html.html_safe
  end

  def annotate_document_tables!(document, site_path)
    version_for_key = @current_document_version || @version
    normalized_site_path = stable_table_site_path(site_path)

    document.css("table").each.with_index(1) do |table, table_index|
      table_key = build_table_preference_key(version_for_key, normalized_site_path, table_index)
      wrapper = ensure_table_wrapper!(document, table)

      append_css_class(wrapper, "portal-doc-table-preference-wrapper")
      wrapper["data-docs-portal-table-wrapper"] = "true"
      wrapper["data-docs-portal-document-version"] = version_for_key.public_id.to_s
      wrapper["data-docs-portal-site-path"] = normalized_site_path
      wrapper["data-docs-portal-table-index"] = table_index.to_s
      wrapper["data-rails-table-preferences-table-key"] = table_key

      append_css_class(table, "portal-doc-preference-table")
      table["data-docs-portal-document-version"] = version_for_key.public_id.to_s
      table["data-docs-portal-site-path"] = normalized_site_path
      table["data-docs-portal-table-index"] = table_index.to_s
      table["data-rails-table-preferences-table-key"] = table_key
    end
  end

  def stable_table_site_path(site_path)
    DocumentVersion.normalize_site_page_path(site_path.presence || @version.html_view_site_path)
  end

  def stable_table_site_path_key(normalized_site_path)
    Base64.urlsafe_encode64(normalized_site_path.to_s, padding: false)
  end

  def build_table_preference_key(version_for_key, normalized_site_path, table_index)
    [
      "document-version",
      version_for_key.public_id,
      "site-path",
      stable_table_site_path_key(normalized_site_path),
      "table",
      table_index
    ].join(":")
  end

  def ensure_table_wrapper!(document, table)
    parent = table.parent
    return parent if parent&.element? && parent["data-docs-portal-table-wrapper"] == "true"

    wrapper = Nokogiri::XML::Node.new("div", document)
    table.replace(wrapper)
    wrapper.add_child(table)
    wrapper
  end

  def append_css_class(node, class_name)
    classes = node["class"].to_s.split
    return if classes.include?(class_name)

    node["class"] = (classes << class_name).join(" ")
  end

  def strip_embedded_docusaurus_chrome!(document)
    document.css(embedded_chrome_selectors.join(", ")).each(&:remove)

    document.css("main .row, .main-wrapper .row").each do |row|
      row["class"] = row["class"].to_s.split.reject { _1.start_with?("row") }.join(" ")
    end

    document.css("main .col, main [class*='col--'], article[class*='col--']").each do |node|
      node["class"] = node["class"].to_s.split.reject { _1 == "col" || _1.start_with?("col--") }.join(" ")
    end
  end

  def embedded_chrome_selectors
    [
      "nav.navbar",
      ".navbar",
      ".navbar-sidebar",
      ".navbar__items",
      ".theme-doc-breadcrumbs",
      ".theme-doc-sidebar-container",
      "aside.theme-doc-sidebar-container",
      "aside.theme-doc-toc-desktop",
      ".theme-doc-toc-desktop",
      ".theme-doc-toc-mobile",
      ".table-of-contents",
      ".theme-doc-footer",
      ".theme-edit-this-page",
      ".pagination-nav",
      "footer.footer",
      ".footer"
    ]
  end

  def inject_embedded_route_path!(document, site_path)
    head = document.at_css("head")
    return unless head

    script = Nokogiri::XML::Node.new("script", document)
    script.content = <<~JS
      (function() {
        var routePath = #{docusaurus_route_path(site_path).to_json};
        var suffix = window.location.search + window.location.hash;
        if (window.location.pathname !== routePath) {
          window.history.replaceState(window.history.state, "", routePath + suffix);
        }
      }());
    JS

    head.children.first ? head.children.first.add_previous_sibling(script) : head.add_child(script)
  end

  def docusaurus_route_path(site_path)
    "/#{DocumentVersion.normalize_site_page_path(site_path.presence || @version.html_view_site_path)}"
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
    return if external_or_anchor_url?(value)

    path_part, suffix = split_url_suffix(value)
    return if path_part.blank?

    relative_path = site_path_from_url(path_part, absolute_path:)
    return unless relative_path

    "#{build_site_url(relative_path, @current_document_version || @version)}#{suffix}"
  end

  def external_or_anchor_url?(value)
    value.start_with?("http://", "https://", "//", "mailto:", "tel:", "#")
  end

  def split_url_suffix(value)
    match = value.to_s.match(/\A([^?#]*)(.*)\z/)
    [match[1], match[2].to_s]
  end

  def resolve_relative_url(value, absolute_path)
    page_dir = relative_directory_for(absolute_path)
    cleaned = Pathname.new(page_dir.join(value)).cleanpath.to_s
    raise ActiveRecord::RecordNotFound, "Invalid site path" if cleaned.start_with?("../")

    cleaned
  end

  def site_path_from_url(value, absolute_path:)
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
    return if @user.internal?

    document.css("nav a[href], aside a[href], .theme-doc-sidebar-menu a[href]").each do |node|
      href = node["href"].to_s
      next if href.blank? || external_or_anchor_url?(href)

      path_part, = split_url_suffix(href)
      next if path_part.blank?

      site_path = site_path_from_url(path_part, absolute_path:)
      next unless site_path

      linked_version = @document_version_resolver.call(site_path)
      next unless linked_version
      next if linked_version.viewable_by?(@user)

      node.ancestors("li").first&.remove || node.remove
    end
  end

  def inject_portal_navigation!(document)
    return unless @project

    current_version = @current_document_version || @version
    current_document = current_version.document

    container = Nokogiri::XML::Node.new("div", document)
    container["class"] = "portal-site-nav"

    meta = Nokogiri::XML::Node.new("span", document)
    meta["class"] = "portal-site-nav-meta"
    meta.content = "#{current_document.title} / #{current_version.version_label}"
    container.add_child(meta)

    separator = Nokogiri::XML::Node.new("span", document)
    separator["class"] = "portal-site-nav-separator"
    separator.content = " | "
    container.add_child(separator)

    project_link = Nokogiri::XML::Node.new("a", document)
    project_link["href"] = @view_context.project_path(@project)
    project_link.content = "案件トップへ戻る"
    container.add_child(project_link)

    separator = Nokogiri::XML::Node.new("span", document)
    separator["class"] = "portal-site-nav-separator"
    separator.content = " | "
    container.add_child(separator)

    document_link = Nokogiri::XML::Node.new("a", document)
    document_link["href"] = @view_context.project_document_path(@project, current_document.slug)
    document_link.content = "文書詳細へ戻る"
    container.add_child(document_link)

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

  def inject_viewer_theme!(document)
    head = document.at_css("head")
    body = document.at_css("body")
    return unless head && body

    body_classes = [
      body["class"],
      "portal-doc-body",
      (@embedded ? "portal-doc-embedded" : "portal-doc-standalone")
    ].compact.join(" ")

    body["class"] = body_classes

    style = Nokogiri::XML::Node.new("style", document)
    style["data-docs-portal-theme"] = "iframe-doc-theme"
    style.content = viewer_theme_css
    head.add_child(style)
  end

  def viewer_theme_css
    [
      Rails.root.join("app/assets/stylesheets/iframe_doc_theme.css").read,
      portal_chrome_css
    ].join("\n")
  end

  def portal_chrome_css
    return "" if @embedded

    <<~CSS
      .portal-site-nav,
      .document-version-switcher {
        box-sizing: border-box;
        max-width: 1280px;
        margin: 0 auto;
        padding-left: 24px;
        padding-right: 24px;
      }
      .portal-site-nav {
        display: flex;
        gap: 0.5rem;
        flex-wrap: wrap;
        align-items: center;
        padding-top: 16px;
        padding-bottom: 12px;
        color: #4b5563;
        font-size: 0.95rem;
      }
      .portal-site-nav a {
        color: #0f62fe;
        text-decoration: none;
      }
      .document-version-switcher {
        margin-bottom: 16px;
      }
      .document-version-switcher summary {
        display: inline-flex;
        align-items: center;
        cursor: pointer;
        padding: 0.4rem 0.75rem;
        border: 1px solid #dbe4f0;
        border-radius: 999px;
        background: #fff;
        font-weight: 600;
      }
      .document-version-switcher ul {
        margin: 0.75rem 0 0;
        padding-left: 1.25rem;
      }
      @media (max-width: 960px) {
        .portal-site-nav,
        .document-version-switcher {
          padding-left: 16px;
          padding-right: 16px;
        }
      }
    CSS
  end
end
