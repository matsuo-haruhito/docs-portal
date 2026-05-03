require "rails_helper"
require "securerandom"

RSpec.describe "Document search", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "PJ#{SecureRandom.hex(4)}", name: "Search Project") }

  def attach_file_to(version, file_name:, content_type: "application/octet-stream")
    DocumentFile.create!(
      document_version: version,
      file_name:,
      content_type:,
      storage_key: "spec/#{SecureRandom.hex(8)}-#{file_name}",
      file_size: 10
    )
  end

  def result_titles
    html = Nokogiri::HTML(response.body)
    html.css("main table tbody tr td:first-child").map { _1.text.strip }
  end

  def tree_labels
    html = Nokogiri::HTML(response.body)
    html.css(".tree-view-table").map(&:text).join(" ")
  end

  it "filters documents by keyword across title, slug, version label, and file name" do
    title_match = create(:document, project:, title: "運用手順", slug: "operation-manual")
    slug_match = create(:document, project:, title: "別資料", slug: "release-note")
    version_match = create(:document, project:, title: "版で探す資料", slug: "versioned-doc")
    file_match = create(:document, project:, title: "添付で探す資料", slug: "attached-doc")
    hidden = create(:document, project:, title: "対象外", slug: "other-doc")

    create(:document_version, document: title_match, version_label: "v1.0.0")
    create(:document_version, document: slug_match, version_label: "v1.0.0")
    create(:document_version, document: version_match, version_label: "needle-version")
    file_version = create(:document_version, document: file_match, version_label: "v1.0.0")
    create(:document_version, document: hidden, version_label: "v1.0.0")
    attach_file_to(file_version, file_name: "needle-file.pdf", content_type: "application/pdf")

    sign_in_as(user)

    get project_documents_path(project, q: "needle")

    expect(response).to have_http_status(:ok)
    expect(result_titles).to contain_exactly("版で探す資料", "添付で探す資料")
  end

  it "filters documents by enum fields" do
    spec_doc = create(:document, project:, title: "仕様書", category: :spec, document_kind: :markdown, visibility_policy: :restricted_external)
    manual_doc = create(:document, project:, title: "操作説明", category: :manual, document_kind: :pdf, visibility_policy: :public_with_login)

    create(:document_version, document: spec_doc)
    create(:document_version, document: manual_doc)

    sign_in_as(user)

    get project_documents_path(project, category: "manual", document_kind: "pdf", visibility_policy: "public_with_login")

    expect(response).to have_http_status(:ok)
    expect(result_titles).to contain_exactly("操作説明")
  end

  it "filters documents by html, attachment, and pdf availability" do
    html_doc = create(:document, project:, title: "HTMLあり", slug: "html-doc")
    html_version = create(:document_version, document: html_doc, site_build_path: "docs/html-doc")
    html_doc.update!(latest_version: html_version)

    file_doc = create(:document, project:, title: "添付あり", slug: "file-doc")
    file_version = create(:document_version, document: file_doc)
    attach_file_to(file_version, file_name: "note.txt", content_type: "text/plain")

    pdf_doc = create(:document, project:, title: "PDFあり", slug: "pdf-doc", document_kind: :markdown)
    pdf_version = create(:document_version, document: pdf_doc)
    attach_file_to(pdf_version, file_name: "manual.pdf", content_type: "application/pdf")

    sign_in_as(user)

    get project_documents_path(project, has_html: "1")
    expect(result_titles).to contain_exactly("HTMLあり")

    get project_documents_path(project, has_files: "1")
    expect(result_titles).to contain_exactly("PDFあり", "添付あり")

    get project_documents_path(project, has_pdf: "1")
    expect(result_titles).to contain_exactly("PDFあり")
  end

  it "keeps search conditions in the form and does not expose inaccessible documents to external users" do
    external_user = create(:user, :external)
    create(:project_membership, project:, user: external_user)

    visible_doc = create(:document, project:, title: "公開資料", slug: "visible-doc", category: :manual)
    hidden_doc = create(:document, project:, title: "社内資料", slug: "internal-doc", category: :manual, visibility_policy: :internal_only)
    create(:document_version, document: visible_doc)
    create(:document_version, document: hidden_doc)
    create(:document_permission, document: visible_doc, company: external_user.company, access_level: :view)

    sign_in_as(external_user)

    get project_documents_path(project, q: "資料", category: "manual")

    expect(response).to have_http_status(:ok)
    expect(result_titles).to contain_exactly("公開資料")
    expect(tree_labels).to include("公開資料")
    expect(tree_labels).not_to include("社内資料")
    expect(response.body).to include('value="資料"')
    expect(response.body).to match(/<option[^>]*selected="selected"[^>]*value="manual"|<option[^>]*value="manual"[^>]*selected="selected"/)
  end
end
