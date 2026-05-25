require "rails_helper"
require "digest"

RSpec.describe "Document tree regressions", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "TREE01", name: "Tree Regression Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def sidebar_folder_key_for(path)
    "folder_#{project.id}_#{Digest::SHA256.hexdigest(path).first(16)}"
  end

  def sidebar_project_key
    "project_#{project.id}"
  end

  def detail_tree_folder_key_for(path)
    "project_detail_folder_#{project.id}_#{Digest::SHA256.hexdigest(path).first(16)}"
  end

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

    patch archive_admin_document_path(pdf_document)
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

    patch restore_admin_document_path(pdf_document)
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
    expect(layout["data-sidebar-layout"]).to eq("true")
    expect(layout["data-controller"].to_s.split).to include("sidebar")
  end

  it "keeps mixed document kinds visible when the tree refreshes through turbo stream" do
    sign_in_as(user)

    get project_document_tree_path(project, document_slug: markdown_document.slug, format: :turbo_stream)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
    expect(parsed_html.at_css(%(turbo-stream[target="document_tree_panel"]))).to be_present
    expect(parsed_html.at_css("#document_tree_toolbar")).to be_present
    expect(page_text).to include("intro-guide.md")
    expect(page_text).to include("operations-manual.pdf")
    expect(page_text).to include("inventory.csv")
    expect(parsed_html.at_css(".tree-icon--pdf")).to be_present
    expect(parsed_html.at_css(".tree-icon--csv")).to be_present
  end

  it "persists sidebar folder toggles and current bulk expansion keys in the tree view state" do
    sign_in_as(user)

    get project_document_tree_path(project, document_slug: markdown_document.slug, tree_action: "show", source_path: "guides", format: :turbo_stream)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq(Mime[:turbo_stream].to_s)

    sidebar_state = user.reload.tree_view_state_for(DocumentsHelper::DOCUMENT_TREE_INSTANCE_KEY)
    expect(Array(sidebar_state.expanded_keys)).to include(sidebar_folder_key_for("guides"))

    get project_document_tree_path(project, document_slug: markdown_document.slug, tree_action: "hide", source_path: "guides", format: :turbo_stream)

    expect(response).to have_http_status(:ok)

    sidebar_state = user.reload.tree_view_state_for(DocumentsHelper::DOCUMENT_TREE_INSTANCE_KEY)
    expect(Array(sidebar_state.expanded_keys)).not_to include(sidebar_folder_key_for("guides"))

    post document_tree_all_project_path(project, tree_action: "show", format: :turbo_stream)

    expect(response).to have_http_status(:ok)

    sidebar_state = user.reload.tree_view_state_for(DocumentsHelper::DOCUMENT_TREE_INSTANCE_KEY)
    expect(Array(sidebar_state.expanded_keys)).to include(
      sidebar_project_key,
      sidebar_folder_key_for("guides")
    )

    post document_tree_all_project_path(project, tree_action: "hide", format: :turbo_stream)

    expect(response).to have_http_status(:ok)

    sidebar_state = user.reload.tree_view_state_for(DocumentsHelper::DOCUMENT_TREE_INSTANCE_KEY)
    expect(Array(sidebar_state.expanded_keys)).not_to include(
      sidebar_project_key,
      sidebar_folder_key_for("guides")
    )
  end

  it "stores project detail tree expansion separately from the sidebar tree state" do
    sign_in_as(user)

    get project_document_tree_path(project, document_slug: markdown_document.slug, tree_action: "show", source_path: "guides", format: :turbo_stream)
    sidebar_before = Array(user.reload.tree_view_state_for(DocumentsHelper::DOCUMENT_TREE_INSTANCE_KEY).expanded_keys)

    post document_detail_tree_project_path(project, tree_action: "collapse", source_path: "guides", format: :turbo_stream)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
    expect(parsed_html.at_css(%(turbo-stream[target="project_document_detail_tree"]))).to be_present

    user.reload
    sidebar_state = user.tree_view_state_for(DocumentsHelper::DOCUMENT_TREE_INSTANCE_KEY)
    detail_state = user.tree_view_state_for("documents:project_detail:#{project.id}")

    expect(Array(sidebar_state.expanded_keys)).to eq(sidebar_before)
    expect(detail_state).to be_present
    expect(Array(detail_state.expanded_keys)).not_to include(detail_tree_folder_key_for("guides"))
    expect(Array(detail_state.expanded_keys)).to eq([])
  end

  it "keeps the requested window offset in turbo tree refresh controls" do
    sign_in_as(user)

    documents = Array.new(120) do |index|
      document = create(
        :document,
        project:,
        title: format("Windowed Document %03d", index),
        slug: format("windowed-document-%03d", index)
      )
      version = create(
        :document_version,
        document:,
        version_label: format("v%<index>d.0.0", index: index + 1),
        source_relative_path: format("windowed/document_%03d.md", index),
        source_directory: "windowed",
        source_file_name: format("document_%03d.md", index),
        source_basename: format("document_%03d", index),
        source_extension: "md"
      )
      document.update!(latest_version: version)
      document
    end
    current_document = documents.fetch(70)

    get project_document_tree_path(project, document_slug: current_document.slug, tree_window_offset: 50, format: :turbo_stream)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
    expect(parsed_html.at_css(".document-tree-window-summary")).to be_present
    expect(page_text).to include("前の50行")
    expect(page_text).to include("次の50行")

    toolbar_actions = parsed_html.css("#document_tree_toolbar form[action]").map { _1["action"] }

    expect(toolbar_actions).not_to be_empty
    expect(toolbar_actions).to all(include("tree_window_offset=50"))
    expect(toolbar_actions.any? { _1.include?("tree_action=show") }).to be(true)
    expect(toolbar_actions.any? { _1.include?("tree_action=hide") }).to be(true)
  end
end
