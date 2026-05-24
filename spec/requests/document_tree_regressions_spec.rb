require "rails_helper"

RSpec.describe "Document tree regressions", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "TREE01", name: "Tree Regression Project") }

  let!(:markdown_document) do
    create(:document, project:, title: "導入ガイド", slug: "intro-guide", document_kind: :markdown)
  end
  let!(:markdown_version) do
    create(
      :document_version,
      document: markdown_document,
      version_label: "v1.0.0",
      source_relative_path: "guides/intro-guide.md",
      source_directory: "guides",
      source_file_name: "intro-guide.md",
      source_basename: "intro-guide",
      source_extension: "md"
    )
  end

  let!(:pdf_document) do
    create(:document, project:, title: "運用手順", slug: "operations-manual", document_kind: :pdf)
  end
  let!(:pdf_version) { create(:document_version, document: pdf_document, version_label: "v2.0.0") }
  let!(:pdf_file) do
    create(
      :document_file,
      document_version: pdf_version,
      file_name: "attachments/operations-manual.pdf",
      content_type: "application/pdf",
      storage_key: "spec/document-tree/operations-manual.pdf",
      file_size: 12,
      sort_order: 0,
      scan_status: :scan_clean
    )
  end

  let!(:csv_document) do
    create(:document, project:, title: "棚卸一覧", slug: "inventory-export", document_kind: :mixed)
  end
  let!(:csv_version) { create(:document_version, document: csv_document, version_label: "v3.0.0") }
  let!(:csv_file) do
    create(
      :document_file,
      document_version: csv_version,
      file_name: "exports/inventory.csv",
      content_type: "text/csv",
      storage_key: "spec/document-tree/inventory.csv",
      file_size: 18,
      sort_order: 0,
      scan_status: :scan_clean
    )
  end

  it "shows mixed document kinds with extension-specific icons in the document page tree" do
    sign_in_as(user)

    get project_document_path(project, markdown_document.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("document-tree-scroll-spacer")
    expect(response.body).to include("intro-guide.md")
    expect(response.body).to include("operations-manual.pdf")
    expect(response.body).to include("inventory.csv")
    expect(response.body).to include("tree-icon--md")
    expect(response.body).to include("tree-icon--pdf")
    expect(response.body).to include("tree-icon--csv")
    expect(response.body).to include(project_document_path(project, pdf_document.slug))
    expect(response.body).to include(project_document_path(project, csv_document.slug))
  end

  it "declares the sidebar controller in the server-rendered document layout" do
    sign_in_as(user)

    get project_document_path(project, markdown_document.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('class="layout-with-sidebar" data-sidebar-layout="true" data-controller="sidebar"')
  end

  it "keeps mixed document kinds visible when the tree refreshes through turbo stream" do
    sign_in_as(user)

    get project_document_tree_path(project, document_slug: markdown_document.slug, format: :turbo_stream)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
    expect(response.body).to include("document_tree_panel")
    expect(response.body).to include("document_tree_toolbar")
    expect(response.body).to include("intro-guide.md")
    expect(response.body).to include("operations-manual.pdf")
    expect(response.body).to include("inventory.csv")
    expect(response.body).to include("tree-icon--pdf")
    expect(response.body).to include("tree-icon--csv")
  end
end
