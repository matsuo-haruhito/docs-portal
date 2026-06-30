require "rails_helper"

RSpec.describe "document_set_document_filter_controller.js" do
  let(:source) { Rails.root.join("app/frontend/controllers/document_set_document_filter_controller.js").read }

  it "adds remote search-only documents as checked catalog item rows" do
    expect(source).to include("createRemoteDocumentRow(remoteDocument)")
    expect(source).to include('static targets = ["query", "row", "status", "checkbox", "selectedOnly", "empty", "tableBody"]')
    expect(source).to include("document_catalog_items[${key}][document_id]")
    expect(source).to include("document_catalog_items[${key}][selected]")
    expect(source).to include("checkbox.checked = true")
    expect(source).to include("this.tableBodyTarget.appendChild(row)")
  end

  it "keeps remote document payload metadata for the generated row" do
    expect(source).to include("detail.option || detail.item || detail.document || detail.data || detail")
    expect(source).to include("latest_version_label")
    expect(source).to include("detailOption.path || detailOption.url")
    expect(source).to include("titleNode.href = path")
  end
end
