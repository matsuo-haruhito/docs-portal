require "base64"
require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe DocusaurusSiteRenderer do
  let(:project) { create(:project, code: "PJ#{SecureRandom.hex(4)}", name: "Project #{SecureRandom.hex(2)}") }
  let(:document) { create(:document, project:, title: "操作説明", slug: "operation-guide") }
  let(:site_build_path) { "docs-#{SecureRandom.hex(3)}/operation-guide" }
  let(:version) do
    create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      markdown_entry_path: site_build_path,
      site_build_path:
    )
  end
  let(:view_context) do
    Class.new do
      def site_document_version_path(version_for_url, site_path:)
        "/document_versions/#{version_for_url.public_id}/site/#{site_path}"
      end

      def project_path(project)
        "/projects/#{project.code}"
      end

      def project_document_path(project, slug)
        "/projects/#{project.code}/documents/#{slug}"
      end
    end.new
  end

  def write_site_file(relative_path, content)
    path = version.site_root_absolute_path.join(relative_path)
    FileUtils.mkdir_p(path.dirname)
    File.write(path, content)
  end

  after do
    FileUtils.rm_rf(version.site_root_absolute_path) if version&.id
    Current.reset
  end

  it "resolves markdown, mdx, and README-style paths to generated html files" do
    write_site_file("#{site_build_path}/guide/index.html", "<html><body>Guide</body></html>")

    renderer = described_class.new(version:, view_context:)

    expect(renderer.file_response_path("#{site_build_path}/guide.md")).to eq(
      version.site_root_absolute_path.join(site_build_path, "guide", "index.html")
    )
    expect(renderer.file_response_path("#{site_build_path}/guide.mdx")).to eq(
      version.site_root_absolute_path.join(site_build_path, "guide", "index.html")
    )
    expect(renderer.file_response_path("#{site_build_path}/guide/README.md")).to eq(
      version.site_root_absolute_path.join(site_build_path, "guide", "index.html")
    )
    expect(renderer.file_response_path("#{site_build_path}/guide/index.mdx")).to eq(
      version.site_root_absolute_path.join(site_build_path, "guide", "index.html")
    )
  end

  it "rewrites internal urls while preserving external, mail, phone, and anchor urls" do
    write_site_file(
      "#{site_build_path}/index.html",
      <<~HTML
        <html>
          <body>
            <a href="guide/getting-started">Guide</a>
            <a href="guide/search?q=abc#top">Guide with suffix</a>
            <a href="https://example.com">External</a>
            <a href="mailto:test@example.com">Mail</a>
            <a href="tel:0000000000">Phone</a>
            <a href="#section">Anchor</a>
          </body>
        </html>
      HTML
    )

    renderer = described_class.new(version:, view_context:)
    html = renderer.render_html("#{site_build_path}/index")

    expect(html).to include("/document_versions/#{version.public_id}/site/#{site_build_path}/guide/getting-started")
    expect(html).to include("/document_versions/#{version.public_id}/site/#{site_build_path}/guide/search?q=abc#top")
    expect(html).to include('href="https://example.com"')
    expect(html).to include('href="mailto:test@example.com"')
    expect(html).to include('href="tel:0000000000"')
    expect(html).to include('href="#section"')
  end

  it "adds stable table preference metadata to each standalone markdown table" do
    write_site_file(
      "#{site_build_path}/index.html",
      <<~HTML
        <html>
          <head></head>
          <body>
            <table><tbody><tr><td>First</td></tr></tbody></table>
            <table><tbody><tr><td>Second</td></tr></tbody></table>
          </body>
        </html>
      HTML
    )

    renderer = described_class.new(
      version:,
      view_context:,
      current_document_version: version,
      project:
    )
    html = renderer.render_html("#{site_build_path}/index")
    parsed = Nokogiri::HTML5.parse(html)

    wrappers = parsed.css(".portal-doc-table-preference-wrapper")
    tables = parsed.css("table")
    expected_site_path = DocumentVersion.normalize_site_page_path("#{site_build_path}/index")
    expected_site_path_key = Base64.urlsafe_encode64(expected_site_path, padding: false)

    expect(wrappers.size).to eq(2)
    expect(tables.size).to eq(2)
    expect(wrappers.map { _1["data-docs-portal-table-index"] }).to eq(%w[1 2])
    expect(wrappers.map { _1["data-docs-portal-site-path"] }).to all(eq(expected_site_path))
    expect(wrappers.map { _1["data-docs-portal-document-version"] }).to all(eq(version.public_id))

    table_keys = wrappers.map { _1["data-rails-table-preferences-table-key"] }
    expect(table_keys.uniq.size).to eq(2)
    expect(table_keys).to all(include("document-version:#{version.public_id}:site-path:#{expected_site_path_key}:table:"))
    expect(table_keys).to all(satisfy { |key| !key.include?("/") })
    expect(tables.map { _1["data-rails-table-preferences-table-key"] }).to eq(table_keys)
  end

  it "keeps mermaid and code blocks intact while annotating real tables" do
    write_site_file(
      "#{site_build_path}/index.html",
      <<~HTML
        <html>
          <head></head>
          <body>
            <div class="mermaid">graph TD; A-->B;</div>
            <pre><code>&lt;table&gt;&lt;tr&gt;&lt;td&gt;example&lt;/td&gt;&lt;/tr&gt;&lt;/table&gt;</code></pre>
            <table><tbody><tr><td>Visible table</td></tr></tbody></table>
          </body>
        </html>
      HTML
    )

    renderer = described_class.new(
      version:,
      view_context:,
      current_document_version: version,
      project:
    )
    html = renderer.render_html("#{site_build_path}/index")
    parsed = Nokogiri::HTML5.parse(html)

    expect(parsed.css(".portal-doc-table-preference-wrapper").size).to eq(1)
    expect(parsed.css("table").size).to eq(1)
    expect(parsed.at_css(".mermaid")&.text).to include("graph TD; A-->B;")
    expect(parsed.at_css("pre code")&.text).to include("<table><tr><td>example</td></tr></table>")
  end

  it "adds stable table preference metadata in embedded mode without portal chrome" do
    write_site_file(
      "#{site_build_path}/index.html",
      <<~HTML
        <html>
          <head></head>
          <body>
            <table><tbody><tr><td>Embedded</td></tr></tbody></table>
          </body>
        </html>
      HTML
    )

    renderer = described_class.new(
      version:,
      view_context:,
      current_document_version: version,
      project:,
      embedded: true
    )
    html = renderer.render_html("#{site_build_path}/index")
    parsed = Nokogiri::HTML5.parse(html)

    wrapper = parsed.at_css(".portal-doc-table-preference-wrapper")
    table = parsed.at_css("table")

    expect(wrapper).to be_present
    expect(wrapper["data-rails-table-preferences-table-key"]).to eq(
      table["data-rails-table-preferences-table-key"]
    )
    expect(wrapper["data-docs-portal-table-index"]).to eq("1")
    expect(html).not_to include("portal-site-nav")
    expect(html).not_to include("document-version-switcher")
  end

  it "injects portal navigation links when project context is provided" do
    write_site_file("#{site_build_path}/index.html", "<html><body><h1>操作説明</h1></body></html>")

    renderer = described_class.new(
      version:,
      view_context:,
      current_document_version: version,
      project:
    )
    html = renderer.render_html("#{site_build_path}/index")

    expect(html).to include("portal-site-nav")
    expect(html).to include("操作説明 / v1.0.0")
    expect(html).to include("案件トップへ戻る")
    expect(html).to include("文書詳細へ戻る")
    expect(html).to include("/projects/#{project.code}")
    expect(html).to include("/projects/#{project.code}/documents/#{document.slug}")
  end

  it "injects viewer theme css for portal document reading" do
    write_site_file("#{site_build_path}/index.html", "<html><head></head><body><main><article><h1>操作説明</h1></article></main></body></html>")

    renderer = described_class.new(
      version:,
      view_context:,
      current_document_version: version,
      project:
    )
    html = renderer.render_html("#{site_build_path}/index")

    expect(html).to include("portal-doc-body")
    expect(html).to include(".portal-site-nav")
    expect(html).to include(".theme-doc-breadcrumbs")
    expect(html).to include("max-width: none !important")
    expect(html).to include("max-width: 1280px")
  end

  it "omits injected portal navigation in embedded mode" do
    write_site_file("#{site_build_path}/index.html", "<html><head></head><body><main><article><h1>操作説明</h1></article></main></body></html>")

    renderer = described_class.new(
      version:,
      view_context:,
      current_document_version: version,
      project:,
      embedded: true
    )
    html = renderer.render_html("#{site_build_path}/index")

    expect(html).to include("portal-doc-body")
    expect(html).not_to include("portal-site-nav")
    expect(html).not_to include("document-version-switcher")
    expect(html).to include("max-width: none !important")
    expect(html).to include("margin: 0")
    expect(html).to include("padding: 20px 24px 48px")
  end

  it "removes navigation links to versions the current user cannot view" do
    external_user = create(:user, :external)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company: external_user.company, access_level: :view)
    Current.user = external_user

    restricted_document = create(:document, project:, title: "社外秘メモ", slug: "secret-memo")
    restricted_version = create(
      :document_version,
      document: restricted_document,
      version_label: version.version_label,
      markdown_entry_path: "#{site_build_path}/secret-memo",
      site_build_path:
    )

    write_site_file(
      "#{site_build_path}/index.html",
      <<~HTML
        <html>
          <body>
            <nav>
              <ul>
                <li><a href="operation-guide">Allowed page</a></li>
                <li><a href="secret-memo">Restricted page</a></li>
              </ul>
            </nav>
          </body>
        </html>
      HTML
    )

    resolver = lambda do |site_path|
      case site_path
      when "#{site_build_path}/operation-guide"
        version
      when "#{site_build_path}/secret-memo"
        restricted_version
      end
    end

    renderer = described_class.new(
      version:,
      view_context:,
      current_document_version: version,
      project:,
      user: external_user,
      document_version_resolver: resolver
    )
    html = renderer.render_html("#{site_build_path}/index")

    expect(html).to include("Allowed page")
    expect(html).not_to include("Restricted page")
  end
end
