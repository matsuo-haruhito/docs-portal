require "fileutils"
require "open3"

class Admin::ApiSpecificationPage
  SITE_PATH = "api-specification".freeze

  def initialize(view_context: nil)
    @view_context = view_context
  end

  def title
    "API仕様"
  end

  def site_path
    SITE_PATH
  end

  def source_path
    Rails.root.join("docs-src", "api-specification.md")
  end

  def build_entry_path
    build_root.join(SITE_PATH, "index.html")
  end

  def available?
    build_entry_path.exist?
  end

  def stale?
    return true unless available?
    return false unless source_path.exist?

    source_path.mtime > build_entry_path.mtime
  end

  def build_requested?
    build_request_marker_path.exist?
  end

  def request_build!
    FileUtils.mkdir_p(build_request_marker_path.dirname)
    File.write(build_request_marker_path, Time.current.iso8601)
  end

  def clear_build_request!
    FileUtils.rm_f(build_request_marker_path)
  end

  def enqueue_build_if_stale!
    return false unless stale?
    return false if build_requested?

    request_build!
    ApiSpecificationBuildJob.perform_later
    true
  end

  def build!
    raise ActiveRecord::RecordNotFound, "API specification source is missing" unless source_path.exist?

    FileUtils.mkdir_p(build_root)
    stdout, stderr, status = Open3.capture3(
      { "DOCUSAURUS_DOCS_PATH" => source_path.dirname.to_s },
      "npm", "run", "build",
      chdir: docusaurus_root.to_s
    )
    return if status.success? && build_entry_path.exist?

    raise "API specification Docusaurus build failed: #{stderr.presence || stdout}"
  end

  def iframe_src
    @view_context.site_admin_api_specification_path(site_path: SITE_PATH)
  end

  def renderer
    DocusaurusSiteRenderer.new(
      version: docusaurus_version,
      view_context: @view_context,
      embedded: true,
      site_url_builder: lambda { |relative_path, _version| @view_context.site_admin_api_specification_path(site_path: relative_path) }
    )
  end

  private

  def docusaurus_root
    Rails.root.join("docusaurus")
  end

  def build_root
    docusaurus_root.join("build")
  end

  def build_request_marker_path
    Rails.root.join("tmp", "api_specification_build.requested")
  end

  def docusaurus_version
    Admin::ApiSpecificationPage::DocusaurusVersion.new(build_root:, entry_path: SITE_PATH)
  end

  DocusaurusVersion = Struct.new(:build_root, :entry_path, keyword_init: true) do
    def site_root_absolute_path
      build_root
    end

    def site_entry_relative_path
      entry_path
    end

    def site_entry_absolute_path
      build_root.join(entry_path, "index.html")
    end

    def legacy_html_absolute_path
      build_root.join("index.html")
    end

    def site_build_path
      entry_path
    end

    def html_view_site_path
      entry_path
    end
  end
end
