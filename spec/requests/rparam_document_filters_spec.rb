require "rails_helper"

RSpec.describe "Rparam document filters", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "RPARAM", name: "Rparam Project") }

  def attach_file_to(version, file_name:, content_type: "application/octet-stream")
    DocumentFile.create!(
      document_version: version,
      file_name:,
      content_type:,
      storage_key: "spec/rparam-#{SecureRandom.hex(8)}-#{file_name}",
      file_size: 10
    )
  end

  def result_titles
    html = Nokogiri::HTML(response.body)
    html.css("main table tbody tr td:first-child").map { _1.text.strip }
  end

  it "normalizes invalid page values" do
    document = create(:document, project:, title: "Rparam Document", slug: "rparam-doc")
    create(:document_version, document:)

    sign_in_as(user)

    get project_documents_path(project, page: "-10")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("1/1ページ")
    expect(response.body).to include("Rparam Document")
  end

  it "applies enum filters through rparam inclusion rules" do
    manual_pdf = create(:document, project:, title: "Manual PDF", category: :manual, document_kind: :pdf, visibility_policy: :public_with_login)
    spec_markdown = create(:document, project:, title: "Spec Markdown", category: :spec, document_kind: :markdown, visibility_policy: :restricted_external)
    create(:document_version, document: manual_pdf)
    create(:document_version, document: spec_markdown)

    sign_in_as(user)

    get project_documents_path(project, category: "manual", document_kind: "pdf", visibility_policy: "public_with_login")

    expect(response).to have_http_status(:ok)
    expect(result_titles).to contain_exactly("Manual PDF")
  end

  it "drops invalid enum filters through rparam inclusion rules" do
    manual_pdf = create(:document, project:, title: "Manual PDF", category: :manual, document_kind: :pdf)
    spec_markdown = create(:document, project:, title: "Spec Markdown", category: :spec, document_kind: :markdown)
    create(:document_version, document: manual_pdf)
    create(:document_version, document: spec_markdown)

    sign_in_as(user)

    get project_documents_path(project, category: "not-a-category", document_kind: "not-a-kind")

    expect(response).to have_http_status(:ok)
    expect(result_titles).to contain_exactly("Manual PDF", "Spec Markdown")
  end

  it "applies boolean availability filters through rparam boolean parsing" do
    html_doc = create(:document, project:, title: "HTMLあり", slug: "html-doc")
    html_version = create(:document_version, document: html_doc, site_build_path: "docs/html-doc")
    html_doc.update!(latest_version: html_version)

    pdf_doc = create(:document, project:, title: "PDFあり", slug: "pdf-doc", document_kind: :markdown)
    pdf_version = create(:document_version, document: pdf_doc)
    attach_file_to(pdf_version, file_name: "manual.pdf", content_type: "application/pdf")

    other_doc = create(:document, project:, title: "対象外", slug: "other-doc")
    create(:document_version, document: other_doc)

    sign_in_as(user)

    get project_documents_path(project, has_html: "1")
    expect(response).to have_http_status(:ok)
    expect(result_titles).to contain_exactly("HTMLあり")

    get project_documents_path(project, has_pdf: "true")
    expect(response).to have_http_status(:ok)
    expect(result_titles).to contain_exactly("PDFあり")
  end

  it "does not apply malformed boolean filters" do
    html_doc = create(:document, project:, title: "HTMLあり", slug: "html-doc")
    html_version = create(:document_version, document: html_doc, site_build_path: "docs/html-doc")
    html_doc.update!(latest_version: html_version)

    other_doc = create(:document, project:, title: "通常資料", slug: "normal-doc")
    create(:document_version, document: other_doc)

    sign_in_as(user)

    get project_documents_path(project, has_html: "yes")

    expect(response).to have_http_status(:ok)
    expect(result_titles).to contain_exactly("HTMLあり", "通常資料")
  end
end
