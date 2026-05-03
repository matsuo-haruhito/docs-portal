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
    double(
      "view_context",
      site_document_version_path: ->(version_for_url, site_path:) { "/document_versions/#{version_for_url.public_id}/site/#{site_path}" },
      project_path: "/projects/#{project.code}",
      project_document_path: "/projects/#{project.code}/documents/#{document.slug}"
    )
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

  it "resolves markdown and README-style paths to generated html files" do
    write_site_file("#{site_build_path}/guide/index.html", "<html><body>Guide</body></html>")

    renderer = described_class.new(version:, view_context:)

    expect(renderer.file_response_path("#{site_build_path}/guide.md")).to eq(
      version.site_root_absolute_path.join(site_build_path, "guide", "index.html")
    )
    expect(renderer.file_response_path("#{site_build_path}/guide/README.md")).to eq(
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
    expect(html).to include('href="https://example.com"')
    expect(html).to include('href="mailto:test@example.com"')
    expect(html).to include('href="tel:0000000000"')
    expect(html).to include('href="#section"')
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
    expect(html).to include("ポータルへ戻る")
    expect(html).to include("/projects/#{project.code}")
    expect(html).to include("/projects/#{project.code}/documents/#{document.slug}")
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
