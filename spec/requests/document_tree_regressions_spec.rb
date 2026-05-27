require "rails_helper"

RSpec.describe "Document tree regressions", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "TREE", name: "Tree Project") }
  let!(:markdown_document) do
    create(:document, project:, title: "Intro Guide", slug: "intro-guide", document_kind: :markdown, visibility_policy: :internal_only)
  end
  let!(:pdf_document) do
    create(:document, project:, title: "Operations Manual", slug: "operations-manual", document_kind: :pdf, visibility_policy: :internal_only)
  end
  let!(:csv_document) do
    create(:document, project:, title: "Inventory", slug: "inventory", document_kind: :excel, visibility_policy: :internal_only)
  end
  let!(:markdown_version) { create(:document_version, document: markdown_document, version_label: "v1", status: :published) }
  let!(:pdf_version) { create(:document_version, document: pdf_document, version_label: "v1", status: :published) }
  let!(:csv_version) { create(:document_version, document: csv_document, version_label: "v1", status: :published) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.gsub(/\s+/, " ").strip
  end

  before do
    markdown_document.update!(latest_version: markdown_version)
    pdf_document.update!(latest_version: pdf_version)
    csv_document.update!(latest_version: csv_version)
  end

  it "shows mixed document kinds with extension-specific icons in the document page tree" do
    sign_in_as(user)

    get project_document_path(project, markdown_document.slug)

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css(".document-tree-scroll-spacer")).to be_present
    expect(page_text).to include("intro-guide.md")
    expect(page_text).to include("operations-manual.pdf")
    expect(page_text).to include("inventory.csv")
    expect(parsed_html.at_css(".tree-icon--md")).to be_present
    expect(parsed_html.at_css(".tree-icon--pdf")).to be_present
    expect(parsed_html.at_css(".tree-icon--csv")).to be_present
    expect(parsed_html.at_css(%(a[href="#{project_document_path(project, pdf_document.slug)}"]))).to be_present
    expect(parsed_html.at_css(%(a[href="#{project_document_path(project, csv_document.slug)}"]))).to be_present
  end

  it "removes archived documents from the tree until they are restored" do
    sign_in_as(user)

    get project_document_path(project, markdown_document.slug)
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("operations-manual.pdf")

    patch archive_admin_document_path(pdf_document.public_id)
    expect(response).to redirect_to(admin_documents_path)
    expect(pdf_document.reload).to be_archived

    get project_document_path(project, markdown_document.slug)
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("intro-guide.md")
    expect(page_text).to include("inventory.csv")
    expect(page_text).not_to include("operations-manual.pdf")

    get project_document_tree_path(project, document_slug: markdown_document.slug, format: :turbo_stream)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
    expect(parsed_html.at_css(%(turbo-stream[target="document_tree_panel"]))).to be_present
    expect(page_text).not_to include("operations-manual.pdf")

    patch restore_admin_document_path(pdf_document.public_id)
    expect(response).to redirect_to(admin_documents_path)
    expect(pdf_document.reload).not_to be_archived

    get project_document_path(project, markdown_document.slug)
    expect(response).to have_http_status(:ok)
    expect(page_text).to include("operations-manual.pdf")
  end

  it "declares the sidebar controller in the server-rendered document layout" do
    sign_in_as(user)

    get project_document_path(project, markdown_document.slug)

    expect(response).to have_http_status(:ok)

    layout = parsed_html.at_css(".layout-with-sidebar")
    expect(layout).to be_present
    expect(layout["data-controller"].to_s.split).to include("document-tree-navigation")
  end
end