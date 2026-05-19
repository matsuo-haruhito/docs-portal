require "fileutils"
require "open3"
require Rails.root.join("db/seeds/support/docusaurus_runtime_checker")

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

  def source_paths
    Dir[source_path.dirname.join("*.md")].map { |path| Pathname.new(path) }
  end

  def build_entry_path
    build_root.join(SITE_PATH, "index.html")
  end

  def available?
    build_entry_path.exist?
  end

  def stale?
    build_freshness_guard.stale?
  end

  def enqueue_build_if_stale!
    build_freshness_guard.enqueue_if_stale!
  end

  def clear_build_request!
    build_freshness_guard.clear_build_request!
  end

  def build!
    raise ActiveRecord::RecordNotFound, "API specification source is missing" unless source_path.exist?

    SeedSupport::DocusaurusRuntimeChecker.ensure_npm!
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

  def build_freshness_guard
    @build_freshness_guard ||= BuildFreshnessGuard.new(
      source_path:,
      source_paths:,
      build_entry_path:,
      marker_path: build_request_marker_path,
      job_class: ApiSpecificationBuildJob
    )
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
