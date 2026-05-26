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
    let(:internal_user) { create(:user, :internal) }
    let(:project) { create(:project, code: "TOOLBAR", name: "Toolbar Tree") }

    before do
      user = internal_user
      helper.define_singleton_method(:current_user) { user }
      helper.define_singleton_method(:params) do
        ActionController::Parameters.new(tree_query: "仕様", tree_window_offset: "25")
      end
    end

    it "builds the expand-all path through the project-wide tree action route" do
      expect(helper.document_tree_toggle_all_path(project:, state: :expanded)).to eq(
        helper.document_tree_all_project_path(
          project,
          tree_action: "show",
          tree_query: "仕様",
          tree_window_offset: 25,
          format: :turbo_stream
        )
      )
    end

    it "maps collapsed states to the hide action" do
      expect(helper.document_tree_toggle_all_path(project:, state: :collapsed)).to eq(
        helper.document_tree_all_project_path(
          project,
          tree_action: "hide",
          tree_query: "仕様",
          tree_window_offset: 25,
          format: :turbo_stream
        )
      )
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