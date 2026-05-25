require "rails_helper"

RSpec.describe "document_versions/show preview status source" do
  let(:source) { Rails.root.join("app/views/document_versions/show.html.slim").read }

  it "uses Japanese labels in the preview status card" do
    aggregate_failures do
      expect(source).to include("strong ビルド状態: ")
      expect(source).to include("strong ビルドマニフェスト: ")
      expect(source).to include("strong マニフェスト警告: ")
      expect(source).to include("summary Docusaurusビルド警告の詳細")
    end
  end

  it "uses Japanese count expressions instead of English pluralize labels" do
    aggregate_failures do
      expect(source).to include('= "#{@version.document_files.size}件"')
      expect(source).to include('= "#{@docusaurus_build_manifest&.warnings&.size.to_i}件"')
      expect(source).not_to include('pluralize(@version.document_files.size, "file")')
      expect(source).not_to include('pluralize(@docusaurus_build_manifest&.warnings&.size.to_i, "warning")')
    end
  end
end
