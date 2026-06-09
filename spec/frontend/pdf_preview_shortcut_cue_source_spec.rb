require "rails_helper"

RSpec.describe "PDF preview shortcut cue source" do
  let(:pdf_preview_source) do
    Rails.root.join("app/views/document_files/show_pdf_preview.html.slim").read
  end

  let(:pdf_tools_source) do
    Rails.root.join("app/frontend/lib/pdf_preview_tools.js").read
  end

  it "shows the height shortcut cue next to the PDF height controls" do
    aggregate_failures do
      expect(pdf_preview_source).to include('data-pdf-preview-tools="true"')
      expect(pdf_preview_source).to include('data-pdf-preview-status="true"')
      expect(pdf_preview_source).to include('data-pdf-preview-shortcut-cue="true" Hで高さ切替')
      expect(pdf_preview_source).to include('data-pdf-preview-height-toggle="true" aria-pressed="false" 大きく表示')
      expect(pdf_preview_source).to include('data-pdf-preview-frame="true"')
    end
  end

  it "keeps the existing h/H keyboard shortcut behavior in the PDF helper" do
    aggregate_failures do
      expect(pdf_tools_source).to include('if (event.key !== "h" && event.key !== "H") return')
      expect(pdf_tools_source).to include("toggleHeight()")
      expect(pdf_tools_source).to include('toggle.textContent = large ? "標準高さに戻す" : "大きく表示"')
      expect(pdf_tools_source).to include('status.textContent = large ? "大きく表示しています" : "標準高さで表示しています"')
    end
  end
end
