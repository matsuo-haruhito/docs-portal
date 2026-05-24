require "rails_helper"

RSpec.describe "Document versions", type: :request do
  let(:project) { create(:project, name: "Versioned", slug: "VERSIONED") }
  let(:document) do
    create(
      :document,
      project:,
      title: "Versioned Document",
      slug: "versioned-document",
      current_content: "Current body"
    )
  end
  let(:internal_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }

  def sign_in_as(user)
    post session_path, params: { email: user.email, password: "password" }
    follow_redirect!
  end

  def create_stored_document_file(version, file_name:, content:, content_type:, sort_order: 0, file_path: nil)
    stored_file_path = Rails.root.join("tmp", "spec-storage", SecureRandom.hex(8), file_name)
    stored_file_path.dirname.mkpath
    stored_file_path.binwrite(content)

    create(
      :document_file,
      document_version: version,
      file_name:,
      file_path: file_path || file_name,
      content_type:,
      file_size: content.bytesize,
      storage_path: stored_file_path.to_s,
      source: :markdown,
      sort_order:
    )
  end

  def create_rendered_site(version, html:, site_build_path: "docs/versioned-document/current")
    create(
      :document_rendered_site,
      document_version: version,
      site_build_path:,
      status: :ready,
      html_entry_path: File.join(site_build_path, "index.html"),
      html_content: html
    )
  end

  it "renders the markdown preview, diff workspace, and archive link for internal users" do
    older_version = create(:document_version, document:, version_label: "v0.9.0", status: :published)
    version = create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      status: :published,
      changelog_summary: "initial release",
      markdown_entry_path: "docs/versioned-document",
      site_build_path: "docs/versioned-document"
    )
    document.update!(latest_version: version)
    create_stored_document_file(older_version, file_name: "README.md", content: "old body", content_type: "text/markdown", sort_order: 0)
    create_stored_document_file(version, file_name: "README.md", content: "new body", content_type: "text/markdown", sort_order: 0)
    create_rendered_site(version, html: "<main><h1>Preview</h1></main>", site_build_path: "docs/versioned-document/current")

    sign_in_as(internal_user)

    get document_version_path(version)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Versioned Document")
    expect(response.body).to include("v1.0.0")
    expect(response.body).to include("initial release")
    expect(response.body).to include("README.md")
    expect(response.body).to include(older_version.version_label)
    expect(response.body).to include(document_version_archive_path(version))
    expect(response.body).to include("差分本文へ移動")
    expect(response.body).to include("左右確認")
    expect(response.body).to include("左右確認（比較対象なし）")
    expect(response.body).to include("添付・元ファイルへ移動")
  end

  it "renders truthful mode navigation for internal users" do
    version = create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      status: :published,
      markdown_entry_path: "docs/versioned-document",
      site_build_path: "docs/versioned-document"
    )
    document.update!(latest_version: version)
    create_stored_document_file(version, file_name: "README.md", content: "# Readme", content_type: "text/markdown", sort_order: 0)
    create_rendered_site(version, html: "<main><h1>Preview</h1></main>", site_build_path: "docs/versioned-document/current")

    sign_in_as(internal_user)

    get document_version_path(version)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("aria-label=")
    expect(response.body).to include(project_document_path(project, document.slug, version_id: version.public_id, site_path: version.html_view_site_path))
    expect(response.body).to include(document_version_quality_check_path(version))
    expect(response.body).to include('class="markdown-mode-tab is-active"')
  end

  it "shows a clear no-compare state in the side-by-side section when no previous version is available" do
    version = create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      status: :published,
      markdown_entry_path: "docs/versioned-document",
      site_build_path: "docs/versioned-document"
    )
    document.update!(latest_version: version)
    create_stored_document_file(version, file_name: "README.md", content: "# Readme", content_type: "text/markdown", sort_order: 0)

    sign_in_as(internal_user)

    get document_version_path(version)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("左右確認（比較対象なし）")
    expect(response.body).to include("公開済みの比較対象版がまだないため、この版では左右比較や差分表示は行わず")
    expect(response.body).to include("比較対象となる公開済みの版がまだないため、この画面では左右比較を表示しません")
  end

  it "offers unified and side-by-side display modes for markdown and html diffs" do
    older_version = create(:document_version, document:, version_label: "v0.9.0", status: :published)
    version = create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      status: :published,
      markdown_entry_path: "docs/versioned-document",
      site_build_path: "docs/versioned-document"
    )
    document.update!(latest_version: version)
    create_stored_document_file(older_version, file_name: "README.md", content: "# Title\nold body\n", content_type: "text/markdown", sort_order: 0)
    create_stored_document_file(version, file_name: "README.md", content: "# Title\nnew body\n", content_type: "text/markdown", sort_order: 0)
    create_rendered_site(older_version, html: "<main><p>old html</p></main>", site_build_path: "docs/versioned-document/older")
    create_rendered_site(version, html: "<main><p>new html</p></main>", site_build_path: "docs/versioned-document/current")

    sign_in_as(internal_user)

    get document_version_path(version, compare_version_id: older_version.public_id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("統合diff")
    expect(response.body).to include("左右diff")
    expect(response.body).to include("Markdown左右比較")
    expect(response.body).to include("HTML左右比較")
  end

  it "renders a side-by-side file review section for binary files" do
    older_version = create(:document_version, document:, version_label: "v0.9.0", status: :published)
    version = create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      status: :published,
      markdown_entry_path: "docs/versioned-document",
      site_build_path: "docs/versioned-document"
    )
    document.update!(latest_version: version)
    create_stored_document_file(older_version, file_name: "diagram.png", content: "old-png", content_type: "image/png", sort_order: 0)
    create_stored_document_file(version, file_name: "diagram.png", content: "new-png", content_type: "image/png", sort_order: 0)

    sign_in_as(internal_user)

    get document_version_path(version, compare_version_id: older_version.public_id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("左右確認ビュー")
    expect(response.body).to include("diagram.png")
    expect(response.body).to include("前版")
    expect(response.body).to include("今回版")
    expect(response.body).to include("画像プレビュー")
  end

  it "shows preview target display sections and group labels" do
    version = create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      status: :published,
      markdown_entry_path: "docs/versioned-document",
      site_build_path: "docs/versioned-document"
    )
    document.update!(latest_version: version)
    create_stored_document_file(version, file_name: "README.md", file_path: "README.md", content: "# Readme", content_type: "text/markdown", sort_order: 0)
    create_stored_document_file(version, file_name: "manual.pdf", file_path: "docs/manual.pdf", content: "%PDF-1.4", content_type: "application/pdf", sort_order: 1)
    create_stored_document_file(version, file_name: "notes.txt", file_path: "debug/notes.txt", content: "debug note", content_type: "text/plain", sort_order: 2)
    create_stored_document_file(version, file_name: "appendix.md", file_path: "appendix/appendix.md", content: "appendix", content_type: "text/markdown", sort_order: 3)

    sign_in_as(internal_user)

    get document_version_path(version)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("通常表示ファイル")
    expect(response.body).to include("group: appendix")
    expect(response.body).to include("hidden files")
    expect(response.body).to include("debug files")
  end

  it "allows external users to read document versions without archive or internal quality links" do
    published_version = create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      status: :published,
      markdown_entry_path: "docs/versioned-document",
      site_build_path: "docs/versioned-document"
    )
    archived_version = create(
      :document_version,
      document:,
      version_label: "v0.9.0",
      status: :archived,
      markdown_entry_path: "docs/versioned-document/archive",
      site_build_path: "docs/versioned-document/archive"
    )
    document.update!(latest_version: published_version)
    create_stored_document_file(published_version, file_name: "README.md", content: "# Readme", content_type: "text/markdown", sort_order: 0)
    create_stored_document_file(archived_version, file_name: "README-old.md", content: "# Old", content_type: "text/markdown", sort_order: 0)

    sign_in_as(external_user)

    get document_version_path(published_version)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("aria-current=")
    expect(response.body).not_to include(document_version_quality_check_path(published_version))

    get document_version_archive_path(published_version)
    expect(response).to have_http_status(:forbidden)

    get document_version_path(archived_version)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(archived_version.version_label)
    expect(response.body).not_to include(document_version_quality_check_path(archived_version))

    get document_version_archive_path(archived_version)
    expect(response).to have_http_status(:forbidden)
  end
end
