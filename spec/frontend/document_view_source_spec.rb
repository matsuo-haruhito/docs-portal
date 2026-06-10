require "rails_helper"

RSpec.describe "document view source" do
  def read_source(path)
    Rails.root.join(path).read
  end

  let(:document_show_source) { read_source("app/views/documents/show.html.slim") }

  it "keeps the document detail drawer summary clear about actions and supporting information" do
    aggregate_failures do
      expect(document_show_source).to include("details.document-context-drawer#document-detail-panels")
      expect(document_show_source).to include("strong 文書情報・操作・版一覧を開く")
      expect(document_show_source).to include("span.muted 確認依頼、関連文書、添付・元ファイルを探すときもここを開きます")
      expect(document_show_source).to include('= render "detail_sections"')
    end
  end
end
