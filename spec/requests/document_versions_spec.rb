require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe "Document versions", type: :request do
  let(:internal_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }
  let(:project) { create(:project, code: "VERSIONED", name: "Versioned Project") }
  let(:document) { create(:document, project:, title: "Versioned Document", slug: "versioned-document") }
  let(:created_site_roots) { [] }

  def create_stored_document_file(version, file_name:, content:, sort_order: 0, content_type: "text/plain")
    storage_key = "spec/versioned-document/#{SecureRandom.hex(8)}/#{file_name}"
    absolute_path = Rails.root.join("storage", "document_files", storage_key)
    FileUtils.mkdir_p(absolute_path.dirname)
    File.binwrite(absolute_path, content)

    DocumentFile.create!(
      document_version: version,
      file_name:,
      content_type:,
      storage_key:,
      file_size: content.bytesize,
      sort_order:
    )
  end

  def create_rendered_site(version, html:, site_build_path: "docs/versioned-document")
    version.update!(site_build_path:)
    relative_path = version.site_entry_relative_path
    absolute_path = version.site_root_absolute_path.join(relative_path)
    FileUtils.mkdir_p(absolute_path.dirname)
    File.write(absolute_path, html)
    created_site_roots << version.site_root_absolute_path
  end

  after do
    created_site_roots.each { |path| FileUtils.rm_rf(path) }
    FileUtils.rm_rf(Rails.root.join("storage", "document_files", "spec", "versioned-document"))
  end

  it "shows version metadata, files, side-by-side review links, and links to other versions" do
    older_version = create(:document_version, document:, version_label: "v0.9.0", status: :archived)
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
    create_stored_document_file(version, file_name: "README.md", content: "# Readme", content_type: "text/markdown", sort_order: 0)

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
    expect(response.body).to include("版詳細ナビゲーション")
    expect(response.body).not_to include("markdown-preview-actions")
    expect(response.body).not_to include("markdown-tool")
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
    version = create(:document_version, document:, version_label: "v1.0.0", status: :published)
    document.update!(latest_version: version)
    create_stored_document_file(older_version, file_name: "README.md", content: "# Old heading\nsame line\nold value", content_type: "text/markdown", sort_order: 0)
    create_stored_document_file(version, file_name: "README.md", content: "# New heading\nsame line\nnew value", content_type: "text/markdown", sort_order: 0)
    create_rendered_site(older_version, html: "<main><h1>Old heading</h1><p>old value</p></main>", site_build_path: "docs/versioned-document/old")
    create_rendered_site(version, html: "<main><h1>New heading</h1><p>new value</p></main>", site_build_path: "docs/versioned-document/current")

    sign_in_as(internal_user)

    get document_version_path(version, compare_version_id: older_version.public_id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Markdown本文の行単位diff")
    expect(response.body).to include("HTML差分")
    expect(response.body).to include("統合diff")
    expect(response.body).to include("左右diff")
    expect(response.body).to include('id="markdown-diff-mode-0-unified"')
    expect(response.body).to include('id="markdown-diff-mode-0-side-by-side"')
    expect(response.body).to include('id="html-diff-mode-unified"')
    expect(response.body).to include('id="html-diff-mode-side-by-side"')
    expect(response.body).to include("Markdown左右比較")
    expect(response.body).to include("HTML左右比較")
    expect(response.body).to include("Markdown差分へ移動")
    expect(response.body).to include("HTML差分へ移動")
    expect(response.body).to include("版差分ビューへ移動")
  end

  it "opens side-by-side review files outside turbo frames" do
    older_version = create(:document_version, document:, version_label: "v0.9.0", status: :published)
    version = create(:document_version, document:, version_label: "v1.0.0", status: :published)
    document.update!(latest_version: version)
    create_stored_document_file(older_version, file_name: "manual.pdf", content: "%PDF old", content_type: "application/pdf", sort_order: 0)
    create_stored_document_file(version, file_name: "manual.pdf", content: "%PDF new", content_type: "application/pdf", sort_order: 0)

    sign_in_as(internal_user)
    get document_version_path(version, compare_version_id: older_version.public_id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("前版を開く")
    expect(response.body).to include("今回版を開く")
    expect(response.body).to include('target="_blank"')
    expect(response.body).to include('data-turbo="false"')
  end

  it "shows preview target metadata summary and organized sections" do
    version = create(:document_version, document:, version_label: "v1.0.0", status: :published)
    document.update!(latest_version: version)
    create_stored_document_file(
      version,
      file_name: ".docs-portal-preview.yml",
      content_type: "text/yaml",
      content: <<~YAML,
        preview_targets:
          primary: README.md
          attachments:
            - attachments/spec.pdf
          hidden:
            - hidden/private.pdf
          debug:
            - debug/raw.json
          groups:
            diagrams:
              - diagrams/flow.puml
      YAML
      sort_order: 0
    )
    create_stored_document_file(version, file_name: "README.md", content_type: "text/markdown", content: "# Readme", sort_order: 1)
    create_stored_document_file(version, file_name: "attachments/spec.pdf", content_type: "application/pdf", content: "%PDF", sort_order: 2)
    create_stored_document_file(version, file_name: "hidden/private.pdf", content_type: "application/pdf", content: "%PDF", sort_order: 3)
    create_stored_document_file(version, file_name: "debug/raw.json", content_type: "application/json", content: "{}", sort_order: 4)
    create_stored_document_file(version, file_name: "diagrams/flow.puml", content_type: "text/plain", content: "@startuml", sort_order: 5)

    sign_in_as(internal_user)
    get document_version_path(version)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("添付分類サマリ")
    expect(response.body).to include("hidden/private.pdf")
    expect(response.body).to include("debug/raw.json")
    expect(response.body).to include("diagrams")
    expect(response.body).to include("主要ファイル")
    expect(response.body).to include("通常表示")
    expect(response.body).to include("補助")
    expect(response.body).to include("デバッグ")
  end

  it "shows export handling notes on version detail" do
    version = create(:document_version, document:, version_label: "v1.0.0", status: :published)
    document.update!(latest_version: version)
    pdf_key = "spec/versioned-document/#{SecureRandom.hex(8)}/manual.pdf"
    pdf_path = Rails.root.join("storage", "document_files", pdf_key)
    FileUtils.mkdir_p(pdf_path.dirname)
    File.binwrite(pdf_path, "%PDF-1.4")
    create(:document_file, document_version: version, file_name: "manual.pdf", content_type: "application/pdf", storage_key: pdf_key, file_size: 8, sort_order: 0, scan_status: :scan_clean)

    sign_in_as(internal_user)
    get document_version_path(version)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("出力時の扱い")
    expect(response.body).to include("HTML 表示には透かしを入れません")
    expect(response.body).to include("Confidential")
  end

  it "links from document detail to each visible version detail" do
    version = create(:document_version, document:, version_label: "v1.0.0", status: :published)
    document.update!(latest_version: version)

    sign_in_as(internal_user)

    get project_document_path(project, document.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(document_version_path(version))
    expect(response.body).to include("1ファイルずつ")
  end

  it "downloads version files as a zip archive and records a download log" do
    version = create(:document_version, document:, version_label: "v1.0.0", status: :published)
    document.update!(latest_version: version)
    create_stored_document_file(version, file_name: "README.md", content: "hello", sort_order: 0)
    create_stored_document_file(version, file_name: "assets/guide.txt", content: "guide", sort_order: 1)

    sign_in_as(internal_user)

    expect do
      get document_version_archive_path(version)
    end.to change(AccessLog.where(action_type: :download, target_type: "zip"), :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/zip")
    expect(response.headers["Content-Disposition"]).to include("attachment")
    expect(response.body).to start_with("PK")
    expect(response.body).to include("README.md")
    expect(response.body).to include("assets/guide.txt")
  end

  it "applies external user visibility rules to version detail and zip archive pages" do
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company: external_user.company, access_level: :view)
    published_version = create(:document_version, document:, version_label: "v1.0.0", status: :published)
    draft_version = create(:document_version, document:, version_label: "v1.1.0", status: :draft)
    archived_version = create(:document_version, document:, version_label: "v0.9.0", status: :archived)

    sign_in_as(external_user)

    get document_version_path(published_version)
    expect(response).to have_http_status(:ok)

    get document_version_archive_path(published_version)
    expect(response).to have_http_status(:forbidden)

    get document_version_path(draft_version)
    expect(response).to have_http_status(:forbidden)

    get document_version_archive_path(draft_version)
    expect(response).to have_http_status(:forbidden)

    get document_version_path(archived_version)
    expect(response).to have_http_status(:forbidden)

    get document_version_archive_path(archived_version)
    expect(response).to have_http_status(:forbidden)
  end
end
