require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe "Project document zips", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "ZIP#{SecureRandom.hex(3)}", name: "Zip Project") }

  def create_document_with_file(title:, slug:, file_name:, content:)
    document = create(:document, project:, title:, slug:)
    version = create(:document_version, document:, version_label: "v1.0.0")
    document.update!(latest_version: version)

    storage_key = "spec/project-document-zips/#{SecureRandom.hex(8)}/#{file_name}"
    absolute_path = Rails.root.join("storage", "document_files", storage_key)
    FileUtils.mkdir_p(absolute_path.dirname)
    File.binwrite(absolute_path, content)

    DocumentFile.create!(
      document_version: version,
      file_name:,
      content_type: "text/plain",
      storage_key:,
      file_size: content.bytesize,
      scan_status: :scan_clean
    )

    document
  end

  def binary_string(value)
    value.b
  end

  after do
    FileUtils.rm_rf(Rails.root.join("storage", "document_files", "spec", "project-document-zips"))
  end

  it "downloads selected latest document versions as a zip archive and records logs" do
    first = create_document_with_file(title: "First", slug: "first", file_name: "README.md", content: "first")
    second = create_document_with_file(title: "Second", slug: "second", file_name: "guide.txt", content: "second")

    sign_in_as(user)

    expect do
      post project_document_zip_path(project), params: { document_ids: [first.id, second.id] }
    end.to change(AccessLog.where(action_type: :download, target_type: "zip"), :count).by(2)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/zip")
    expect(response.headers["Content-Disposition"]).to include("attachment")
    expect(response.body).to start_with("PK")
    expect(response.body).to include("first/v1.0.0/README.md")
    expect(response.body).to include("second/v1.0.0/guide.txt")
  end

  it "keeps Japanese document and file names in the zip archive" do
    document = create_document_with_file(title: "日本語資料", slug: "nihongo-doc", file_name: "操作説明書.txt", content: "日本語本文")
    project.update!(code: "案件A")

    sign_in_as(user)

    post project_document_zip_path(project), params: { document_ids: [document.id] }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/zip")
    expect(response.headers["content-disposition"]).to include("attachment")
    expect(response.headers["content-disposition"]).to include("filename*=UTF-8''%E6%A1%88%E4%BB%B6A-documents.zip")
    expect(response.body).to include(binary_string("nihongo-doc/v1.0.0/操作説明書.txt"))
  end

  it "ignores selected documents outside the current user access scope" do
    external_user = create(:user, :external)
    visible = create_document_with_file(title: "Visible", slug: "visible", file_name: "visible.txt", content: "visible")
    hidden = create_document_with_file(title: "Hidden", slug: "hidden", file_name: "hidden.txt", content: "hidden")
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document: visible, company: external_user.company, access_level: :download)

    sign_in_as(external_user)

    post project_document_zip_path(project), params: { document_ids: [visible.id, hidden.id] }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("visible/v1.0.0/visible.txt")
    expect(response.body).not_to include("hidden/v1.0.0/hidden.txt")
  end

  it "ignores selected documents when the external user only has view permission" do
    external_user = create(:user, :external)
    downloadable = create_document_with_file(title: "Downloadable", slug: "downloadable", file_name: "downloadable.txt", content: "downloadable")
    view_only = create_document_with_file(title: "View Only", slug: "view-only", file_name: "view-only.txt", content: "view-only")
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document: downloadable, company: external_user.company, access_level: :download)
    create(:document_permission, document: view_only, company: external_user.company, access_level: :view)

    sign_in_as(external_user)

    expect do
      post project_document_zip_path(project), params: { document_ids: [downloadable.id, view_only.id] }
    end.to change(AccessLog.where(action_type: :download, target_type: "zip"), :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("downloadable/v1.0.0/downloadable.txt")
    expect(response.body).not_to include("view-only/v1.0.0/view-only.txt")
  end

  it "downloads all matching documents across the current filters when matching selection is requested" do
    external_user = create(:user, :external)
    visible = create_document_with_file(title: "Alpha Visible", slug: "alpha-visible", file_name: "visible.txt", content: "visible")
    hidden = create_document_with_file(title: "Alpha Hidden", slug: "alpha-hidden", file_name: "hidden.txt", content: "hidden")
    create(:document, project:, title: "Alpha No Version", slug: "alpha-no-version")
    other = create_document_with_file(title: "Beta Visible", slug: "beta-visible", file_name: "beta.txt", content: "beta")
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document: visible, company: external_user.company, access_level: :download)
    create(:document_permission, document: other, company: external_user.company, access_level: :download)

    sign_in_as(external_user)

    post project_document_zip_path(project), params: {
      selection_scope: "matching",
      q: "Alpha"
    }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("alpha-visible/v1.0.0/visible.txt")
    expect(response.body).not_to include("alpha-hidden/v1.0.0/hidden.txt")
    expect(response.body).not_to include("beta-visible/v1.0.0/beta.txt")
  end

  it "shows page and matching bulk selection controls on the document index while keeping unavailable documents disabled" do
    available_document = create_document_with_file(title: "First", slug: "first", file_name: "README.md", content: "first")
    unavailable_document = create(:document, project:, title: "Unavailable", slug: "unavailable")

    sign_in_as(user)

    get project_documents_path(project)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(project_document_zip_path(project))
    expect(response.body).to include("選択した文書の最新版をZIPでダウンロード")
    expect(response.body).to include("ZIP出力オプション")
    expect(response.body).to include("このページを全選択")
    expect(response.body).to include("検索結果1件を全選択")
    expect(response.body).to include("選択解除")
    expect(response.body).to include("0件選択中")

    html = Nokogiri::HTML.parse(response.body)
    available_checkbox = html.at_css("input#document_ids_#{available_document.id}")
    unavailable_checkbox = html.at_css("input#document_ids_#{unavailable_document.id}")
    count = html.at_css('[data-document-zip-selection-target="count"]')
    scope_field = html.at_css('input[name="selection_scope"]')

    aggregate_failures do
      expect(available_checkbox["data-action"]).to include("document-zip-selection#sync")
      expect(available_checkbox["data-document-zip-selection-target"]).to eq("checkbox")
      expect(unavailable_checkbox["disabled"]).to eq("disabled")
      expect(count.text).to include("0件選択中")
      expect(scope_field["value"]).to eq("explicit")
    end
  end

  it "does not reuse slash-containing keyword queries as zip source_path state" do
    document = create(:document, project:, title: "guides/folder-guide", slug: "folder-guide")
    version = create(:document_version, document:, version_label: "v1.0.0", source_relative_path: "guides/folder-guide/README.md")
    document.update!(latest_version: version)

    sign_in_as(user)

    get project_documents_path(project), params: { q: "guides/folder-guide" }

    expect(response).to have_http_status(:ok)

    html = Nokogiri::HTML.parse(response.body)
    zip_form = html.at_css("form[action='#{project_document_zip_path(project)}']")

    aggregate_failures do
      expect(zip_form.at_css('input[name="q"]')["value"]).to eq("guides/folder-guide")
      expect(zip_form.at_css('input[name="source_path"]')).to be_nil
    end
  end

  it "keeps upload-source folder context in the zip form" do
    document = create(:document, project:, title: "Folder doc", slug: "folder-doc")
    version = create(:document_version, document:, version_label: "v1.0.0", source_relative_path: "guides/folder-doc/README.md")
    document.update!(latest_version: version)

    sign_in_as(user)

    get project_documents_path(project), params: { upload_source_path: "guides/folder-doc" }

    expect(response).to have_http_status(:ok)

    html = Nokogiri::HTML.parse(response.body)
    zip_form = html.at_css("form[action='#{project_document_zip_path(project)}']")
    source_path_field = zip_form.at_css('input[name="source_path"]')

    expect(source_path_field["value"]).to eq("guides/folder-doc")
  end

  it "supports zip path and file type options" do
    document = create(:document, project:, title: "仕様書", slug: "spec-doc")
    version = create(:document_version, document:, version_label: "v1.0.0", source_relative_path: "deliverables/spec-doc/README.md")
    document.update!(latest_version: version)

    markdown_key = "spec/project-document-zips/#{SecureRandom.hex(8)}/README.md"
    pdf_key = "spec/project-document-zips/#{SecureRandom.hex(8)}/manual.pdf"
    markdown_path = Rails.root.join("storage", "document_files", markdown_key)
    pdf_path = Rails.root.join("storage", "document_files", pdf_key)
    FileUtils.mkdir_p(markdown_path.dirname)
    FileUtils.mkdir_p(pdf_path.dirname)
    File.write(markdown_path, "# body\n")
    File.binwrite(pdf_path, "%PDF-1.4")

    create(:document_file, document_version: version, file_name: "README.md", content_type: "text/markdown", storage_key: markdown_key, file_size: 7, scan_status: :scan_clean)
    create(:document_file, document_version: version, file_name: "manual.pdf", content_type: "application/pdf", storage_key: pdf_key, file_size: 8, scan_status: :scan_clean)

    sign_in_as(user)

    post project_document_zip_path(project), params: {
      document_ids: [document.id],
      zip_path_mode: "source_path",
      include_markdown_sources: "0",
      include_attachments: "1",
      pdf_only: "1"
    }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("deliverables/spec-doc/manual.pdf")
    expect(response.body).not_to include("README.md")
    expect(response.body).to include("README.txt")
    expect(response.body).to include("PDF watermark metadata")
    expect(response.body).to include("Confidential")
  end
end
