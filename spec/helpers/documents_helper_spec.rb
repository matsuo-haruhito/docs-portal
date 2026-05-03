require "rails_helper"

RSpec.describe DocumentsHelper, type: :helper do
  describe "document tree links" do
    let(:user) { create(:user, :internal) }
    let(:project) { create(:project, code: "TREE") }
    let(:document) { create(:document, project:, title: "操作説明", slug: "manual") }

    before do
      current_user = user
      helper.define_singleton_method(:current_user) { current_user }
    end

    it "links a document node directly to its rendered HTML page when available" do
      version = create(:document_version, document:, site_build_path: "docs/manual")
      document.update!(latest_version: version, updated_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
      FileUtils.mkdir_p(version.site_root_absolute_path.join("docs/manual"))
      File.write(version.site_root_absolute_path.join("docs/manual/index.html"), "<html></html>")

      expect(helper.tree_item_path(document)).to eq(
        helper.project_site_path(project, site_path: "docs/manual", version_id: version.public_id)
      )
      expect(helper.tree_item_detail_path(document)).to eq(helper.project_document_path(project, document.slug))
      expect(helper.tree_item_updated_label(document)).to eq("2026-05-01")
      expect(helper.tree_item_html_available?(document)).to be(true)
    end

    it "falls back to the document detail page when rendered HTML is unavailable" do
      document.update!(latest_version: create(:document_version, document:))

      expect(helper.tree_item_path(document)).to eq(helper.project_document_path(project, document.slug))
      expect(helper.tree_item_html_available?(document)).to be(false)
    end

    it "links a project node to its default rendered site and keeps a project top link" do
      version = create(:document_version, document:, site_build_path: "docs/manual", published_at: Time.zone.local(2026, 5, 1, 9, 0, 0))
      document.update!(latest_version: version)
      FileUtils.mkdir_p(version.site_root_absolute_path.join("docs/manual"))
      File.write(version.site_root_absolute_path.join("docs/manual/index.html"), "<html></html>")

      expect(helper.tree_item_path(project)).to eq(
        helper.project_site_path(project, site_path: "docs/manual", version_id: version.public_id)
      )
      expect(helper.tree_item_detail_path(project)).to eq(helper.project_path(project))
    end
  end

  describe "#document_search_match_labels" do
    let(:project) { create(:project, code: "MATCH") }
    let(:document) { create(:document, project:, title: "出荷API仕様", slug: "shipping-api") }

    it "returns empty labels when keyword is blank" do
      expect(helper.document_search_match_labels(document, "")).to eq([])
    end

    it "returns labels for matched title, keyword, body text, and attached file name" do
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
        "添付テキスト"
      )
    end

    it "normalizes full-width keyword values" do
      DocumentKeyword.create!(document:, keyword: "ＷＭＳ ＡＰＩ")

      expect(helper.document_search_match_labels(document.reload, "wms api")).to contain_exactly("キーワード")
    end
  end
end
