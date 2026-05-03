require "rails_helper"

RSpec.describe DocumentSearch do
  let(:project) { create(:project, code: "DSEARCH") }
  let(:document) { create(:document, project:, title: "出荷API仕様", slug: "shipping-api") }

  it "returns empty labels when keyword is blank" do
    expect(described_class.new("").match_labels_for(document)).to eq([])
  end

  it "returns labels for matched title, keyword, body text, and attached file values" do
    version = create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      source_relative_path: "docs/shipping-api.md",
      search_body_text: "出荷APIの本文説明"
    )
    DocumentKeyword.create!(document:, keyword: "外部連携API")
    DocumentFile.create!(
      document_version: version,
      file_name: "shipping-api.pdf",
      content_type: "application/pdf",
      storage_key: "spec/document-search/shipping-api.pdf",
      file_size: 10,
      search_text: "添付内のAPI説明"
    )

    expect(described_class.new("API").match_labels_for(document.reload)).to contain_exactly(
      "タイトル",
      "slug",
      "source path",
      "本文",
      "添付ファイル名",
      "添付テキスト",
      "キーワード"
    )
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
end
