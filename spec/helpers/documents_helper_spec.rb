require "rails_helper"

RSpec.describe DocumentsHelper, type: :helper do
  describe "#document_tree_render_state" do
    let(:project) { create(:project, code: "TREE", name: "Tree Project") }
    let!(:first_folder_doc) { create(:document, project:, title: "01. 要件") }
    let!(:second_folder_doc) { create(:document, project:, title: "02. 設計") }

    before do
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
