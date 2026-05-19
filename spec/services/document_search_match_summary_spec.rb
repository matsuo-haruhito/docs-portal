require "rails_helper"

RSpec.describe "DocumentSearch match summaries" do
  let(:project) { create(:project, code: "DSEARCHSUM") }
  let(:document) { create(:document, project:, title: "出荷API仕様", slug: "shipping-api") }

  it "returns compact label and value pairs" do
    create(
      :document_version,
      document:,
      source_relative_path: "docs/shipping-api.md",
      search_body_text: "出荷APIの本文説明"
    )

    summaries = DocumentSearch.new("API").match_summaries_for(document.reload)

    expect(summaries.map(&:label)).to include("タイトル", "slug", "source path")
    expect(summaries.map(&:value)).to include("出荷API仕様", "shipping-api", "docs/shipping-api.md")
  end

  it "limits summary rows for the document index" do
    create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      source_relative_path: "docs/shipping-api.md",
      search_body_text: "出荷APIの本文説明"
    )
    DocumentKeyword.create!(document:, keyword: "外部連携API")

    summaries = DocumentSearch.new("API").match_summaries_for(document.reload, limit: 2)

    expect(summaries.size).to eq(2)
  end
end
