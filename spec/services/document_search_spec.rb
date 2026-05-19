require "rails_helper"

RSpec.describe DocumentSearch do
  let(:project) { create(:project, code: "DSEARCH") }
  let(:document) { create(:document, project:, title: "出荷API仕様", slug: "shipping-api") }

  it "returns empty labels when keyword is blank" do
    expect(described_class.new("").match_labels_for(document)).to eq([])
  end

  it "returns labels for matched title, tag, keyword, body text, summary, and attached file values" do
    version = create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      source_relative_path: "docs/shipping-api.md",
      changelog_summary: "外部連携APIの初版",
      search_body_text: "出荷APIの本文説明"
    )
    tag = DocumentTag.create!(name: "外部連携", normalized_name: DocumentTag.normalize("外部連携"))
    DocumentTagging.create!(document:, document_tag: tag)
    DocumentKeyword.create!(document:, keyword: "外部連携API")
    DocumentFile.create!(
      document_version: version,
      file_name: "shipping-api.pdf",
      content_type: "application/pdf",
      storage_key: "spec/document-search/files/shipping-api.pdf",
      file_size: 10,
      search_text: "添付内のAPI説明"
    )

    expect(described_class.new("API").match_labels_for(document.reload)).to contain_exactly(
      "タイトル",
      "slug",
      "source path",
      "更新サマリ",
      "本文",
      "添付ファイル名",
      "添付tree path",
      "添付テキスト",
      "キーワード"
    )
    expect(described_class.new("外部連携").match_labels_for(document.reload)).to include("タグ")
  end

  it "uses the same target labels for matching and public target definition" do
    expect(described_class.new("API").match_labels_for(document)).to all(
      be_in(described_class.match_target_labels)
    )
  end

  it "normalizes full-width keyword values" do
    DocumentKeyword.create!(document:, keyword: "ＷＭＳ ＡＰＩ")

    expect(described_class.new("wms api").match_labels_for(document.reload)).to contain_exactly("キーワード")
  end

  it "applies the keyword filter to an ActiveRecord scope" do
    create(:document, project:, title: "対象外", slug: "other-doc")
    create(:document_version, document:, search_body_text: "shared-search-keyword")

    result = described_class.new("shared-search-keyword").apply(project.documents).distinct

    expect(result).to contain_exactly(document)
  end

  it "applies tag and attachment path filters to an ActiveRecord scope" do
    other_document = create(:document, project:, title: "対象外", slug: "other-doc")
    tag = DocumentTag.create!(name: "運用手順", normalized_name: DocumentTag.normalize("運用手順"))
    DocumentTagging.create!(document:, document_tag: tag)
    version = create(:document_version, document:)
    DocumentFile.create!(
      document_version: version,
      file_name: "guide.pdf",
      content_type: "application/pdf",
      storage_key: "spec/document-search/files/guide.pdf",
      file_size: 10
    )

    expect(described_class.new("運用手順").apply(project.documents).distinct).to contain_exactly(document)
    expect(described_class.new("files/guide").apply(project.documents).distinct).to contain_exactly(document)
    expect(described_class.new("files/guide").apply(Document.where(id: other_document.id)).distinct).to be_empty
  end
end
