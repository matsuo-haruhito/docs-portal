class Admin::ApiSpecificationPage
  SITE_PATH = "api-specification".freeze

  def initialize(view_context:)
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

  def build_root
    Rails.root.join("docusaurus", "build")
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
