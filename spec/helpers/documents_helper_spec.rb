require "rails_helper"

RSpec.describe DocumentsHelper, type: :helper do
  describe "#document_tree_render_state" do
    let(:internal_user) { create(:user, :internal) }
    let(:project) { create(:project, code: "TREE", name: "Tree Project") }
    let!(:first_folder_doc) { create(:document, project:, title: "01. 要件") }
    let!(:second_folder_doc) { create(:document, project:, title: "02. 設計") }

    before do
      user = internal_user
      helper.define_singleton_method(:current_user) { user }
      first_version = create(:document_version, document: first_folder_doc, source_relative_path: "docs/01_requirements/index.md")
      second_version = create(:document_version, document: second_folder_doc, source_relative_path: "docs/02_design/index.md")
      first_folder_doc.update!(latest_version: first_version)
      second_folder_doc.update!(latest_version: second_version)
    end

    it "expands folders on the path to the current document" do
      render_state = helper.document_tree_render_state(projects: [project], current_project: project, current_document: second_folder_doc)
      first_folder = helper.send(:document_tree_nodes_for, project).find { _1.label == "docs" }
      second_folder = first_folder.children.find { _1.label == "02_design" }

      expect(render_state.expanded_keys).to include(
        "project_#{project.id}",
        helper.send(:node_key, first_folder),
        helper.send(:node_key, second_folder)
      )
    end

    it "keeps non-Markdown documents in the tree using representative file paths when no source path exists" do
      markdown_doc = create(:document, project:, title: "03. Markdown guide", document_kind: :markdown)
      markdown_version = create(:document_version, document: markdown_doc, source_relative_path: "docs/shared/guide.md")
      markdown_doc.update!(latest_version: markdown_version)

      pdf_doc = create(:document, project:, title: "04. PDF policy", document_kind: :pdf)
      pdf_version = create(:document_version, document: pdf_doc)
      create(
        :document_file,
        document_version: pdf_version,
        file_name: "docs/shared/policy.pdf",
        content_type: "application/pdf",
        storage_key: "spec/document-tree/policy.pdf"
      )
      pdf_doc.update!(latest_version: pdf_version)

      excel_doc = create(:document, project:, title: "05. Excel matrix", document_kind: :excel)
      excel_version = create(:document_version, document: excel_doc)
      create(
        :document_file,
        document_version: excel_version,
        file_name: "docs/shared/matrix.xlsx",
        content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        storage_key: "spec/document-tree/matrix.xlsx"
      )
      excel_doc.update!(latest_version: excel_version)

      helper.document_tree_render_state(projects: [project], current_project: project)
      docs_folder = helper.send(:document_tree_nodes_for, project).find { _1.label == "docs" }
      shared_folder = docs_folder.children.find { _1.label == "shared" }

      expect(shared_folder.children).to include(markdown_doc, pdf_doc, excel_doc)
      expect(helper.send(:document_tree_source_file_name, pdf_doc)).to eq("policy.pdf")
      expect(helper.send(:document_tree_source_file_name, excel_doc)).to eq("matrix.xlsx")
      expect(helper.send(:tree_item_html_available?, pdf_doc)).to eq(false)
      expect(helper.send(:tree_item_html_available?, excel_doc)).to eq(false)
    end

    it "preserves external visibility and archived filters for file-backed tree rows" do
      external_user = create(:user, :external)
      project.update!(company: external_user.company)
      create(:project_membership, project:, user: external_user)
      helper.define_singleton_method(:current_user) { external_user }

      visible_doc = create(:document, project:, title: "Visible PDF", document_kind: :pdf, visibility_policy: :public_with_login)
      visible_version = create(:document_version, document: visible_doc)
      create(:document_file, document_version: visible_version, file_name: "external/visible.pdf", content_type: "application/pdf")
      visible_doc.update!(latest_version: visible_version)

      internal_doc = create(:document, project:, title: "Internal PDF", document_kind: :pdf, visibility_policy: :internal_only)
      internal_version = create(:document_version, document: internal_doc)
      create(:document_file, document_version: internal_version, file_name: "external/internal.pdf", content_type: "application/pdf")
      internal_doc.update!(latest_version: internal_version)

      archived_doc = create(:document, project:, title: "Archived PDF", document_kind: :pdf, visibility_policy: :public_with_login, archived_at: Time.current)
      archived_version = create(:document_version, document: archived_doc)
      create(:document_file, document_version: archived_version, file_name: "external/archived.pdf", content_type: "application/pdf")
      archived_doc.update!(latest_version: archived_version)

      helper.document_tree_render_state(projects: [project], current_project: project)
      documents = helper.send(:document_tree_documents_for, project)

      expect(documents).to include(visible_doc)
      expect(documents).not_to include(internal_doc, archived_doc)
    end

    it "chooses document tree icons from source extension, primary file, then document kind" do
      mdx_doc = create(:document, project:, title: "MDX page", document_kind: :markdown)
      mdx_version = create(:document_version, document: mdx_doc, source_relative_path: "docs/page.mdx", source_extension: "mdx")
      mdx_doc.update!(latest_version: mdx_version)

      uploaded_pdf = create(:document, project:, title: "Uploaded PDF", document_kind: :markdown)
      pdf_version = create(:document_version, document: uploaded_pdf)
      create(:document_file, document_version: pdf_version, file_name: "uploads/confirmed.PDF", content_type: "application/pdf")
      uploaded_pdf.update!(latest_version: pdf_version)

      word_doc = create(:document, project:, title: "Word fallback", document_kind: :word)
      word_version = create(:document_version, document: word_doc)
      word_doc.update!(latest_version: word_version)

      zip_doc = create(:document, project:, title: "Zip bundle", document_kind: :mixed)
      zip_version = create(:document_version, document: zip_doc)
      create(:document_file, document_version: zip_version, file_name: "uploads/bundle.zip", content_type: "application/zip")
      zip_doc.update!(latest_version: zip_version)

      helper.document_tree_render_state(projects: [project], current_project: project)

      expect(helper.send(:document_tree_icon_name, mdx_doc)).to eq("mdx")
      expect(helper.send(:document_tree_icon_name, uploaded_pdf)).to eq("pdf")
      expect(helper.send(:document_tree_icon_name, word_doc)).to eq("docx")
      expect(helper.send(:document_tree_icon_name, zip_doc)).to eq("zip")
    end
  end

  describe "#document_tree_render_window" do
    let(:internal_user) { create(:user, :internal) }

    before do
      user = internal_user
      helper.define_singleton_method(:current_user) { user }
    end

    it "skips windowing for small trees" do
      project = create(:project, code: "SMALL", name: "Small Tree")
      document = create(:document, project:, title: "Overview")
      version = create(:document_version, document:, source_relative_path: "docs/overview/index.md")
      document.update!(latest_version: version)

      render_state = helper.document_tree_render_state(projects: [project], current_project: project, current_document: document)

      expect(helper.document_tree_render_window(render_state, current_document: document)).to be_nil
    end

    it "windows large trees while keeping the current document visible" do
      project = create(:project, code: "LARGE", name: "Large Tree")
      documents = Array.new(90) do |index|
        document = create(:document, project:, title: format("Document %03d", index))
        version = create(
          :document_version,
          document:,
          source_relative_path: format("docs/section_%02d/document_%03d.md", index / 3, index)
        )
        document.update!(latest_version: version)
        document
      end
      current_document = documents.fetch(75)

      render_state = helper.document_tree_render_state(projects: [project], current_project: project, current_document: current_document)
      window = helper.document_tree_render_window(render_state, current_document: current_document)

      expect(window).to be_a(TreeView::RenderWindow)
      expect(window.total_count).to be > DocumentsHelper::DOCUMENT_TREE_RENDER_WINDOW_THRESHOLD
      expect(window.rows.length).to eq(DocumentsHelper::DOCUMENT_TREE_RENDER_WINDOW_LIMIT)
      expect(window.offset).to be > 0
      expect(window.rows.map(&:node_key)).to include(helper.send(:node_key, current_document))
    end

    it "clamps explicit offsets to the last full window" do
      project = create(:project, code: "CLAMP", name: "Clamp Tree")
      documents = Array.new(90) do |index|
        document = create(:document, project:, title: format("Node %03d", index))
        version = create(
          :document_version,
          document:,
          source_relative_path: format("docs/group_%02d/node_%03d.md", index / 3, index)
        )
        document.update!(latest_version: version)
        document
      end

      render_state = helper.document_tree_render_state(projects: [project], current_project: project, current_document: documents.last)
      window = helper.document_tree_render_window(render_state, current_document: documents.last, requested_offset: 10_000)

      expect(window).to be_a(TreeView::RenderWindow)
      expect(window.offset).to eq(window.total_count - DocumentsHelper::DOCUMENT_TREE_RENDER_WINDOW_LIMIT)
      expect(window.rows.map(&:node_key)).to include(helper.send(:node_key, documents.last))
    end

    it "exposes previous and next offsets for intermediate windows" do
      project = create(:project, code: "MID", name: "Middle Window Tree")
      documents = Array.new(140) do |index|
        document = create(:document, project:, title: format("Window %03d", index))
        version = create(
          :document_version,
          document:,
          source_relative_path: format("window_%03d.md", index)
        )
        document.update!(latest_version: version)
        document
      end
      current_document = documents.fetch(60)

      render_state = helper.document_tree_render_state(projects: [project], current_project: project, current_document: current_document)
      window = helper.document_tree_render_window(render_state, current_document: current_document, requested_offset: 50)

      expect(window).to be_a(TreeView::RenderWindow)
      expect(window.offset).to eq(50)
      expect(window).to be_previous
      expect(window.previous_offset).to eq(0)
      expect(window).to be_next
      expect(window.next_offset).to eq(100)
    end
  end

  describe "#document_tree_toggle_all_path" do
    let(:project) { create(:project, code: "PATH", name: "Path Tree") }

    before do
      helper.define_singleton_method(:params) do
        ActionController::Parameters.new(tree_query: "legacy slug", tree_window_offset: "25")
      end
    end

    it "preserves query and render window state for expand-all actions" do
      expect(helper.document_tree_toggle_all_path(:expanded, current_project: project)).to eq(
        helper.document_tree_all_project_path(
          project,
          tree_action: "show",
          tree_query: "legacy slug",
          tree_window_offset: 25,
          format: :turbo_stream
        )
      )
    end

    it "returns nil without a current project context" do
      expect(helper.document_tree_toggle_all_path(:expanded)).to be_nil
    end
  end

  describe "#document_search_match_labels" do
    let(:project) { create(:project, code: "MATCH") }
    let(:document) { create(:document, project:, title: "出荷API仕様", slug: "shipping-api") }

    it "returns empty labels when keyword is blank" do
      expect(helper.document_search_match_labels(document, "")).to eq([])
    end

    it "returns labels for matched title, keyword, body text, and attached file metadata" do
      version = create(
        :document_version,
        document:,
        version_label: "v1.0.0",
        search_body_text: "出荷APIの本文説明"
      )
      DocumentKeyword.create!(document:, keyword: "外部連携API")
      DocumentFile.create!(
        document_version: version,
        file_name: "shipping-api.pdf",
        content_type: "application/pdf",
        storage_key: "spec/shipping-api.pdf",
        file_size: 10,
        search_text: "添付内のAPI説明"
      )

      expect(helper.document_search_match_labels(document.reload, "API")).to contain_exactly(
        "タイトル",
        "slug",
        "キーワード",
        "本文",
        "添付ファイル名",
        "添付tree path",
        "添付テキスト"
      )
    end

    it "normalizes full-width keyword values" do
      DocumentKeyword.create!(document:, keyword: "ＷＭＳ ＡＰＩ")

      expect(helper.document_search_match_labels(document.reload, "wms api")).to contain_exactly("キーワード")
    end
  end
end
