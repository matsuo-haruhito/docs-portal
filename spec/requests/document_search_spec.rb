require "rails_helper"
require "securerandom"

RSpec.describe "Document search", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "PJ#{SecureRandom.hex(4)}", name: "Search Project") }

  def attach_file_to(version, file_name:, content_type: "application/octet-stream", search_text: nil)
    DocumentFile.create!(
      document_version: version,
      file_name:,
      content_type:,
      storage_key: "spec/#{SecureRandom.hex(8)}-#{file_name}",
      file_size: 10,
      search_text:
    )
  end

  def tag_document(document, name)
    tag = DocumentTag.find_or_create_by!(normalized_name: DocumentTag.normalize(name)) do |record|
      record.name = name
    end

    DocumentTagging.create!(document:, document_tag: tag)
    tag
  end

  def keyword_document(document, keyword)
    DocumentKeyword.create!(document:, keyword:)
  end

  def result_titles
    html = Nokogiri::HTML(response.body)
    html.css("main table tbody tr td:first-child").map { _1.text.strip }
  end

  def tree_labels
    html = Nokogiri::HTML(response.body)
    html.css(".tree-view-table").map(&:text).join(" ")
  end

  it "filters documents by keyword across title, slug, version label, file name, and document keyword" do
    title_match = create(:document, project:, title: "運用手順", slug: "operation-manual")
    slug_match = create(:document, project:, title: "別資料", slug: "release-note")
    version_match = create(:document, project:, title: "版で探す資料", slug: "versioned-doc")
    file_match = create(:document, project:, title: "添付で探す資料", slug: "attached-doc")
    keyword_match = create(:document, project:, title: "業務語で探す資料", slug: "keyword-doc")
    hidden = create(:document, project:, title: "対象外", slug: "other-doc")

    create(:document_version, document: title_match, version_label: "v1.0.0")
    create(:document_version, document: slug_match, version_label: "v1.0.0")
    create(:document_version, document: version_match, version_label: "needle-version")
    file_version = create(:document_version, document: file_match, version_label: "v1.0.0")
    create(:document_version, document: keyword_match, version_label: "v1.0.0")
    create(:document_version, document: hidden, version_label: "v1.0.0")
    attach_file_to(file_version, file_name: "needle-file.pdf", content_type: "application/pdf")
    keyword_document(keyword_match, "needle-business-word")

    sign_in_as(user)

    get project_documents_path(project, q: "needle")

    expect(response).to have_http_status(:ok)
    expect(result_titles).to contain_exactly("版で探す資料", "添付で探す資料", "業務語で探す資料")
  end

  it "filters documents by body text and source path metadata" do
    body_match = create(:document, project:, title: "本文で探す資料", slug: "body-doc")
    source_path_match = create(:document, project:, title: "パスで探す資料", slug: "path-doc")
    source_file_match = create(:document, project:, title: "ファイル名で探す資料", slug: "source-file-doc")
    hidden = create(:document, project:, title: "対象外", slug: "body-hidden")

    create(:document_version, document: body_match, search_body_text: "markdown body includes body-needle")
    create(:document_version, document: source_path_match, source_directory: "作成資料/body-needle")
    create(:document_version, document: source_file_match, source_file_name: "body-needle.md")
    create(:document_version, document: hidden, search_body_text: "other text")

    sign_in_as(user)

    get project_documents_path(project, q: "body-needle")

    expect(response).to have_http_status(:ok)
    expect(result_titles).to contain_exactly("本文で探す資料", "パスで探す資料", "ファイル名で探す資料")
  end

  it "filters documents by extracted document file search text" do
    file_text_match = create(:document, project:, title: "添付本文で探す資料", slug: "file-text-doc")
    hidden = create(:document, project:, title: "対象外", slug: "file-text-hidden")
    file_text_version = create(:document_version, document: file_text_match)
    hidden_version = create(:document_version, document: hidden)
    attach_file_to(file_text_version, file_name: "manual.pdf", content_type: "application/pdf", search_text: "attachment includes file-body-needle")
    attach_file_to(hidden_version, file_name: "manual.pdf", content_type: "application/pdf", search_text: "attachment has other text")

    sign_in_as(user)

    get project_documents_path(project, q: "file-body-needle")

    expect(response).to have_http_status(:ok)
    expect(result_titles).to contain_exactly("添付本文で探す資料")
  end

  it "filters documents by normalized document keyword" do
    api_doc = create(:document, project:, title: "外部連携仕様", slug: "external-api")
    other_doc = create(:document, project:, title: "操作手順", slug: "manual-doc")
    create(:document_version, document: api_doc)
    create(:document_version, document: other_doc)
    keyword_document(api_doc, "ＷＭＳ ＡＰＩ")

    sign_in_as(user)

    get project_documents_path(project, q: "wms api")

    expect(response).to have_http_status(:ok)
    expect(result_titles).to contain_exactly("外部連携仕様")
  end

  it "filters documents by tag" do
    api_doc = create(:document, project:, title: "API仕様", slug: "api-spec")
    manual_doc = create(:document, project:, title: "操作手順", slug: "manual-doc")
    create(:document_version, document: api_doc)
    create(:document_version, document: manual_doc)
    tag = tag_document(api_doc, "API")
    tag_document(manual_doc, "Manual")

    sign_in_as(user)

    get project_documents_path(project, tag: tag.normalized_name)

    expect(response).to have_http_status(:ok)
    expect(result_titles).to contain_exactly("API仕様")
    expect(response.body).to include("API")
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

  it "does not expose inaccessible documents through tag filtering" do
    external_user = create(:user, :external)
    create(:project_membership, project:, user: external_user)

    visible_doc = create(:document, project:, title: "公開API", slug: "visible-api")
    hidden_doc = create(:document, project:, title: "社内API", slug: "internal-api", visibility_policy: :internal_only)
    create(:document_version, document: visible_doc)
    create(:document_version, document: hidden_doc)
    create(:document_permission, document: visible_doc, company: external_user.company, access_level: :view)
    tag = tag_document(visible_doc, "API")
    DocumentTagging.create!(document: hidden_doc, document_tag: tag)

    sign_in_as(external_user)

    get project_documents_path(project, tag: tag.normalized_name)

    expect(response).to have_http_status(:ok)
    expect(result_titles).to contain_exactly("公開API")
    expect(response.body).not_to include("社内API")
  end

  it "does not expose inaccessible documents through keyword search" do
    external_user = create(:user, :external)
    create(:project_membership, project:, user: external_user)

    visible_doc = create(:document, project:, title: "公開仕様", slug: "visible-spec")
    hidden_doc = create(:document, project:, title: "社内仕様", slug: "internal-spec", visibility_policy: :internal_only)
    create(:document_version, document: visible_doc)
    create(:document_version, document: hidden_doc)
    create(:document_permission, document: visible_doc, company: external_user.company, access_level: :view)
    keyword_document(visible_doc, "Salesforce連携")
    keyword_document(hidden_doc, "Salesforce連携")

    sign_in_as(external_user)

    get project_documents_path(project, q: "Salesforce")

    expect(response).to have_http_status(:ok)
    expect(result_titles).to contain_exactly("公開仕様")
    expect(response.body).not_to include("社内仕様")
  end

  it "does not expose inaccessible documents through body text search" do
    external_user = create(:user, :external)
    create(:project_membership, project:, user: external_user)

    visible_doc = create(:document, project:, title: "公開本文", slug: "visible-body")
    hidden_doc = create(:document, project:, title: "社内本文", slug: "internal-body", visibility_policy: :internal_only)
    create(:document_version, document: visible_doc, search_body_text: "confidential-body-keyword")
    create(:document_version, document: hidden_doc, search_body_text: "confidential-body-keyword")
    create(:document_permission, document: visible_doc, company: external_user.company, access_level: :view)

    sign_in_as(external_user)

    get project_documents_path(project, q: "confidential-body-keyword")

    expect(response).to have_http_status(:ok)
    expect(result_titles).to contain_exactly("公開本文")
    expect(response.body).not_to include("社内本文")
  end
end
